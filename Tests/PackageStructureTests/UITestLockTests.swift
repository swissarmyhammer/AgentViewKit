import Testing

/// Holds the shared swissarmyhammer UI test lock of `Scripts/ui-test-lock.sh`
/// to its contract.
///
/// `Scripts/test-examples.sh` takes the lock around the UI tests of each
/// example, so that its demo app never comes up during the UI tests of another
/// repository. `Scripts/test-ui-test-lock.sh` checks the lock code in a
/// temporary directory, never at the real lock path: a lock that a live
/// process holds blocks a waiter, a stale lock is taken over, SIGTERM and
/// SIGINT release the lock, a release removes only the lock of its own
/// process, and no draft file stays beside the lock.
@Suite struct UITestLockTests {
  /// The check script, relative to the package root.
  static let scriptPath = "Scripts/test-ui-test-lock.sh"

  /// The line that the check writes when each of its checks passes.
  static let passLine = "PASS ui-test-lock"

  @Test func theLockBlocksAWaiterTakesOverAStaleLockAndReleasesOnlyItsOwnLock() throws {
    let run = try ScriptRun.run(Self.scriptPath)

    #expect(run.status == 0, "\(run.output)")
    #expect(run.output.contains(Self.passLine), "\(run.output)")
  }
}
