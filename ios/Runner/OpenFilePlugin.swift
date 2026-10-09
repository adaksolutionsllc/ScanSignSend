import Flutter
import Foundation
import UniformTypeIdentifiers

/// Platform channel: "com.scansignsend/open_file"
///
/// Receives PDFs the user opens with Scan Sign Send from Files, Mail, Safari
/// or a share sheet ("Open in…"), declared by CFBundleDocumentTypes in
/// Info.plist. Each one is copied into the app's temp folder and queued until
/// Dart collects it, because a cold launch delivers the file before the
/// Flutter UI is listening.
///
/// Methods:
///   Dart → native  "takePending" → [{path: String, name: String}]
///   native → Dart  "pending"     — a file was queued; call takePending
/// See OpenedFileService (Dart).
class OpenFilePlugin: NSObject, FlutterPlugin, FlutterSceneLifeCycleDelegate {

    static let channelName = "com.scansignsend/open_file"

    private var channel: FlutterMethodChannel?
    private var pending: [[String: String]] = []

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let instance = OpenFilePlugin()
        instance.channel = channel
        registrar.addMethodCallDelegate(instance, channel: channel)
        registrar.addSceneDelegate(instance)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "takePending":
            result(pending)
            pending.removeAll()
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // Cold launch: the file arrives with the scene connection.
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions?
    ) -> Bool {
        guard let contexts = connectionOptions?.urlContexts,
              !contexts.isEmpty else { return false }
        return receive(contexts)
    }

    // App already running.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) -> Bool {
        return receive(URLContexts)
    }

    private func receive(_ contexts: Set<UIOpenURLContext>) -> Bool {
        var handled = false
        for context in contexts {
            let url = context.url
            guard url.isFileURL, Self.isPdf(url),
                  let copy = Self.copyToTemp(url) else { continue }
            pending.append(["path": copy.path, "name": url.lastPathComponent])
            handled = true
        }
        if handled { channel?.invokeMethod("pending", arguments: nil) }
        return handled
    }

    private static func isPdf(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return type.conforms(to: .pdf)
        }
        return url.pathExtension.lowercased() == "pdf"
    }

    /// Copies the opened file somewhere the app owns. iOS hands over either a
    /// copy in Documents/Inbox (removed here, so it never shows up as a stray
    /// file in our container) or a security-scoped URL into another app's
    /// storage that is only readable while access is held.
    private static func copyToTemp(_ url: URL) -> URL? {
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }

        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("opened", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let dest = dir.appendingPathComponent(url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            // Coordinated read: the file may live in iCloud Drive or a
            // third-party File Provider that has to download it first.
            var coordError: NSError?
            var copyError: Error?
            NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordError) { readable in
                do {
                    try FileManager.default.copyItem(at: readable, to: dest)
                } catch {
                    copyError = error
                }
            }
            if let error = coordError ?? copyError { throw error }
        } catch {
            NSLog("OpenFilePlugin: could not copy \(url.lastPathComponent): \(error)")
            return nil
        }
        if url.path.contains("/Documents/Inbox/") {
            try? FileManager.default.removeItem(at: url)
        }
        return dest
    }
}
