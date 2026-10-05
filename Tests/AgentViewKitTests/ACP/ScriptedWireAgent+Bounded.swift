import DemoSupport
import Testing

/// The time limit of the ACP tests that talk to a ``ScriptedWireAgent``.
extension ScriptedWireAgent {
  /// The number of seconds that ``bounded(_:)`` waits.
  ///
  /// The limit stops a hang. It does not measure speed. Each test of this
  /// target runs on the main actor, and a hosted test holds the main thread
  /// while it runs the run loop. Thus an ACP operation waits for the main
  /// actor at each step. In a full `swift test` run, the slowest ACP test
  /// takes less than 3 seconds, so 5 seconds is sufficient.
  ///
  /// Do not make the limit larger to stop a failure. A large limit hides a
  /// stall of the main actor. Find the cause of the stall.
  /// ``ScriptedWireAgentBoundedTests`` keeps the limit at 5 seconds or less.
  static let operationLimitSeconds = 5

  /// The time that ``bounded(_:)`` waits.
  static let operationLimit = Duration.seconds(operationLimitSeconds)

  /// Runs `operation` with a time limit.
  ///
  /// When the time runs out, the function records an issue and stops the
  /// agent. The stop closes the transport, so each request that waits for
  /// the agent fails, and `operation` ends.
  ///
  /// - Parameter operation: The operation to run.
  /// - Returns: The result of `operation`.
  func bounded<Result>(_ operation: () async throws -> Result) async rethrows -> Result {
    let watchdog = Task { [self] in
      try? await Task.sleep(for: Self.operationLimit)
      guard !Task.isCancelled else { return }
      Issue.record("The operation did not end in time.")
      stop()
    }
    defer { watchdog.cancel() }
    return try await operation()
  }
}
