import UIKit

/// Covers the UI with a blurred overlay while the app is in the background.
///
/// iOS snapshots the window for the app switcher and keeps that snapshot on
/// disk. Without this, whatever document, signature or filled form was on
/// screen stays legible in the switcher to anyone holding the unlocked phone.
///
/// Implemented with `UIApplication` notifications rather than by overriding
/// `sceneWillResignActive(_:)`: `FlutterSceneDelegate` implements the scene
/// lifecycle methods itself to forward them to plugins, and those overrides are
/// not exposed in its public header, so subclassing them would shadow the
/// forwarding instead of extending it.
final class PrivacyOverlay {

  static let shared = PrivacyOverlay()

  private var overlay: UIView?

  private init() {}

  func activate() {
    let center = NotificationCenter.default

    // Background/foreground, deliberately NOT willResignActive/didBecomeActive.
    //
    // `willResignActive` fires for any system sheet that takes over the screen
    // — Face ID, Control Centre, a notification banner — none of which put the
    // app in the switcher. This app raises one of those during launch: the
    // biometric app lock prompts for Face ID as soon as it starts. Blurring
    // there covered the UI at launch, and if that transition did not land back
    // on `didBecomeActive` the overlay was stranded over the running app.
    //
    // iOS takes the app-switcher snapshot after the app enters the background,
    // so moving to these two notifications keeps the protection while removing
    // every false trigger.
    center.addObserver(
      self,
      selector: #selector(hideContents),
      name: UIApplication.didEnterBackgroundNotification,
      object: nil)
    center.addObserver(
      self,
      selector: #selector(revealContents),
      name: UIApplication.willEnterForegroundNotification,
      object: nil)

    // Safety net. Whatever path got us here, the overlay must never survive
    // into an app the user is actually looking at.
    center.addObserver(
      self,
      selector: #selector(revealContents),
      name: UIApplication.didBecomeActiveNotification,
      object: nil)
  }

  private var hostWindow: UIWindow? {
    let windows = UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
    return windows.first { $0.isKeyWindow } ?? windows.first
  }

  @objc private func hideContents() {
    // Never cover a foreground app, no matter which notification got us here.
    guard UIApplication.shared.applicationState != .active else { return }
    guard overlay == nil, let window = hostWindow else { return }

    let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThickMaterial))
    blur.frame = window.bounds
    blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // A lock glyph keeps the switcher card recognisable while the content
    // underneath stays unreadable.
    let glyph = UIImageView(
      image: UIImage(systemName: "lock.doc.fill")?
        .withConfiguration(UIImage.SymbolConfiguration(pointSize: 56, weight: .light)))
    glyph.tintColor = UIColor.secondaryLabel
    glyph.translatesAutoresizingMaskIntoConstraints = false
    blur.contentView.addSubview(glyph)
    NSLayoutConstraint.activate([
      glyph.centerXAnchor.constraint(equalTo: blur.contentView.centerXAnchor),
      glyph.centerYAnchor.constraint(equalTo: blur.contentView.centerYAnchor),
    ])

    window.addSubview(blur)
    overlay = blur
  }

  @objc private func revealContents() {
    overlay?.removeFromSuperview()
    overlay = nil
  }
}
