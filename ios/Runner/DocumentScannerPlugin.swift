import Flutter
import UIKit
import VisionKit

/// Platform channel: "com.scansignsend/scanner"
/// Method: "scan" → returns [String] (list of temp image file paths)
/// Method: "scanAvailable" → returns Bool
class DocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {

    static let channelName = "com.scansignsend/scanner"

    private var pendingResult: FlutterResult?
    private weak var viewController: UIViewController?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = DocumentScannerPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "scanAvailable":
            result(VNDocumentCameraViewController.isSupported)

        case "scan":
            guard VNDocumentCameraViewController.isSupported else {
                result(FlutterError(code: "UNAVAILABLE",
                                    message: "Document scanner not supported on this device",
                                    details: nil))
                return
            }
            guard pendingResult == nil else {
                result(FlutterError(code: "ALREADY_ACTIVE",
                                    message: "A scan is already in progress",
                                    details: nil))
                return
            }
            pendingResult = result
            DispatchQueue.main.async {
                let scanner = VNDocumentCameraViewController()
                scanner.delegate = self
                self.viewController = UIApplication.shared.keyWindowRootViewController
                self.viewController?.present(scanner, animated: true)
            }

        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: VNDocumentCameraViewControllerDelegate

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFinishWith scan: VNDocumentCameraScan
    ) {
        controller.dismiss(animated: true)
        var paths: [String] = []

        // Save directly to Documents/scan_staging/ — permanent, never cleared by OS
        let fm = FileManager.default
        guard let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            pendingResult?(FlutterError(code: "STORAGE_ERROR",
                                        message: "Cannot access Documents directory",
                                        details: nil))
            pendingResult = nil
            return
        }
        let stagingDir = docsDir.appendingPathComponent("scan_staging", isDirectory: true)
        try? fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)

        let batchId = UUID().uuidString
        for i in 0..<scan.pageCount {
            let image = scan.imageOfPage(at: i)
            let fileName = "scan_\(batchId)_page_\(i).jpg"
            let url = stagingDir.appendingPathComponent(fileName)
            if let data = image.jpegData(compressionQuality: 0.92) {
                try? data.write(to: url)
                paths.append(url.path)
            }
        }
        pendingResult?(paths)
        pendingResult = nil
    }

    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
        pendingResult?([String]())
        pendingResult = nil
    }

    func documentCameraViewController(
        _ controller: VNDocumentCameraViewController,
        didFailWithError error: Error
    ) {
        controller.dismiss(animated: true)
        pendingResult?(FlutterError(code: "SCAN_FAILED",
                                    message: error.localizedDescription,
                                    details: nil))
        pendingResult = nil
    }
}

private extension UIApplication {
    var keyWindowRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}
