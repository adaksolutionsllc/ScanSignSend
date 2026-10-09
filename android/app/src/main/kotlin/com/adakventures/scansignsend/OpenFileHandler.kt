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
 * Receives PDFs the user opens with Scan Sign Send from Files, Gmail, Drive, a
 * browser download or a share sheet (the VIEW / SEND intent filters in
 * AndroidManifest.xml). Each one is copied into the app's cache and queued
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
        val uri = pdfUri(intent) ?: return
        // The read grant from the sender lasts as long as this activity, but
        // the copy can take a moment for a large or cloud-backed file, so it
        // runs off the UI thread.
        io.execute {
            val copy = copyToCache(uri) ?: return@execute
            main.post {
                pending.add(mapOf("path" to copy.path, "name" to copy.name))
                channel.invokeMethod("pending", null)
            }
        }
    }

    private fun pdfUri(intent: Intent?): Uri? {
        intent ?: return null
        val uri: Uri? = when (intent.action) {
            Intent.ACTION_VIEW -> intent.data
            Intent.ACTION_SEND ->
                @Suppress("DEPRECATION")
                intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
            else -> null
        }
        // content:// only: a file:// path would need storage permission,
        // which this app deliberately doesn't hold.
        if (uri?.scheme != "content") return null
        val type = intent.type ?: context.contentResolver.getType(uri)
        if (type != null && type != "application/pdf") return null
        return uri
    }

    private fun copyToCache(uri: Uri): File? {
        return try {
            val dir = File(context.cacheDir, "opened/${UUID.randomUUID()}")
            dir.mkdirs()
            val dest = File(dir, displayName(uri))
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
    private fun displayName(uri: Uri): String {
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
            .ifEmpty { "Document.pdf" }
        return if (safe.lowercase().endsWith(".pdf")) safe else "$safe.pdf"
    }
}
