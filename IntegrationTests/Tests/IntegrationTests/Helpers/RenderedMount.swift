import EditorTestSupport
import Testing

/// A view mounted in a window, which a test renders after a change of its
/// model. A helper that sends a change and waits for it takes this protocol.
protocol RenderedMount {
  /// Makes SwiftUI update the view now, with no run loop turn and no clock.
  func render()
}

extension RenderedMount {
  /// Waits until `condition` holds, then until the main run loop has run the
  /// update that SwiftUI queued for the change, then renders.
  ///
  /// The wait has a bound, so a change that never comes fails the test and
  /// the run goes on. The bound is a guard against a defect, not a delay: a
  /// wait whose change comes ends at the change. Use this method, and not
  /// the `render(when:)` of EditorKit's `HostedViewHarness`, which waits with
  /// no bound.
  ///
  /// - Parameters:
  ///   - bound: The longest time that the wait suspends. The default is
  ///     `BoundedWait.defaultBound`.
  ///   - sourceLocation: The place of the wait in the test, for the issue
  ///     when the bound passes.
  ///   - condition: The condition on observable model values that are
  ///     certain to change.
  func renderAfter(
    within bound: Duration = BoundedWait.defaultBound,
    sourceLocation: SourceLocation = #_sourceLocation,
    _ condition: @MainActor () -> Bool
  ) async {
    await ObservationWait.until(within: bound, sourceLocation: sourceLocation, condition)
    await RunLoopBlockFence.afterPendingBlocks()
    render()
  }
}

extension HostedViewHarness: RenderedMount {}
