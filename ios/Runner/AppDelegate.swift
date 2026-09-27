import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // Blur the UI in the app-switcher snapshot so scanned documents aren't
    // legible from outside the app. See PrivacyOverlay.
    PrivacyOverlay.shared.activate()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    DocumentScannerPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "DocumentScannerPlugin")!)
    AiFieldEnhancerPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "AiFieldEnhancerPlugin")!)
    BackupPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "BackupPlugin")!)
    EntitlementPlugin.register(with: engineBridge.pluginRegistry.registrar(forPlugin: "EntitlementPlugin")!)
  }
}
