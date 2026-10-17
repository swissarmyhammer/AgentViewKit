import CoreFoundation
import Foundation
import Synchronization

/// Waits until the main run loop has run each common-mode block that was
/// added to it before the wait.
///
/// ``afterPendingBlocks()`` adds one block to the main run loop with
/// `RunLoop.main.perform(inModes: [.common])`, wakes the run loop, and
/// suspends until that block runs. The wait has no clock, no poll and no time
/// limit. It ends at once when the task of the caller is cancelled.
///
/// Proof (a), the order. Source: `CFRunLoop.c` of swift-corelibs-foundation
/// (`Sources/CoreFoundation/CFRunLoop.c`). `CFRunLoopPerformBlock` adds each
/// block at the end of the block list of the run loop, under the lock of the
/// run loop. `__CFRunLoopDoBlocks` takes the list and runs it from the start.
/// It runs each block whose mode is the current mode, or whose mode is
/// `kCFRunLoopCommonModes` when the current mode is a common mode. The block
/// of the fence and a block that was added before it with the common modes
/// match the same modes. Thus the fence block runs after that block.
/// `-[NSRunLoop performInModes:block:]` calls `CFRunLoopPerformBlock`: the
/// sampled stacks show this frame.
///
/// Proof (b), the block runs. Sources: the sampled stacks of the test process
/// (lldb, 2026-10-17), and `CFExecutor.swift` of the swift repository
/// (`stdlib/public/Concurrency`). In the samples, the main thread runs `main`,
/// `swift_task_asyncMainDrainQueue`, `CFMainExecutor.run()` and
/// `CFRunLoopRun`, and the blocks of the main run loop run in
/// `__CFRunLoopDoBlocks` under `CFRunLoopRun`. `CFMainExecutor.run()` calls
/// `CFRunLoopRun`. In `CFRunLoop.c`, `CFRunLoopRun` runs the current run loop
/// in `kCFRunLoopDefaultMode`, and a new run loop adds
/// `kCFRunLoopDefaultMode` to its common modes. Thus the main run loop turns
/// in a common mode while the test awaits. `CFRunLoopPerformBlock` does not
/// wake the run loop, so the fence calls `CFRunLoopWakeUp` after it adds the
/// block.
///
/// The assumption of the proofs: `CFRunLoop.c` is the source of
/// swift-corelibs-foundation, but the test process runs the CoreFoundation of
/// macOS. The samples show that the blocks of the main run loop run in
/// `__CFRunLoopDoBlocks` of the CoreFoundation binary of macOS. The samples do
/// not show how that binary adds a block to the list or in which order it runs
/// the list. Thus the proofs assume that the CoreFoundation of macOS adds,
/// selects and runs the blocks as `CFRunLoop.c` does.
///
/// The limit of the claim: the order is proven only for the sampled chain of
/// the inspector of a split view. The samples are of a chip press and of a host
/// selection of a thread view. That chain is `HostedViewHarness.render()`,
/// `NSHostingView.layout()`, `SplitViewCoordinator.updateInspector`,
/// `onNextMainRunLoop`, `-[NSRunLoop performInModes:block:]` with
/// `kCFRunLoopCommonModes`, and `CFRunLoopPerformBlock`, all in one
/// synchronous call of the render pass. Only a sample of a chip press reads
/// the modes argument. If a later SwiftUI moves that work to the main dispatch
/// queue or to a Core Animation commit, the order to the fence is not fixed,
/// and a test that uses the fence can then fail only sometimes. Investigate
/// such a failure with a new sample of the stack of the enqueue. Do not run
/// the test again to find the cause.
@MainActor
public enum RunLoopBlockFence {
  /// Suspends until the main run loop runs a block that this call adds.
  ///
  /// Call it after the render pass that adds the blocks to wait for. Each
  /// common-mode block that the main run loop holds at the call has run when
  /// the call returns. The call returns at once when the task is cancelled.
  public static func afterPendingBlocks() async {
    let release = Release()
    await withTaskCancellationHandler {
      await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
        release.arm { continuation.resume() }
        RunLoop.main.perform(inModes: [.common]) { release.release() }
        CFRunLoopWakeUp(RunLoop.main.getCFRunLoop())
      }
    } onCancel: {
      release.release()
    }
  }

  /// An action that runs one time: at the first ``release()`` after
  /// ``arm(_:)``, or in ``arm(_:)`` when the release came first.
  ///
  /// The fence block and the cancellation handler each call ``release()``,
  /// and they can run on different threads, so the state uses a lock.
  nonisolated final class Release: Sendable {
    /// The state of a release.
    enum State {
      /// No action and no release yet.
      case waiting
      /// The action is set, and no release came yet.
      case armed(@Sendable () -> Void)
      /// The release came. The action ran, or it runs at the arm.
      case released
    }

    /// The state, behind a lock.
    private let state = Mutex(State.waiting)

    /// Makes a release with no action.
    init() {}

    /// Sets the action, or runs it at once when the release came first.
    ///
    /// - Parameter action: The action to run one time.
    func arm(_ action: @escaping @Sendable () -> Void) {
      let isReleased = state.withLock { state in
        if case .released = state { return true }
        state = .armed(action)
        return false
      }
      if isReleased { action() }
    }

    /// Runs the action, when it is set and did not run. A later call does
    /// nothing.
    func release() {
      let action = state.withLock { state -> (@Sendable () -> Void)? in
        defer { state = .released }
        guard case .armed(let action) = state else { return nil }
        return action
      }
      action?()
    }
  }
}
