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
                // Present from the top-most controller. Presenting from the
                // root fails silently whenever something is already shown on
                // top of it (a sheet, an alert, the privacy overlay), and the
                // Dart side then waited forever on a result that never came.
                guard let host = UIApplication.shared.topMostViewController else {
                    self.pendingResult?(FlutterError(code: "NO_PRESENTER",
                                                     message: "No view controller to present the scanner from",
                                                     details: nil))
                    self.pendingResult = nil
                    return
                }
                let scanner = VNDocumentCameraViewController()
                scanner.delegate = self
                self.viewController = host
                host.present(scanner, animated: true)
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

        // Stage in the temp directory: it's never included in iCloud Backup,
        // and the Dart side moves each page into Documents/pages/ straight
        // away. (Staging used to live in Documents/scan_staging, which was
        // backed up and kept any page orphaned by a crash forever.)
        let fm = FileManager.default
        let stagingDir = fm.temporaryDirectory.appendingPathComponent("scan_staging", isDirectory: true)
        try? fm.createDirectory(at: stagingDir, withIntermediateDirectories: true)
        // Remove what the old location may still hold from earlier builds.
        if let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask).first {
            try? fm.removeItem(at: docsDir.appendingPathComponent("scan_staging", isDirectory: true))
        }

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
    /// The controller currently on top: the key window's root, followed down
    /// through anything it (or its descendants) is presenting.
    var topMostViewController: UIViewController? {
        var top = connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
        while let presented = top?.presentedViewController, !presented.isBeingDismissed {
            top = presented
        }
        return top
    }
}
