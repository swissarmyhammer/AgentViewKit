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
/// change to the checks: the tree under the resumed root has a child, and a
/// child of that child, as the recording holds.
@Suite @MainActor struct RecordedNestedResumeTests {
  @Test(.disabled("Waits for the Agent package to replay child sessions from a recording with agentSpawn."))
  func aResumeOfANestedRecordingShowsTheTree() async throws {
    let scenario = try await RecordedSessionsScenario.start()
    defer { Task { await scenario.stop() } }

    var depth = 0
    try await RecordedSessionsScenario.resumeEachSessionFromTheStart(of: scenario.agent) { _, session in
      depth = max(depth, Self.levels(below: session))
    }

    #expect(depth >= 2)
  }

  /// The number of levels below a session: zero for a session with no child.
  private static func levels(below session: SessionModel) -> Int {
    1 + (session.children.map(levels(below:)).max() ?? -1)
  }
}
