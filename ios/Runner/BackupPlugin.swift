import Flutter
import Foundation

/// Platform channel: "com.scansignsend/backup"
/// Method: "apply" {include: Bool, path: String} — sets whether the app's
/// Documents directory (database, scanned pages, signatures, exports) is part
/// of the user's iCloud Backup. Excluding a directory excludes its contents,
/// including files created in it later. Driven by the "Include in device
/// backup" switch in Settings; off by default. See BackupService (Dart).
class BackupPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/backup"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(BackupPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        guard call.method == "apply",
              let args = call.arguments as? [String: Any],
              let include = args["include"] as? Bool,
              let path = args["path"] as? String else {
            result(FlutterMethodNotImplemented)
            return
        }
        var url = URL(fileURLWithPath: path, isDirectory: true)
        var values = URLResourceValues()
        values.isExcludedFromBackup = !include
        do {
            try url.setResourceValues(values)
            result(nil)
        } catch {
            result(FlutterError(code: "BACKUP_FLAG_FAILED",
                                message: error.localizedDescription,
                                details: nil))
        }
    }
}
