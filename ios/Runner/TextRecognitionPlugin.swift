import Flutter
import Foundation
import ImageIO
import Vision

/// Platform channel: "com.scansignsend/ocr"
/// Method: "read" {path: String} → {width, height, lines: [{text, box, words}]}
///
/// Reads the text in an image file with Vision's text recognizer, on the
/// device. Boxes are [left, top, right, bottom] in image pixels, origin
/// top-left; a word is any run of characters between spaces, as with ML Kit
/// on Android, so underscores and dotted leaders stay words. Vision replaces
/// ML Kit on iOS: ML Kit sends usage metrics to Google, and this app sends
/// nothing. Same contract as TextRecognitionPlugin.kt; see OcrService (Dart).
class TextRecognitionPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/ocr"

    /// The app's locales that write in Latin script (the only script read).
    private static let languages = ["en-US", "fr-FR", "es-ES", "pt-BR"]

    private let queue = DispatchQueue(label: "com.scansignsend.ocr", qos: .userInitiated)

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(TextRecognitionPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "read",
              let args = call.arguments as? [String: Any],
              let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }
        queue.async {
            let answer: Any
            do {
                answer = try Self.read(path: path)
            } catch {
                NSLog("TextRecognitionPlugin: \(error)")
                answer = FlutterError(code: "vision", message: "\(error)", details: nil)
            }
            DispatchQueue.main.async { result(answer) }
        }
    }

    private static func read(path: String) throws -> [String: Any] {
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return ["width": 0, "height": 0, "lines": []]
        }
        let w = Double(image.width), h = Double(image.height)
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        // Keep what is printed: correction turns "____" and codes into words.
        request.usesLanguageCorrection = false
        // Form text is small: 9 pt on an A4 scan is about 1/100 of its height.
        request.minimumTextHeight = 0.006
        let supported = (try? request.supportedRecognitionLanguages()) ?? []
        request.recognitionLanguages = languages.filter(supported.contains)
        // Stored pages are already upright (imports are re-encoded with their
        // EXIF rotation applied), so the pixels are read as they are.
        let handler = VNImageRequestHandler(cgImage: image, orientation: .up, options: [:])
        try handler.perform([request])

        // Vision's boxes are fractions of the image, origin bottom-left.
        func pixels(_ r: CGRect) -> [Double] {
            [Double(r.minX) * w, (1 - Double(r.maxY)) * h,
             Double(r.maxX) * w, (1 - Double(r.minY)) * h]
        }

        var lines: [[String: Any]] = []
        for observation in request.results ?? [] {
            guard let top = observation.topCandidates(1).first else { continue }
            let text = top.string
            let lineBox = pixels(observation.boundingBox)
            let ranges = wordRanges(in: text)
            var words: [[String: Any]] = []
            for range in ranges {
                guard let box = try? top.boundingBox(for: range)?.boundingBox else { continue }
                words.append(["text": String(text[range]), "box": pixels(box)])
            }
            // Some iOS versions give every word the whole line's box. Then
            // share the line out by characters instead.
            if words.count != ranges.count || (ranges.count > 1 && wordsCoverLine(words, lineBox)) {
                words = shareOut(text: text, ranges: ranges, lineBox: lineBox)
            }
            lines.append(["text": text, "box": lineBox, "words": words])
        }
        return ["width": w, "height": h, "lines": lines]
    }

    /// Runs of non-space characters.
    private static func wordRanges(in text: String) -> [Range<String.Index>] {
        var out: [Range<String.Index>] = []
        var start: String.Index?
        var i = text.startIndex
        while i < text.endIndex {
            if text[i].isWhitespace {
                if let s = start { out.append(s..<i); start = nil }
            } else if start == nil {
                start = i
            }
            i = text.index(after: i)
        }
        if let s = start { out.append(s..<text.endIndex) }
        return out
    }

    /// True when the first two words each span (almost) the whole line.
    private static func wordsCoverLine(_ words: [[String: Any]], _ line: [Double]) -> Bool {
        let width = line[2] - line[0]
        guard width > 0 else { return false }
        return words.prefix(2).allSatisfy { word in
            guard let b = word["box"] as? [Double] else { return false }
            return (b[2] - b[0]) >= width * 0.95
        }
    }

    /// Word boxes estimated from each word's place among the characters.
    private static func shareOut(
        text: String, ranges: [Range<String.Index>], lineBox: [Double]
    ) -> [[String: Any]] {
        let count = Double(max(text.count, 1))
        let width = lineBox[2] - lineBox[0]
        return ranges.map { range in
            let from = Double(text.distance(from: text.startIndex, to: range.lowerBound))
            let to = Double(text.distance(from: text.startIndex, to: range.upperBound))
            return [
                "text": String(text[range]),
                "box": [lineBox[0] + width * from / count, lineBox[1],
                        lineBox[0] + width * to / count, lineBox[3]],
            ]
        }
    }
}
