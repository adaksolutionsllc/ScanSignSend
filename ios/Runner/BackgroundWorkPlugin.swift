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
///   iOS 26 asks for the task only when the app stops being active, and ends
///   it when the app is back: on iPhones without a Dynamic Island the system
///   shows its progress banner at once, over the top of the app, and it does
///   not go away by itself (tester report, build 26).
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
    /// The identifier of the task asked for and not yet ended.
    private var asked: String?
    /// Moves the system's progress on within a page (see tick()).
    private var ticker: Timer?
    /// Progress units for each page: a page moves the bar by this many.
    private static let unitsPerPage: Int64 = 20
    /// A job is running: between "begin" and "end".
    private var working = false
    private var title = ""
    private var subtitle = ""
    /// The title once the system has ended the time ("… paused. Open the
    /// app to go on."): iOS itself adds "Task failed" under it.
    private var pausedTitle = ""
    private var done: Int64 = 0
    private var total: Int64 = 0

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
        // UIApplication notifications, as in PrivacyOverlay: FlutterSceneDelegate
        // keeps the scene methods to itself. willResignActive, not
        // didEnterBackground: the task must start while the app is in front.
        let center = NotificationCenter.default
        center.addObserver(
            self, selector: #selector(leaving),
            name: UIApplication.willResignActiveNotification, object: nil)
        center.addObserver(
            self, selector: #selector(back),
            name: UIApplication.didBecomeActiveNotification, object: nil)
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
        if call.method == "begin" || call.method == "progress" {
            title = args["title"] as? String ?? ""
            subtitle = args["subtitle"] as? String ?? ""
            done = Int64(args["done"] as? Int ?? 0)
            total = Int64(args["total"] as? Int ?? 0)
            pausedTitle = args["paused"] as? String ?? ""
        }
        switch call.method {
        case "keepScreenOn":
            UIApplication.shared.isIdleTimerDisabled = args["on"] as? Bool ?? false
            result(nil)
        case "begin":
            begin()
            result(nil)
        case "progress":
            if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
                show(task)
            }
            result(nil)
        case "end":
            end()
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func begin() {
        end()
        working = true
        if #available(iOS 26.0, *) {
            // Asked for when the user leaves the app (leaving()).
            if UIApplication.shared.applicationState != .active { leaving() }
            return
        }
        beginShortTask()
    }

    private func beginShortTask() {
        guard shortTask == .invalid else { return }
        shortTask = UIApplication.shared.beginBackgroundTask(withName: "import-job") { [weak self] in
            self?.expired()
        }
    }

    /// The app stops being active: ask for the continued-processing task,
    /// or a short background task when the system says no.
    @objc private func leaving() {
        guard #available(iOS 26.0, *), working, asked == nil else { return }
        if !submitContinued() { beginShortTask() }
    }

    /// The app is in front again: end the task, so the system's progress
    /// banner does not cover the app. The job goes on in the app.
    @objc private func back() {
        guard #available(iOS 26.0, *), working else { return }
        endTasks()
    }

    /// True when the system accepted the task.
    @available(iOS 26.0, *)
    private func submitContinued() -> Bool {
        guard let bundle = Bundle.main.bundleIdentifier else { return false }
        // Info.plist BGTaskSchedulerPermittedIdentifiers: "<bundle>.importJob.*"
        let id = "\(bundle).importJob.\(UUID().uuidString.prefix(8))"
        let registered = BGTaskScheduler.shared.register(forTaskWithIdentifier: id, using: .main) { [weak self] task in
            guard let self, let task = task as? BGContinuedProcessingTask else {
                task.setTaskCompleted(success: false)
                return
            }
            // The user came back, or the job ended, before the task started.
            guard self.asked == id, UIApplication.shared.applicationState != .active else {
                task.setTaskCompleted(success: true)
                return
            }
            self.show(task)
            task.expirationHandler = { [weak self, weak task] in
                guard let self else { return }
                if let task, !self.pausedTitle.isEmpty {
                    task.updateTitle(self.pausedTitle, subtitle: self.subtitle)
                }
                self.expired()
            }
            self.continued = task
            self.ticker = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
        guard registered else { return false }
        let request = BGContinuedProcessingTaskRequest(identifier: id, title: title, subtitle: subtitle)
        // Not queued: a job that can't start now still runs in the app.
        request.strategy = .fail
        do {
            try BGTaskScheduler.shared.submit(request)
            asked = id
            return true
        } catch {
            NSLog("BackgroundWorkPlugin: \(error)")
            return false
        }
    }

    /// The pages done so far, as the system's progress.
    @available(iOS 26.0, *)
    private func show(_ task: BGContinuedProcessingTask) {
        let pages = max(total, 1)
        task.progress.totalUnitCount = pages * Self.unitsPerPage
        task.progress.completedUnitCount = min(done, pages) * Self.unitsPerPage
        task.updateTitle(title, subtitle: subtitle)
    }

    /// One unit on while a page is in work, up to just short of the next
    /// page. iOS ends a task whose progress stands still for about 30 s and
    /// shows "Task failed"; Apple DTS asks for an update every 1–2 s (forum
    /// thread 805554). A large page in the background can take that long
    /// (tester report, build 26). This cannot help when a locked phone goes
    /// to sleep (an iOS bug, thread 796138): the job then pauses and goes on
    /// when the app is back.
    private func tick() {
        guard #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask else { return }
        let pages = max(total, 1)
        let next = (min(done, pages) + 1) * Self.unitsPerPage - 1
        if task.progress.completedUnitCount < next {
            task.progress.completedUnitCount += 1
        }
    }

    private func expired() {
        channel.invokeMethod("expired", arguments: nil)
        end()
    }

    private func end() {
        working = false
        endTasks()
    }

    private func endTasks() {
        ticker?.invalidate()
        ticker = nil
        if #available(iOS 26.0, *), let task = continued as? BGContinuedProcessingTask {
            task.setTaskCompleted(success: true)
        }
        continued = nil
        asked = nil
        if shortTask != .invalid {
            UIApplication.shared.endBackgroundTask(shortTask)
            shortTask = .invalid
        }
    }
}
