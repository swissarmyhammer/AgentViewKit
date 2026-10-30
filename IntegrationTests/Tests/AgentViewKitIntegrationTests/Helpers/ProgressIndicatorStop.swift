import AppKit
import EditorTestSupport

/// Stops each AppKit progress indicator under `root`, before a capture.
///
/// EditorKit's capture takes the window until two images in a row are equal.
/// EditorKit's `ReviewScreenRoot` shows each capture with Reduce Motion on, so
/// the endless animations of the kit that honour it stand still
/// (`ShimmerView`, `.liveSymbolEffect(isActive:)`). An indeterminate
/// `ProgressView` spins with no end and reads no Reduce Motion, and no part of
/// EditorKit's capture stops it, so each capture of it would wait for its last
/// try. A stopped indicator keeps its place and its look, and the window stops
/// changing.
///
/// - Parameter root: The hosting view of the mount.
func stopProgressIndicators(in root: NSView) {
  for indicator in views(ofType: NSProgressIndicator.self, in: root) {
    indicator.stopAnimation(nil)
  }
}
