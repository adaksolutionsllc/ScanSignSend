package com.adakventures.scansignsend

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Handler
import android.os.Looper
import android.provider.OpenableColumns
import android.util.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.UUID
import java.util.concurrent.Executors

/**
 * Platform channel: "com.scansignsend/open_file"
 *
 * Receives PDFs and photos the user opens with Scan Sign Send from Files,
 * Gmail, Drive, a browser download or a share sheet (the VIEW / SEND /
 * SEND_MULTIPLE intent filters in AndroidManifest.xml). Files that arrive in
 * one intent are queued together, so Dart can make several photos one
 * document. Each one is copied into the app's cache and queued
 * until Dart collects it, because a cold launch delivers the file before the
 * Flutter UI is listening.
 *
 * Methods:
 *   Dart → native  "takePending" → [{path: String, name: String}]
 *   native → Dart  "pending"     — a file was queued; call takePending
 * See OpenedFileService (Dart).
 */
class OpenFileHandler(private val context: Context, messenger: BinaryMessenger) {

    private companion object {
        const val CHANNEL = "com.scansignsend/open_file"
        const val TAG = "OpenFileHandler"

        /** Supported MIME types → the extension the importer recognises. */
        val EXTENSIONS = mapOf(
            "application/pdf" to "pdf",
            "image/jpeg" to "jpg",
            "image/png" to "png",
            "image/heic" to "heic",
            "image/heif" to "heif",
        )
    }

    private val channel = MethodChannel(messenger, CHANNEL)
    private val pending = mutableListOf<Map<String, String>>()
    private val io = Executors.newSingleThreadExecutor()
    private val main = Handler(Looper.getMainLooper())

    init {
        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "takePending" -> {
                    result.success(pending.toList())
                    pending.clear()
                }
                else -> result.notImplemented()
            }
        }
    }

    fun receive(intent: Intent?) {
        val uris = supportedUris(intent)
        if (uris.isEmpty()) return
        // The read grant from the sender lasts as long as this activity, but
        // the copy can take a moment for a large or cloud-backed file, so it
        // runs off the UI thread.
        io.execute {
            val copies = uris.mapNotNull { (uri, type) -> copyToCache(uri, type) }
            if (copies.isEmpty()) return@execute
            main.post {
                for (copy in copies) {
                    pending.add(mapOf("path" to copy.path, "name" to copy.name))
                }
                channel.invokeMethod("pending", null)
            }
        }
    }

    /** The opened files the importer reads, each with its MIME type. */
    private fun supportedUris(intent: Intent?): List<Pair<Uri, String>> {
        intent ?: return emptyList()
        @Suppress("DEPRECATION")
        val uris: List<Uri> = when (intent.action) {
            Intent.ACTION_VIEW -> listOfNotNull(intent.data)
            Intent.ACTION_SEND ->
                listOfNotNull(intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri)
            Intent.ACTION_SEND_MULTIPLE ->
                intent.getParcelableArrayListExtra<Uri>(Intent.EXTRA_STREAM).orEmpty()
            else -> emptyList()
        }
        return uris.mapNotNull { uri ->
            // content:// only: a file:// path would need storage permission,
            // which this app deliberately doesn't hold.
            if (uri.scheme != "content") return@mapNotNull null
            // The resolver knows each file's own type; the intent's may be a
            // wildcard such as image/* for several photos.
            val type = context.contentResolver.getType(uri) ?: intent.type
            if (type in EXTENSIONS) uri to type!! else null
        }
    }

    private fun copyToCache(uri: Uri, type: String): File? {
        return try {
            val dir = File(context.cacheDir, "opened/${UUID.randomUUID()}")
            dir.mkdirs()
            val dest = File(dir, displayName(uri, EXTENSIONS.getValue(type)))
            context.contentResolver.openInputStream(uri)?.use { input ->
                dest.outputStream().use { input.copyTo(it) }
            } ?: return null
            dest
        } catch (e: Exception) {
            Log.w(TAG, "Could not copy opened file", e)
            null
        }
    }

    /** The file's own name (for the document title), made safe as a path. */
    private fun displayName(uri: Uri, extension: String): String {
        var name: String? = null
        try {
            context.contentResolver.query(
                uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null
            )?.use { cursor ->
                if (cursor.moveToFirst()) name = cursor.getString(0)
            }
        } catch (_: Exception) {
        }
        val safe = (name ?: uri.lastPathSegment ?: "")
            .substringAfterLast('/')
            .replace(Regex("[\\\\:*?\"<>|\\x00-\\x1f]"), "_")
            .trim()
            .ifEmpty { "Document.$extension" }
        val lower = safe.lowercase()
        val known = EXTENSIONS.values.any { lower.endsWith(".$it") } ||
            lower.endsWith(".jpeg")
        return if (known) safe else "$safe.$extension"
    }
}
