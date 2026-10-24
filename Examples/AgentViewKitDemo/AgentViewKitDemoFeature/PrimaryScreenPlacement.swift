import AppKit
import SwiftUI

/// Moves the window of the view to the primary screen, the one whose frame
/// origin is (0, 0), when the app runs with `--primary-screen`
/// (``DemoLaunchOptions/primaryScreenArgument``).
///
/// This is a test-environment switch. The demo window opens on the screen
/// that the user is working on, and XCTest's hit test fails for a window on
/// a screen that lies above or left of the primary screen, where the global
/// coordinates are negative. The UI tests pass the argument, so that they
/// run the same on every arrangement of displays. Without the argument, the
/// view does nothing.
private struct PrimaryScreenPlacement: NSViewRepresentable {
  /// Whether to move the window.
  let isEnabled: Bool

  func makeNSView(context: Context) -> PlacementView {
    PlacementView(isEnabled: isEnabled)
  }

  func updateNSView(_ nsView: PlacementView, context: Context) {}

  /// The view that finds its window, and moves the window to the primary
  /// screen when the window stands on another screen.
  ///
  /// SwiftUI places the window after it adds the content, so the view
  /// checks the window when it joins the window, on the next turn of the
  /// run loop, and each time the window becomes the key window or changes
  /// its screen. A window that stands on the primary screen stays where it
  /// is, so the check ends after the move.
  final class PlacementView: NSView {
    /// Whether to move the window.
    private let isEnabled: Bool

    init(isEnabled: Bool) {
      self.isEnabled = isEnabled
      super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      fatalError("PlacementView is made in code.")
    }

    override func viewWillMove(toWindow newWindow: NSWindow?) {
      super.viewWillMove(toWindow: newWindow)
      NotificationCenter.default.removeObserver(self)
    }

    override func viewDidMoveToWindow() {
      super.viewDidMoveToWindow()
      guard isEnabled, let window else { return }
      for name in [NSWindow.didBecomeKeyNotification, NSWindow.didChangeScreenNotification] {
        NotificationCenter.default.addObserver(
          self, selector: #selector(moveWindowToThePrimaryScreen), name: name, object: window)
      }
      moveWindowToThePrimaryScreen()
      DispatchQueue.main.async { [weak self] in self?.moveWindowToThePrimaryScreen() }
    }

    /// Moves the window to the top-left corner of the visible frame of the
    /// primary screen, unless it stands on the primary screen.
    @objc private func moveWindowToThePrimaryScreen() {
      guard let window, let primaryScreen = NSScreen.screens.first, window.screen != primaryScreen else { return }
      window.setFrame(
        DemoWindowLayout.primaryScreenFrame(visibleFrame: primaryScreen.visibleFrame), display: true)
    }
  }
}

extension View {
  /// Moves the window of this view to the primary screen, when `isEnabled`.
  ///
  /// - Parameter isEnabled: Whether the app runs with `--primary-screen`.
  /// - Returns: The view with the placement.
  func placedOnThePrimaryScreen(_ isEnabled: Bool) -> some View {
    background(PrimaryScreenPlacement(isEnabled: isEnabled))
  }
}
