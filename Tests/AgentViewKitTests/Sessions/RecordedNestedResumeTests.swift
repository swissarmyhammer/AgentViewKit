import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The acceptance test of the nested resume with the real agent: a resume of a
/// nested recording shows the tree.
///
/// The test is off until FoundationModelsACPAgent replays the child history of
/// a recorded session that has `agentSpawn` records (the Router records), and
/// the demo app has such a recording. Turn it on then, and it must pass with no
/// change to the checks: the tree under the resumed root has a child that has a
/// child, as the recording holds.
@Suite @MainActor struct RecordedNestedResumeTests {
  @Test(.disabled("Waits for the Agent package to replay child sessions from a recording with agentSpawn."))
  func aResumeOfANestedRecordingShowsTheTree() async throws {
    let scenario = try await RecordedSessionsScenario.start()
    defer { Task { await scenario.stop() } }

    var hasChildOfChild = false
    try await RecordedSessionsScenario.resumeEachSessionFromTheStart(of: scenario.agent) { _, session in
      if Self.hasChildOfChild(session) { hasChildOfChild = true }
    }

    #expect(hasChildOfChild)
  }

  /// Tells if a session of the tree has a child that has a child.
  private static func hasChildOfChild(_ session: SessionModel) -> Bool {
    session.children.contains { !$0.children.isEmpty || hasChildOfChild($0) }
  }
}
