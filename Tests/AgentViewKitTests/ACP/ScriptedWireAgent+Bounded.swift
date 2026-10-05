import DemoSupport
import Testing

/// The time limit of the ACP tests that talk to a ``ScriptedWireAgent``.
extension ScriptedWireAgent {
  /// The number of seconds that ``bounded(_:)`` waits.
  ///
  /// The limit stops a hang. It does not measure speed. In a run of the whole
  /// suite, the hosted tests keep the main actor busy for many seconds, and
  /// an ACP test waits for the main actor during that time. A short limit
  /// then fails a test that does not hang.
  static let operationLimitSeconds = 60

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
