import Flutter
import Foundation
import Security
import StoreKit

/// Platform channel: "com.scansignsend/entitlement"
/// Keeps the number of free documents already used in the Keychain, which
/// survives deleting and reinstalling the app (only erasing the phone clears
/// it), so reinstalling doesn't reset the free allowance. It holds one
/// number and nothing about the user or their documents.
///
/// "ThisDeviceOnly": never synced to iCloud Keychain or restored to another
/// phone. The allowance is per device, like the rest of the app.
///
/// Methods: "getFreeUsed" → Int (0 if unset); "setFreeUsed" {value: Int};
/// "originalAppVersion" → {supported: Bool, version: String?} — the build
/// number of the user's first App Store download, from Apple's signed
/// AppTransaction (iOS 16+). Builds up to 9 were sold at $9.99 upfront, so
/// those buyers keep full access now the app is free with an unlock.
class EntitlementPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/entitlement"
    private static let service = "com.adakventures.scansignsend.allowance"
    private static let account = "freeDocumentsUsed"

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: channelName,
                                           binaryMessenger: registrar.messenger())
        registrar.addMethodCallDelegate(EntitlementPlugin(), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getFreeUsed":
            result(Self.read())
        case "setFreeUsed":
            guard let args = call.arguments as? [String: Any],
                  let value = args["value"] as? Int else {
                result(FlutterError(code: "BAD_ARGS", message: nil, details: nil))
                return
            }
            result(Self.write(value))
        case "originalAppVersion":
            guard #available(iOS 16.0, *) else {
                result(["supported": false])
                return
            }
            Task {
                var version: String?
                // Only a verified production transaction counts: TestFlight
                // and Xcode builds report "1.0" and must see the paywall.
                if case .verified(let tx)? = try? await AppTransaction.shared,
                   tx.environment == .production {
                    version = tx.originalAppVersion
                }
                await MainActor.run {
                    result(["supported": true, "version": version as Any])
                }
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private static var query: [String: Any] {
        [kSecClass as String: kSecClassGenericPassword,
         kSecAttrService as String: service,
         kSecAttrAccount as String: account]
    }

    private static func read() -> Int {
        var q = query
        q[kSecReturnData as String] = true
        q[kSecMatchLimit as String] = kSecMatchLimitOne
        var item: CFTypeRef?
        guard SecItemCopyMatching(q as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let text = String(data: data, encoding: .utf8),
              let value = Int(text) else { return 0 }
        return value
    }

    private static func write(_ value: Int) -> Bool {
        let data = Data(String(value).utf8)
        let update: [String: Any] = [kSecValueData as String: data]
        let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        if status == errSecItemNotFound {
            var add = query
            add[kSecValueData as String] = data
            add[kSecAttrAccessible as String] =
                kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
            return SecItemAdd(add as CFDictionary, nil) == errSecSuccess
        }
        return status == errSecSuccess
    }
}
