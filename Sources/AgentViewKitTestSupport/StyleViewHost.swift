import AppKit
import SwiftUI

/// Lays out a SwiftUI view in an `NSHostingView` with no window, so that a
/// test reads its size and its body runs.
///
/// The host puts no window on the screen and reads no accessibility tree, so
/// a test that uses it takes no focus. The unit tests and the
/// IntegrationTests package use this one helper, and keep no copy of the
/// sizing code.
@MainActor public enum StyleViewHost {
  /// The size that `view` fits in, with no proposal.
  ///
  /// - Parameter view: The view to measure.
  /// - Returns: The fitting size of the hosting view of `view`.
  public static func fittingSize(of view: some View) -> CGSize {
    NSHostingView(rootView: view).fittingSize
  }

  /// The size that `view` fits in at `width`.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - width: The width of the proposal, in points.
  /// - Returns: The size that the view takes in the width.
  public static func size(of view: some View, width: CGFloat) -> CGSize {
    fittingSize(of: view.frame(width: width))
  }

  /// Lays out `view` once, so that its body and the bodies under it run.
  ///
  /// - Parameter view: The view to lay out.
  public static func layOut(_ view: some View) {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
  }
}
