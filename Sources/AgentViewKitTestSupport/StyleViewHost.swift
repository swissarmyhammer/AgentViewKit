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

  /// The size that `view` takes when its parent proposes `width`, and no
  /// limit of height.
  ///
  /// The view chooses its size in the proposal: a `ViewThatFits` shows the
  /// first child that fits the width.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - width: The proposed width, in points.
  /// - Returns: The size that the view takes in the proposal.
  public static func size(of view: some View, proposedWidth width: CGFloat) -> CGSize {
    NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
  }

  /// Lays out `view` once, so that its body and the bodies under it run.
  ///
  /// - Parameter view: The view to lay out.
  public static func layOut(_ view: some View) {
    layOut(NSHostingView(rootView: view))
  }

  /// Gives `hosting` its fitting size, and lays it out once, so that the
  /// bodies of its root view run.
  ///
  /// A test that keeps one hosting view, and changes its root view between
  /// two layout passes, uses this function. SwiftUI then makes, updates and
  /// dismantles the views in the same host.
  ///
  /// - Parameter hosting: The hosting view to lay out.
  public static func layOut(_ hosting: NSHostingView<some View>) {
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
  }
}
