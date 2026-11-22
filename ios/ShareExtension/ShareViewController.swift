import ImageIO
import UIKit
import UniformTypeIdentifiers

/// Photos → Share → Scan Sign Send (and the same from Files, Mail, Safari…).
///
/// Copies the shared photos and PDFs into the App Group inbox, then opens the
/// app, which imports them like files opened with "Open in…". No Flutter and
/// no database here: an extension has about 120 MB of memory, and the app
/// does the real work. See ShareInbox for the hand-over.
final class ShareViewController: UIViewController {

    /// The photo types the importer reads; any other image is converted to
    /// JPEG first.
    private static let photoTypes: [UTType] = [.jpeg, .png, .heic, .heif]

    private let spinner = UIActivityIndicatorView(style: .large)
    private let message = UILabel()
    private let doneButton = UIButton(type: .system)
    private var started = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        message.text = Self.text("share.adding")
        message.font = .preferredFont(forTextStyle: .headline)
        message.adjustsFontForContentSizeCategory = true
        message.textAlignment = .center
        message.numberOfLines = 0

        doneButton.setTitle(Self.text("share.done"), for: .normal)
        doneButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        doneButton.isHidden = true
        doneButton.addTarget(self, action: #selector(finish), for: .touchUpInside)

        spinner.startAnimating()

        let stack = UIStackView(arrangedSubviews: [spinner, message, doneButton])
        stack.axis = .vertical
        stack.spacing = 20
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo: view.layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: view.layoutMarginsGuide.trailingAnchor),
        ])
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !started else { return }
        started = true
        collect()
    }

    // MARK: - Copying into the inbox

    private func collect() {
        let providers = (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
        guard let root = ShareInbox.root else {
            NSLog("ShareExtension: no App Group container")
            return show(Self.text("share.failed"))
        }
        let batch = UUID().uuidString
        let partial = root.appendingPathComponent(batch + ShareInbox.partialSuffix, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: partial, withIntermediateDirectories: true)
        } catch {
            NSLog("ShareExtension: \(error)")
            return show(Self.text("share.failed"))
        }

        // One at a time: a converted photo is decoded in full, and two at
        // once could pass the extension's memory limit.
        var entries: [ShareInbox.Entry] = []
        func next(_ i: Int) {
            guard i < providers.count else {
                return DispatchQueue.main.async {
                    self.hand(entries, batch: batch, from: partial, root: root)
                }
            }
            copy(providers[i], index: i, into: partial) { entry in
                if let entry { entries.append(entry) }
                next(i + 1)
            }
        }
        next(0)
    }

    /// Copies one shared item into [dir] as "<index>.<ext>".
    private func copy(
        _ provider: NSItemProvider,
        index: Int,
        into dir: URL,
        done: @escaping (ShareInbox.Entry?) -> Void
    ) {
        let registered = provider.registeredTypeIdentifiers.compactMap { UTType($0) }
        let type: UTType
        let convert: Bool
        if registered.contains(where: { $0.conforms(to: .pdf) }) {
            (type, convert) = (.pdf, false)
        } else if let photo = registered.first(where: { t in
            Self.photoTypes.contains { t.conforms(to: $0) }
        }) {
            (type, convert) = (photo, false)
        } else if registered.contains(where: { $0.conforms(to: .image) }) {
            (type, convert) = (.image, true)
        } else {
            return done(nil)
        }

        provider.loadFileRepresentation(forTypeIdentifier: type.identifier) { url, error in
            // The file at url is deleted when this handler returns.
            guard let url else {
                NSLog("ShareExtension: \(error?.localizedDescription ?? "no file")")
                return done(nil)
            }
            let ext = convert ? "jpg" : Self.fileExtension(of: url, type: type)
            let dest = dir.appendingPathComponent("\(index).\(ext)")
            let ok = convert ? Self.convertToJpeg(url, to: dest) : Self.copyFile(url, to: dest)
            guard ok else { return done(nil) }
            done(ShareInbox.Entry(
                file: dest.lastPathComponent,
                name: "\(Self.baseName(provider.suggestedName, url)).\(ext)"))
        }
    }

    /// The shared file's name without its extension ("IMG_0412").
    private static func baseName(_ suggested: String?, _ url: URL) -> String {
        let name = suggested.flatMap { $0.isEmpty ? nil : $0 } ?? url.lastPathComponent
        let ext = (name as NSString).pathExtension.lowercased()
        let known = ["pdf", "jpg", "jpeg", "png", "heic", "heif", "tif", "tiff", "gif", "webp"]
        return known.contains(ext) ? (name as NSString).deletingPathExtension : name
    }

    private static func fileExtension(of url: URL, type: UTType) -> String {
        let ext = url.pathExtension.lowercased()
        if ["pdf", "jpg", "jpeg", "png", "heic", "heif"].contains(ext) { return ext }
        return type.preferredFilenameExtension ?? "jpg"
    }

    private static func copyFile(_ url: URL, to dest: URL) -> Bool {
        do {
            try FileManager.default.copyItem(at: url, to: dest)
            return true
        } catch {
            NSLog("ShareExtension: \(error)")
            return false
        }
    }

    /// TIFF, GIF, WebP and the like, as JPEG, keeping orientation.
    private static func convertToJpeg(_ url: URL, to dest: URL) -> Bool {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let out = CGImageDestinationCreateWithURL(
                  dest as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return false }
        CGImageDestinationAddImageFromSource(
            out, source, 0,
            [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        return CGImageDestinationFinalize(out)
    }

    /// Finishes the batch and opens the app with it.
    private func hand(_ entries: [ShareInbox.Entry], batch: String, from partial: URL, root: URL) {
        let fm = FileManager.default
        guard !entries.isEmpty else {
            try? fm.removeItem(at: partial)
            return show(Self.text("share.nothing"))
        }
        do {
            let manifest = try JSONEncoder().encode(entries)
            try manifest.write(to: partial.appendingPathComponent(ShareInbox.manifestName))
            try fm.moveItem(at: partial, to: root.appendingPathComponent(batch, isDirectory: true))
        } catch {
            NSLog("ShareExtension: \(error)")
            try? fm.removeItem(at: partial)
            return show(Self.text("share.failed"))
        }
        guard let url = ShareInbox.importURL(batch: batch) else { return finish() }
        openApp(url) { opened in
            DispatchQueue.main.async {
                // The batch is kept either way: the app picks it up the
                // next time it comes to the front.
                if opened { self.finish() } else { self.show(Self.text("share.openApp")) }
            }
        }
    }

    // MARK: - Opening the app

    /// Extensions have no API to open their app; UIApplication is reached
    /// through the responder chain instead. When that fails, the user is
    /// told to open the app, which then finds the batch in the inbox.
    private func openApp(_ url: URL, done: @escaping (Bool) -> Void) {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if r is UIApplication, r.responds(to: selector) {
                typealias Open = @convention(c) (
                    AnyObject, Selector, NSURL, NSDictionary,
                    (@convention(block) (Bool) -> Void)?
                ) -> Void
                let open = unsafeBitCast(r.method(for: selector), to: Open.self)
                open(r, selector, url as NSURL, NSDictionary(), { done($0) })
                return
            }
            responder = r.next
        }
        done(false)
    }

    // MARK: - UI

    private func show(_ text: String) {
        spinner.stopAnimating()
        spinner.isHidden = true
        message.text = text
        doneButton.isHidden = false
    }

    @objc private func finish() {
        extensionContext?.completeRequest(returningItems: nil)
    }

    private static func text(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }
}
