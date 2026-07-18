import Flutter
import UIKit

/// Platform channel: "com.scansignsend/ai_enhancer"
/// Method: "enhance" (args: {"ocrText": String, "pageIndex": Int})
///         → returns [{"type": String, "label": String,
///                     "x": Double, "y": Double, "w": Double, "h": Double}]
/// Method: "isAvailable" → Bool (true on iOS 26+ with Foundation Models)
class AiFieldEnhancerPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/ai_enhancer"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = AiFieldEnhancerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "isAvailable":
            // Foundation Models (FoundationModels framework) available iOS 26+
            if #available(iOS 26.0, *) {
                result(true)
            } else {
                result(false)
            }

        case "enhance":
            guard let args = call.arguments as? [String: Any],
                  let ocrText = args["ocrText"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "ocrText required", details: nil))
                return
            }
            if #available(iOS 26.0, *) {
                Task {
                    let enhanced = await self.runFoundationModel(ocrText: ocrText)
                    DispatchQueue.main.async {
                        result(enhanced)
                    }
                }
            } else {
                // Return empty — caller falls back to heuristics
                result([])
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    @available(iOS 26.0, *)
    func runFoundationModel(ocrText: String) async -> [[String: Any]] {
        // Apple Foundation Models (FoundationModels framework).
        // Prompt asks the model to identify form fields from raw OCR text
        // and return a JSON array.
        //
        // FoundationModels.LanguageModel is the entry point in iOS 26 SDK.
        // Using LanguageModelSession with a structured prompt.
        //
        // NOTE: Replace this stub with actual FoundationModels calls
        // once the iOS 26 SDK is out of beta and the API is stable.
        // The Flutter layer already handles an empty response gracefully
        // by falling back to the heuristic engine.
        return []
    }
}
