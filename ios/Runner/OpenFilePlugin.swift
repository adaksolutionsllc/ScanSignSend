import Flutter
import Foundation
import UniformTypeIdentifiers

/// Platform channel: "com.scansignsend/open_file"
///
/// Receives PDFs and photos the user opens with Scan Sign Send from Files, Mail, Safari
/// or a share sheet ("Open in…"), declared by CFBundleDocumentTypes in
/// Info.plist, and the ones shared through the Share Extension (Photos →
/// Share), which leaves them in the App Group inbox (ShareInbox). Each one is
/// copied into the app's temp folder and queued until Dart collects it,
/// because a cold launch delivers the file before the Flutter UI is
/// listening.
///
/// Methods:
///   Dart → native  "takePending" → [{path: String, name: String, batch: String}]
///                  (files opened together share a batch)
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
        NotificationCenter.default.addObserver(
            instance, selector: #selector(enteredForeground),
            name: UIScene.willEnterForegroundNotification, object: nil)
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

    // A share that couldn't open the app is picked up when the app comes to
    // the front, on a cold launch too. (A notification, because Flutter
    // doesn't pass the scene's foreground events on to this plugin.)
    @objc private func enteredForeground() {
        if takeInbox() { channel?.invokeMethod("pending", arguments: nil) }
    }

    private func receive(_ contexts: Set<UIOpenURLContext>) -> Bool {
        var handled = false
        let batch = UUID().uuidString
        for context in contexts {
            let url = context.url
            if let shared = ShareInbox.batch(from: url) {
                handled = takeShared(shared) || handled
                continue
            }
            guard url.isFileURL, Self.isSupported(url),
                  let copy = Self.copyToTemp(url) else { continue }
            pending.append(["path": copy.path, "name": url.lastPathComponent, "batch": batch])
            handled = true
        }
        if handled { channel?.invokeMethod("pending", arguments: nil) }
        return handled
    }

    // MARK: - Share Extension inbox

    /// Every finished share in the inbox. A half-written one older than an
    /// hour (the extension was stopped) is deleted.
    private func takeInbox() -> Bool {
        guard let root = ShareInbox.root,
              let items = try? FileManager.default.contentsOfDirectory(
                  at: root, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return false }
        var taken = false
        for item in items.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let name = item.lastPathComponent
            if name.hasSuffix(ShareInbox.partialSuffix) {
                let modified = (try? item.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate ?? .distantPast
                if modified < Date().addingTimeInterval(-3600) {
                    try? FileManager.default.removeItem(at: item)
                }
            } else if UUID(uuidString: name) != nil {
                taken = takeShared(name) || taken
            }
        }
        return taken
    }

    /// Queues the files of one share, in the order they were shared, as one
    /// batch, then deletes the share from the inbox.
    private func takeShared(_ batch: String) -> Bool {
        guard let dir = ShareInbox.root?.appendingPathComponent(batch, isDirectory: true),
              FileManager.default.fileExists(atPath: dir.path) else { return false }
        defer { try? FileManager.default.removeItem(at: dir) }
        guard let data = try? Data(contentsOf: dir.appendingPathComponent(ShareInbox.manifestName)),
              let entries = try? JSONDecoder().decode([ShareInbox.Entry].self, from: data)
        else { return false }
        var taken = false
        for entry in entries {
            let file = dir.appendingPathComponent((entry.file as NSString).lastPathComponent)
            let name = (entry.name as NSString).lastPathComponent
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("opened", isDirectory: true)
                .appendingPathComponent(UUID().uuidString, isDirectory: true)
                .appendingPathComponent(name.isEmpty ? file.lastPathComponent : name)
            do {
                try FileManager.default.createDirectory(
                    at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: file, to: dest)
            } catch {
                NSLog("OpenFilePlugin: could not take shared \(entry.file): \(error)")
                continue
            }
            pending.append(["path": dest.path, "name": dest.lastPathComponent, "batch": batch])
            taken = true
        }
        return taken
    }

    /// PDFs and the photo types the importer reads (CFBundleDocumentTypes).
    private static func isSupported(_ url: URL) -> Bool {
        if let type = try? url.resourceValues(forKeys: [.contentTypeKey]).contentType {
            return [.pdf, .jpeg, .png, .heic, .heif].contains { type.conforms(to: $0) }
        }
        return ["pdf", "jpg", "jpeg", "png", "heic", "heif"]
            .contains(url.pathExtension.lowercased())
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
