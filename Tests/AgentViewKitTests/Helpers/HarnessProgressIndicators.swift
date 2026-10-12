import AgentViewKitTestSupport
import AppKit
import SwiftUI

extension HostedViewHarness {
  /// The number of AppKit progress indicators in the hosting view.
  ///
  /// A SwiftUI `ProgressView` shows as an `NSProgressIndicator` in the
  /// hosting view, so a test counts the spinners of a view with this
  /// function.
  ///
  /// - Returns: The number of progress indicators below the hosting view.
  func progressIndicatorCount() -> Int {
    Self.progressIndicatorCount(in: hostingView)
  }

  /// The number of AppKit progress indicators in `view` and below it.
  ///
  /// - Parameter view: The view to search.
  /// - Returns: The number of progress indicators.
  private static func progressIndicatorCount(in view: NSView) -> Int {
    let own = view is NSProgressIndicator ? 1 : 0
    return view.subviews.reduce(own) { count, subview in count + progressIndicatorCount(in: subview) }
  }
}
