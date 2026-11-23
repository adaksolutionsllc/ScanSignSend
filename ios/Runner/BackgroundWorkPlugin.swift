import BackgroundTasks
import Flutter
import Foundation
import UIKit

/// Platform channel: "com.scansignsend/background" (plan 1.3.2, J4 and J5)
///
/// - "keepScreenOn" {on}: the phone does not lock by itself while a long
///   import job runs with the app open.
/// - "begin" {title, subtitle, done, total}: keeps the app running when the
///   user leaves it. iOS 26 and later: a continued-processing task, which
///   the system shows with its own progress and the user can stop. Earlier
///   iOS, or when the system says no: a short background task (about 30 s).
/// - "progress" {title, subtitle, done, total}, "end".
/// - Calls "expired" in Dart when the system ends the time; the job pauses
///   at the next page and goes on when the app is back.
///
/// The work itself runs in Dart; this only keeps the app awake and reports
/// progress. See BackgroundWorkService (Dart).
class BackgroundWorkPlugin: NSObject, FlutterPlugin {

    static let channelName = "com.scansignsend/background"

    private let channel: FlutterMethodChannel
    private var shortTask: UIBackgroundTaskIdentifier = .invalid
    /// A BGContinuedProcessingTask (iOS 26+), kept untyped for older iOS.
    private var continued: AnyObject?

    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(
            name: channelName,
            binaryMessenger: registrar.messenger()
        )
        registrar.addMethodCallDelegate(BackgroundWorkPlugin(channel: channel), channel: channel)
    }

    func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments as? [String: Any] ?? [:]
        let title = args["title"] as? String ?? ""
        let subtitle = args["subtitle"] as? String ?? ""
        let done = Int64(args["done"] as? Int ?? 0)
        let total = Int64(args["total"] as? Int ?? 0)
        switch call.method {
        case "keepScreenOn":
            UIApplication.shared.isIdleTimerDisabled = args["on"] as? Bool ?? false
            result(nil)
        case "begin":
            begin(title: title, subtitle: subtitle, done: done, total: total)
            result(nil)
        case "progress":
            if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
                task.progress.totalUnitCount = max(total, 1)
                task.progress.completedUnitCount = min(done, max(total, 1))
                task.updateTitle(title, subtitle: subtitle)
            }
            result(nil)
        case "end":
            end()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func begin(title: String, subtitle: String, done: Int64, total: Int64) {
        end()
        if #available(iOS 26.0, *), submitContinued(title: title, subtitle: subtitle, done: done, total: total) {
            return
        }
        shortTask = UIApplication.shared.beginBackgroundTask(withName: "import-job") { [weak self] in
            self?.expired()
        }
    }

    /// True when the system accepted the task.
    @available(iOS 26.0, *)
    private func submitContinued(title: String, subtitle: String, done: Int64, total: Int64) -> Bool {
        guard let bundle = Bundle.main.bundleIdentifier else { return false }
        // Info.plist BGTaskSchedulerPermittedIdentifiers: "<bundle>.importJob.*"
        let id = "\(bundle).importJob.\(UUID().uuidString.prefix(8))"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            task.progress.totalUnitCount = max(total, 1)
            task.progress.completedUnitCount = done
            task.expirationHandler = { [weak self] in self?.expired() }
            self.continued = task
        }
        guard registered else { return false }
        let request = BGContinuedProcessingTaskRequest(identifier: id, title: title, subtitle: subtitle)
        // Not queued: a job that can't start now still runs in the app.
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
            return true
        } catch {
            NSLog("BackgroundWorkPlugin: \(error)")
            return false
        }
    }

    private func expired() {
        channel.invokeMethod("expired", arguments: nil)
        end()
    }

    private func end() {
        if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
            task.setTaskCompleted(success: true)
        }
        continued = nil
        if shortTask != .invalid {
            UIApplication.shared.endBackgroundTask(shortTask)
            shortTask = .invalid
        }
    }
}
