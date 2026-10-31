import AppKit
import EditorTestSupport
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
    views(ofType: NSProgressIndicator.self, in: hostingView).count
  }
}
