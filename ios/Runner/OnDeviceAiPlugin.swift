import Flutter
import UIKit
#if canImport(FoundationModels)
import FoundationModels
#endif

/// Platform channel "com.scansignsend/on_device_ai" — the phone's own language
/// model (Apple Foundation Models, iOS 26+). Everything runs on the device.
///
/// Methods:
/// - "status" → String: available | deviceNotEligible | osTooOld | notEnabled
///   | notReady | languageUnsupported | unsupported
/// - "classifyDocument" {title, text, categories} → String? (a category key,
///   or nil when the model isn't sure). Dart validates the key and falls back
///   to keyword sorting on nil or any error.
///
/// FoundationModels is weak-linked (OTHER_LDFLAGS) so the app still launches
/// on iOS 15–25.
class OnDeviceAiPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/on_device_ai"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(OnDeviceAiPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "status":
            result(Self.status())

        case "classifyDocument":
            guard let args = call.arguments as? [String: Any],
                  let title = args["title"] as? String,
                  let text = args["text"] as? String else {
                result(FlutterError(code: "BAD_ARGS", message: "title and text required", details: nil))
                return
            }
            #if canImport(FoundationModels)
            if #available(iOS 26.0, *) {
                Task {
                    let key = await Self.classify(title: title, text: text)
                    DispatchQueue.main.async { result(key) }
                }
                return
            }
            #endif
            result(nil)

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// iPhones that can run Apple Intelligence: A17 Pro and later. Used only
    /// to tell an eligible phone on old iOS ("update iOS") from one that will
    /// never have the model.
    private static func hardwareIsEligible() -> Bool {
        var info = utsname()
        uname(&info)
        let id = withUnsafePointer(to: &info.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) { String(cString: $0) }
        }
        // "iPhone16,1" = 15 Pro; iPhone 16 and later are iPhone17,x and up.
        if id.hasPrefix("iPhone"),
           let major = Int(id.dropFirst("iPhone".count).split(separator: ",").first ?? "") {
            return major >= 16
        }
        // iPads with M1 or later report iPad13,4+; keep it simple and let the
        // OS decide on iOS 26.
        return false
    }

    static func status() -> String {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                return model.supportsLocale() ? "available" : "languageUnsupported"
            case .unavailable(.deviceNotEligible):
                return "deviceNotEligible"
            case .unavailable(.appleIntelligenceNotEnabled):
                return "notEnabled"
            case .unavailable(.modelNotReady):
                return "notReady"
            case .unavailable:
                return "unsupported"
            }
        }
        #endif
        return hardwareIsEligible() ? "osTooOld" : "deviceNotEligible"
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    @Generable
    struct Pick {
        @Guide(
            description: "The category this document belongs to, or none if it fits none of them or you are unsure.",
            .anyOf([
                "tax", "money", "insurance", "medical", "home", "work",
                "school", "id_travel", "legal", "bills", "none",
            ])
        )
        var category: String
    }

    @available(iOS 26.0, *)
    static func classify(title: String, text: String) async -> String? {
        let instructions = """
        You sort a person's documents into one category. Categories:
        tax (tax forms and returns), money (banking, loans, investments),
        insurance, medical (health and patient forms), home (renting, leases,
        property), work (jobs, employment, pay), school (students, education),
        id_travel (passports, IDs, visas, travel), legal (contracts,
        affidavits, powers of attorney), bills (invoices, receipts, bills).
        Answer none when the document fits none of them or you are not sure.
        """
        do {
            let session = LanguageModelSession(instructions: instructions)
            let response = try await session.respond(
                to: "Title: \(title)\n\nText:\n\(text)",
                generating: Pick.self,
                options: GenerationOptions(temperature: 0)
            )
            let key = response.content.category
            return key == "none" ? nil : key
        } catch {
            return nil
        }
    }
    #endif
}
