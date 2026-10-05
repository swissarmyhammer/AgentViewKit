import DemoSupport
import Testing

/// The time limit of the ACP tests stays small (task ^pbgn012).
///
/// A large limit hides a stall of the main actor. A test that waits for a
/// stall then passes, and nobody sees the stall.
@Suite struct ScriptedWireAgentBoundedTests {
  /// The largest time limit, in seconds, that ``ScriptedWireAgent/bounded(_:)``
  /// can have.
  static let largestOperationLimitSeconds = 5

  @Test func theOperationLimitIsAtMostFiveSeconds() {
    #expect(ScriptedWireAgent.operationLimitSeconds <= Self.largestOperationLimitSeconds)
  }
}
