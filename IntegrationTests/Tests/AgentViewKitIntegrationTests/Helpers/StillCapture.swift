import AppKit
import EditorTestSupport
import SwiftUI

/// A view of a capture with its endless animations held still (^f89p8k).
///
/// EditorKit's capture takes the window until two images in a row are equal.
/// A view that animates with no end, such as the `TimelineView` of
/// `ShimmerView` or a live symbol effect, changes the window between each two
/// images, so each capture of it waits for its last try. The kit stops these
/// animations under Reduce Motion (`ShimmerView`, `.liveSymbolEffect(isActive:)`),
/// so the capture shows the view with Reduce Motion on. The production views
/// do not change: only the environment of the fixture does.
struct StillCaptureContent<Content: View>: View {
  /// The view of the capture.
  let content: Content

  var body: some View {
    content.environment(\._accessibilityReduceMotion, true)
  }
}

/// Stops each AppKit progress indicator under `root`, before a capture.
///
/// An indeterminate `ProgressView` spins with no end, and it does not read
/// Reduce Motion, so ``StillCaptureContent`` does not hold it still. A stopped
/// indicator keeps its place and its look, and the window stops changing.
///
/// - Parameter root: The hosting view of the mount.
func stopProgressIndicators(in root: NSView) {
  for indicator in views(ofType: NSProgressIndicator.self, in: root) {
    indicator.stopAnimation(nil)
  }
}
