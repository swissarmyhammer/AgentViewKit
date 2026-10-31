import AppKit
import EditorTestSupport

extension ReviewMount {
  /// Makes SwiftUI update the view now: a layout pass of the hosting view,
  /// then a display of the window.
  func render() {
    hostingView.layoutSubtreeIfNeeded()
    window.displayIfNeeded()
  }

  /// Waits until `condition` holds, then until the main run loop has run the
  /// update that SwiftUI queued for the change, then renders.
  ///
  /// - Parameter condition: The condition on observable model values that are
  ///   certain to change.
  func render(when condition: @MainActor () -> Bool) async {
    await ObservationWait.until(condition)
    await RunLoopBlockFence.afterPendingBlocks()
    render()
  }

  /// Hides each AppKit view of `types`, such as the `QLPreviewView` of the
  /// attachment inspector: QuickLook draws its preview out of process, at a
  /// time that no event of the view tells.
  ///
  /// - Parameter types: The classes of the views to hide.
  func hideViews(of types: [NSView.Type]) {
    for view in hostingView.descendants where types.contains(where: view.isKind(of:)) {
      view.isHidden = true
    }
  }
}
