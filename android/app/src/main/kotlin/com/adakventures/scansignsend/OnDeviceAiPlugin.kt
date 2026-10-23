package com.adakventures.scansignsend

import android.os.Build
import androidx.annotation.RequiresApi
import com.google.mlkit.genai.common.FeatureStatus
import com.google.mlkit.genai.prompt.Generation
import com.google.mlkit.genai.prompt.GenerativeModel
import com.google.mlkit.genai.prompt.TextPart
import com.google.mlkit.genai.prompt.generateContentRequest
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.launch

/**
 * Platform channel "com.scansignsend/on_device_ai": Gemini Nano through ML Kit's
 * Prompt API, on the phone. Same contract as the iOS plugin:
 * - "status" → available | notReady | unsupported
 * - "classifyDocument" {title, text, categories} → a category key or null
 *
 * The Prompt API needs Android 8.0 (API 26) while the app supports 7.0, so the
 * library is merged with tools:overrideLibrary and every use of it lives in
 * [GeminiNano], which is only created on API 26+. Android 7 phones answer
 * "unsupported" and Dart sorts by keywords.
 */
class OnDeviceAiPlugin : FlutterPlugin, MethodChannel.MethodCallHandler {

    private lateinit var channel: MethodChannel
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val nano: GeminiNano? by lazy {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) GeminiNano() else null
    }

    override fun onAttachedToEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(binding.binaryMessenger, "com.scansignsend/on_device_ai")
        channel.setMethodCallHandler(this)
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        channel.setMethodCallHandler(null)
        scope.cancel()
        nano?.close()
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        val nano = nano
        when (call.method) {
            "status" -> {
                if (nano == null) return result.success("unsupported")
                scope.launch {
                    result.success(runCatching { nano.status() }.getOrDefault("unsupported"))
                }
            }
            "classifyDocument" -> {
                val title = call.argument<String>("title") ?: ""
                val text = call.argument<String>("text") ?: ""
                val categories = call.argument<List<String>>("categories") ?: emptyList()
                if (nano == null) return result.success(null)
                scope.launch {
                    result.success(runCatching { nano.classify(title, text, categories) }.getOrNull())
                }
            }
            else -> result.notImplemented()
        }
    }
}

@RequiresApi(Build.VERSION_CODES.O)
private class GeminiNano {
    private val model: GenerativeModel = Generation.getClient()

    suspend fun status(): String = when (model.checkStatus()) {
        FeatureStatus.AVAILABLE -> "available"
        // The system downloads the model on its own schedule; the app never
        // starts a download.
        FeatureStatus.DOWNLOADABLE, FeatureStatus.DOWNLOADING -> "notReady"
        else -> "unsupported"
    }

    suspend fun classify(title: String, text: String, categories: List<String>): String? {
        if (model.checkStatus() != FeatureStatus.AVAILABLE) return null
        val prompt = """
            Sort this document into one category. Categories:
            tax (tax forms and returns), money (banking, loans, investments),
            insurance, medical (health and patient forms), home (renting,
            leases, property), work (jobs, employment, pay), school (students,
            education), id_travel (passports, IDs, visas, travel), legal
            (contracts, affidavits, powers of attorney), bills (invoices,
            receipts, bills). Answer none if it fits none or you are not sure.
            Reply with the category word only.

            Title: $title

            Text:
            $text
        """.trimIndent()
        val response = model.generateContent(
            generateContentRequest(TextPart(prompt)) {
                temperature = 0f
                topK = 1
                candidateCount = 1
                maxOutputTokens = 8
            },
        )
        val answer = response.candidates.firstOrNull()?.text
            ?.trim()?.lowercase()?.trim('.', '"', '\'', ' ', '\n')
            ?: return null
        return answer.takeIf { it in categories }
    }

    fun close() = model.close()
}
