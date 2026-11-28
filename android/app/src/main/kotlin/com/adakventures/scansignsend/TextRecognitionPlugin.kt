package com.adakventures.scansignsend

import android.content.Context
import android.graphics.Rect
import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.TextRecognizer
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.io.File

/**
 * Platform channel "com.scansignsend/ocr": reads the text in an image file
 * with ML Kit text recognition (Latin script, model bundled in the app), on
 * the phone. Same contract as the iOS plugin (Vision):
 * - "read" {path} → {lines: [{text, box, words: [{text, box}]}]}
 *
 * Boxes are [left, top, right, bottom] in image pixels. No width or height
 * is sent: Dart reads the size from the file, as it did with the old
 * plugin. ML Kit sends usage metrics to Google when it can; the manifest
 * strips INTERNET, so it can't.
 */
class TextRecognitionPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private lateinit var context: Context
    private val recognizer: TextRecognizer by lazy {
        TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        context = binding.applicationContext
        channel = MethodChannel(binding.binaryMessenger, "com.scansignsend/ocr")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        recognizer.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        if (call.method != "read") return result.notImplemented()
        val path = call.argument<String>("path")
            ?: return result.error("args", "path missing", null)
        val image = try {
            InputImage.fromFilePath(context, Uri.fromFile(File(path)))
        } catch (e: Exception) {
            return result.error("image", e.message, null)
        }
        recognizer.process(image)
            .addOnSuccessListener { text ->
                val lines = text.textBlocks.flatMap { block ->
                    block.lines.mapNotNull { line ->
                        val box = line.boundingBox ?: return@mapNotNull null
                        mapOf(
                            "text" to line.text,
                            "box" to box.toList(),
                            "words" to line.elements.mapNotNull { e ->
                                e.boundingBox?.let { mapOf("text" to e.text, "box" to it.toList()) }
                            },
                        )
                    }
                }
                result.success(mapOf("lines" to lines))
            }
            .addOnFailureListener { e -> result.error("mlkit", e.message, null) }
    }

    private fun Rect.toList() =
        listOf(left.toDouble(), top.toDouble(), right.toDouble(), bottom.toDouble())
}
