import Foundation

/// The hand-over between the Share Extension and the app, through the App
/// Group container they share. Compiled into both targets.
///
///   Inbox/<batch>.partial/   the extension is still copying files in
///   Inbox/<batch>/           one finished share: the files + manifest.json
///
/// manifest.json lists the files in the order they were shared:
///   [{"file": "0.heic", "name": "IMG_0412.HEIC"}, …]
///
/// When the copy is done the extension renames the folder (so the app never
/// sees half a share) and opens scansignsend://import?batch=<batch>. The app
/// also looks in the inbox each time it becomes active, for a share that
/// couldn't open it. See OpenFilePlugin (app) and ShareViewController
/// (extension).
enum ShareInbox {
    static let groupID = "group.com.adakVentures.scanSignSend"
    static let scheme = "scansignsend"
    static let manifestName = "manifest.json"
    static let partialSuffix = ".partial"

    struct Entry: Codable {
        /// The file's name inside the batch folder.
        let file: String
        /// The name it had where it was shared from, for the document title.
        let name: String
    }

    /// The inbox folder, or nil when the App Group isn't available (a build
    /// signed without it).
    static var root: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("Inbox", isDirectory: true)
    }

    static func importURL(batch: String) -> URL? {
        var parts = URLComponents()
        parts.scheme = scheme
        parts.host = "import"
        parts.queryItems = [URLQueryItem(name: "batch", value: batch)]
        return parts.url
    }

    /// The batch named by an import URL. Only a UUID is accepted, so the URL
    /// can never point outside the inbox.
    static func batch(from url: URL) -> String? {
        guard url.scheme?.lowercased() == scheme, url.host == "import",
              let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?.first(where: { $0.name == "batch" })?.value,
              let uuid = UUID(uuidString: value) else { return nil }
        return uuid.uuidString
    }
}
