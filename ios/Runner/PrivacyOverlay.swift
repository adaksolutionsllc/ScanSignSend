import UIKit

/// Covers the UI with a blurred overlay whenever the app leaves the foreground.
///
/// iOS snapshots the window for the app switcher the moment the app resigns
/// active, and keeps that snapshot on disk. Without this, whatever document,
/// signature or filled form was on screen stays legible in the switcher to
/// anyone holding the unlocked phone. The overlay costs the user nothing — it
/// never blocks a screenshot they take deliberately — so unlike the Android
/// FLAG_SECURE path it is always on rather than tied to the app lock setting.
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
    center.addObserver(
      self,
      selector: #selector(hideContents),
      name: UIApplication.willResignActiveNotification,
      object: nil)
    center.addObserver(
      self,
      selector: #selector(revealContents),
      name: UIApplication.didBecomeActiveNotification,
      object: nil)
  }

  private var keyWindow: UIWindow? {
    UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
      ?? UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .flatMap { $0.windows }
        .first
  }

  @objc private func hideContents() {
    guard overlay == nil, let window = keyWindow else { return }

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
