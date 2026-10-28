import AppKit
import SwiftUI

/// Lays out a SwiftUI view of the style library in an `NSHostingView` with
/// no window, so a test reads its size and its body runs.
///
/// The host puts no window on the screen and reads no accessibility tree, so
/// a style test takes no focus and shares no process state with the hosted
/// tests of AgentViewKit.
@MainActor enum StyleViewHost {
  /// The size that `view` fits in, with no proposal.
  ///
  /// - Parameter view: The view to measure.
  /// - Returns: The fitting size of the hosting view of `view`.
  static func fittingSize(of view: some View) -> CGSize {
    NSHostingView(rootView: view).fittingSize
  }

  /// The size that `view` fits in at `width`.
  ///
  /// - Parameters:
  ///   - view: The view to measure.
  ///   - width: The width of the proposal, in points.
  /// - Returns: The size that the view takes in the width.
  static func size(of view: some View, width: CGFloat) -> CGSize {
    NSHostingView(rootView: view.frame(width: width)).fittingSize
  }

  /// Lays out `view` once, so that its body and the bodies under it run.
  ///
  /// - Parameter view: The view to lay out.
  static func layOut(_ view: some View) {
    let hosting = NSHostingView(rootView: view)
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
  }
}

/// A list of values that a style records as a view runs it.
@MainActor final class StyleRecord<Value> {
  /// The recorded values, in the order of the calls.
  var values: [Value] = []
}
