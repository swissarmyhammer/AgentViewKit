import Dispatch

/// Lets the main queue run one turn, with no clock.
///
/// ``run()`` puts one block on the main queue and suspends until that block
/// runs. The work that is already on the main queue runs before the block.
/// The hop is an event that is certain to come: the main queue always runs
/// the block. The hop has no clock, does not poll, does not retry and has no
/// time limit.
///
/// Use the hop when a view shows a change only after a turn of the main
/// queue, such as the inspector item of an AppKit split view. Hop one time,
/// call `HostedViewHarness.render()`, and then check the result with an
/// expectation. When the view needs more than one turn, the expectation
/// fails, and the test does not hang. Do not hop again, and do not hop in a
/// loop.
@MainActor
public enum MainQueueHop {
  /// Suspends until the main queue runs one block that this call puts on it.
  public static func run() async {
    await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
      DispatchQueue.main.async {
        continuation.resume()
      }
    }
  }
}
