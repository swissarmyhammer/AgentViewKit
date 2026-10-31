import EditorTestSupport

/// A view mounted in a window, which a test renders after a change of its
/// model. A helper that sends a change and waits for it takes this protocol.
protocol RenderedMount {
  /// Makes SwiftUI update the view now, with no run loop turn and no clock.
  func render()

  /// Waits until `condition` holds, then makes SwiftUI update the view.
  ///
  /// - Parameter condition: The condition on observable model values that are
  ///   certain to change.
  func render(when condition: @MainActor () -> Bool) async
}

extension RenderedMount {
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
}

extension HostedViewHarness: RenderedMount {}
