import Foundation

/// Runs the blocks that the main run loop holds, in one pass of the run
/// loop that does not wait.
///
/// SwiftUI adds the work of a layout pass to the main run loop as blocks,
/// such as a change of the geometry of a row. A test that must see that
/// work runs this pass after the layout, and lays out again.
///
/// Do not use `RunLoopBlockFence.afterPendingBlocks()` for this work. The
/// fence block runs only at the end of the turn of the run loop, after each
/// main-actor job that was ready at the start of the turn. Swift Testing
/// runs many tests on the main actor at the same time, so that turn holds
/// the jobs of the other tests too. The turns of a parallel run of the
/// thread tests took up to 18 seconds (2026-11-26), so under a heavy load
/// the fence passed its bound of 30 seconds before its block ran.
///
/// The pass runs in the call, and it does not wait. It runs no main-actor
/// job, because a run loop that runs inside a job of the main queue does
/// not run the main queue. Thus no job of another test runs before the
/// blocks.
@MainActor enum PendingRunLoopBlocks {
  /// Runs each block that the main run loop holds for its default mode,
  /// and each source that is ready. The pass does not wait.
  static func run() {
    RunLoop.main.run(mode: .default, before: .distantPast)
  }
}
