import Flutter
import Foundation
import PDFKit

/// Platform channel: "com.scansignsend/pdf_password"
/// Method: "protect" {input: String, output: String, password: String} → Bool
///
/// Writes a password-protected copy of the PDF at `input` to `output` with
/// PDFKit, so the encryption is the operating system's. The password opens
/// the file and is also the owner password. It is never stored. Used by Send
/// → "Password-protect"; see PdfPasswordService (Dart).
///
/// PDFKit rewrites radio-button groups when it writes a form (the radio flag
/// moves from the field to its buttons), so Dart doesn't offer this for a
/// fillable form with radio buttons.
class PdfPasswordPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/pdf_password"

    private let queue = DispatchQueue(label: "com.scansignsend.pdf_password", qos: .userInitiated)

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(PdfPasswordPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "protect",
              let args = call.arguments as? [String: Any],
              let input = args["input"] as? String,
              let output = args["output"] as? String,
              let password = args["password"] as? String,
              !password.isEmpty else {
            result(FlutterMethodNotImplemented)
            return
        }
        queue.async {
            guard let doc = PDFDocument(url: URL(fileURLWithPath: input)) else {
                DispatchQueue.main.async {
                    result(FlutterError(code: "unreadable", message: "Cannot open the PDF", details: nil))
                }
                return
            }
            let ok = doc.write(
                to: URL(fileURLWithPath: output),
                withOptions: [.userPasswordOption: password, .ownerPasswordOption: password]
            )
            DispatchQueue.main.async { result(ok) }
        }
    }
}
