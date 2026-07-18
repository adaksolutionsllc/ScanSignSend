package com.scansignsend.scan_sign_send

import android.app.Activity
import android.content.Context
import android.net.Uri
import com.google.mlkit.vision.documentscanner.GmsDocumentScanner
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.RESULT_FORMAT_JPEG
import com.google.mlkit.vision.documentscanner.GmsDocumentScannerOptions.SCANNER_MODE_FULL
import com.google.mlkit.vision.documentscanner.GmsDocumentScanning
import com.google.mlkit.vision.documentscanner.GmsDocumentScanningResult
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.embedding.engine.plugins.activity.ActivityAware
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.PluginRegistry
import java.io.File
import java.io.FileOutputStream
import java.util.UUID

class DocumentScannerPlugin :
    FlutterPlugin,
    MethodChannel.MethodCallHandler,
    ActivityAware,
    PluginRegistry.ActivityResultListener {

    companion object {
        const val CHANNEL_NAME = "com.scansignsend/scanner"
        private const val REQUEST_CODE = 0x5CA3 // "SCAN"
    }

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private var activity: Activity? = null
    private var pendingResult: MethodChannel.Result? = null
    private var scanner: GmsDocumentScanner? = null

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, CHANNEL_NAME)
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
    }

    override fun onAttachedToActivity(binding: ActivityPluginBinding) {
        activity = binding.activity
        binding.addActivityResultListener(this)
    }

    override fun onDetachedFromActivity() {
        activity = null
    }

    override fun onDetachedFromActivityForConfigChanges() = onDetachedFromActivity()
    override fun onReattachedToActivityForConfigChanges(binding: ActivityPluginBinding) =
        onAttachedToActivity(binding)

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "scanAvailable" -> result.success(true)

            "scan" -> {
                val act = activity ?: run {
                    result.error("NO_ACTIVITY", "No activity available", null)
                    return
                }
                if (pendingResult != null) {
                    result.error("ALREADY_ACTIVE", "A scan is already in progress", null)
                    return
                }
                pendingResult = result

                val options = GmsDocumentScannerOptions.Builder()
                    .setGalleryImportAllowed(true)
                    .setPageLimit(20)
                    .setResultFormats(RESULT_FORMAT_JPEG)
                    .setScannerMode(SCANNER_MODE_FULL)
                    .build()

                scanner = GmsDocumentScanning.getClient(options)
                scanner!!.getStartScanIntent(act)
                    .addOnSuccessListener { intentSender ->
                        act.startIntentSenderForResult(
                            intentSender, REQUEST_CODE, null, 0, 0, 0
                        )
                    }
                    .addOnFailureListener { e ->
                        pendingResult?.error("SCAN_FAILED", e.message, null)
                        pendingResult = null
                    }
            }

            else -> result.notImplemented()
        }
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: android.content.Intent?): Boolean {
        if (requestCode != REQUEST_CODE) return false
        val result = pendingResult ?: return true
        pendingResult = null

        if (resultCode != Activity.RESULT_OK || data == null) {
            result.success(emptyList<String>())
            return true
        }

        val scanResult = GmsDocumentScanningResult.fromActivityResultIntent(data)
        val pages = scanResult?.pages ?: run {
            result.success(emptyList<String>())
            return true
        }

        val paths = mutableListOf<String>()
        val cacheDir = context.cacheDir

        for (page in pages) {
            val uri: Uri = page.imageUri
            val destFile = File(cacheDir, "scan_page_${UUID.randomUUID()}.jpg")
            try {
                context.contentResolver.openInputStream(uri)?.use { input ->
                    FileOutputStream(destFile).use { output ->
                        input.copyTo(output)
                    }
                }
                paths.add(destFile.absolutePath)
            } catch (e: Exception) {
                // skip unreadable pages
            }
        }
        result.success(paths)
        return true
    }
}
