import AppIntents
import Flutter
import Foundation

/// Platform channel: "com.scansignsend/shortcuts"
///
/// Siri, Spotlight and the Shortcuts app can run three actions, the same as
/// the home-screen quick actions: Scan a document, Open a PDF, Fill my last
/// draft. Each opens the app; the action is queued here until Dart takes it,
/// because a cold launch runs the intent before the Flutter UI is listening.
///
/// Methods:
///   Dart → native  "takePending" → String? (a QuickActionType, or nil)
///   native → Dart  "pending"     — an action was queued; call takePending
/// See QuickActionsSetup (Dart).
final class ShortcutsPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/shortcuts"

    private static var pending: String?
    private static weak var instance: ShortcutsPlugin?
    private var channel: FlutterMethodChannel?

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        let plugin = ShortcutsPlugin()
        plugin.channel = channel
        instance = plugin
        registrar.addMethodCallDelegate(plugin, channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "takePending":
            result(Self.pending)
            Self.pending = nil
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Called by an intent, on the main thread.
    static func run(_ type: String) {
        pending = type
        instance?.channel?.invokeMethod("pending", arguments: nil)
    }
}

// The types match QuickActionType in quick_actions_setup.dart.

@available(iOS 16.0, *)
struct ScanDocumentIntent: AppIntent {
    static var title: LocalizedStringResource = "Scan a document"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutsPlugin.run("scan")
        return .result()
    }
}

@available(iOS 16.0, *)
struct OpenPdfIntent: AppIntent {
    static var title: LocalizedStringResource = "Open a PDF"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutsPlugin.run("open_pdf")
        return .result()
    }
}

@available(iOS 16.0, *)
struct FillLastDraftIntent: AppIntent {
    static var title: LocalizedStringResource = "Fill my last draft"
    static var openAppWhenRun = true

    @MainActor
    func perform() async throws -> some IntentResult {
        ShortcutsPlugin.run("last_draft")
        return .result()
    }
}

/// Shown in Siri, Spotlight and the Shortcuts app with no setup. Phrases
/// are translated in each <locale>.lproj/AppShortcuts.strings; every phrase
/// must name the app.
@available(iOS 16.0, *)
struct ScanSignSendShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ScanDocumentIntent(),
            phrases: [
                "Scan a document with \(.applicationName)",
                "Scan with \(.applicationName)",
            ]
        )
        AppShortcut(
            intent: OpenPdfIntent(),
            phrases: [
                "Open a PDF in \(.applicationName)",
            ]
        )
        AppShortcut(
            intent: FillLastDraftIntent(),
            phrases: [
                "Fill my last draft in \(.applicationName)",
                "Fill my form with my details in \(.applicationName)",
            ]
        )
    }
}
