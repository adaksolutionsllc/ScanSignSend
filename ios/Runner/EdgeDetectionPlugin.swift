import Flutter
import Foundation
import ImageIO
import Vision

/// Platform channel: "com.scansignsend/edges"
/// Method: "detect" {path: String} → [x0, y0, … x3, y3] or nil
///
/// Finds a document's corners in an image file with Vision's document
/// segmentation (iOS 15+), on the device. Where that finds nothing (it needs
/// the Neural Engine, so the simulator never answers), Vision's rectangle
/// detector has a second try. Points are fractions of the image
/// size, origin top-left, in the order top-left, top-right, bottom-right,
/// bottom-left. nil means no document was found; a FlutterError means Vision
/// could not run, and Dart then uses its own detector. Used for photos and
/// image-only PDFs that did not come from the camera scanner; see
/// EdgeCheckService (Dart).
class EdgeDetectionPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/edges"

    private let queue = DispatchQueue(label: "com.scansignsend.edges", qos: .userInitiated)

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(EdgeDetectionPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "detect",
              let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }
        queue.async {
            let answer: Any?
            do {
                answer = try Self.detect(path: path)
            } catch {
                NSLog("EdgeDetectionPlugin: \(error)")
                answer = FlutterError(code: "vision", message: "\(error)", details: nil)
            }
            DispatchQueue.main.async { result(answer) }
        }
    }

    private static func detect(path: String) throws -> [Double]? {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        // Stored pages are already upright (imports are re-encoded with their
        // EXIF rotation applied), so the pixels are read as they are.
        let segmentation = VNDetectDocumentSegmentationRequest()
        let rectangles = VNDetectRectanglesRequest()
        rectangles.maximumObservations = 1
        rectangles.minimumConfidence = 0.8
        rectangles.minimumSize = 0.3
        rectangles.quadratureTolerance = 30
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([segmentation, rectangles])
        let found = segmentation.results?.first(where: { $0.confidence >= 0.5 })
            ?? rectangles.results?.first
        guard let doc = found else { return nil }
        // Vision's origin is bottom-left; Dart's is top-left.
        let corners = [doc.topLeft, doc.topRight, doc.bottomRight, doc.bottomLeft]
        return corners.flatMap { [Double($0.x), Double(1 - $0.y)] }
    }
}
