@testable import AgentViewKitTestSupport
import Foundation
import Synchronization
import Testing

/// Tests for ``RunLoopBlockFence``.
///
/// The release tests call the actions synchronously, so they do not wait. The
/// fence test waits for a block that the fence adds to the main run loop. The
/// main run loop of the test process runs in the default mode, which is a
/// common mode, so that block is certain to run.
@Suite @MainActor struct RunLoopBlockFenceTests {
  /// Counts the runs of an action. The action is `@Sendable`, so the count
  /// uses a lock.
  nonisolated final class RunCount: Sendable {
    /// The count, behind a lock.
    private let storage = Mutex(0)

    /// The runs since the start.
    var value: Int { storage.withLock { $0 } }

    /// Counts one run.
    func increment() {
      storage.withLock { $0 += 1 }
    }
  }

  @Test func aBlockThatWasAddedBeforeTheFenceRanWhenTheFenceReturns() async {
    let flag = ChangeFlag()
    RunLoop.main.perform(inModes: [.common]) { flag.set() }

    await RunLoopBlockFence.afterPendingBlocks()

    #expect(flag.value)
  }

  @Test func aReleaseAfterTheArmRunsTheActionOneTime() {
    let release = RunLoopBlockFence.Release()
    let count = RunCount()
    release.arm { count.increment() }
    #expect(count.value == 0)

    release.release()
    release.release()

    #expect(count.value == 1)
  }

  @Test func anArmAfterTheReleaseRunsTheActionAtOnce() {
    let release = RunLoopBlockFence.Release()
    let count = RunCount()
    release.release()

    release.arm { count.increment() }
    release.release()

    #expect(count.value == 1)
  }
}
