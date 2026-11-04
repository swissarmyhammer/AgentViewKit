import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The acceptance test of the nested resume with the real agent: a resume of a
/// nested recording shows the tree.
///
/// The recording is `interrupted-nested-child`: a root, a child and a grandchild
/// that the agent recorded with its stub model, interrupted at a quit. The
/// stage makes the recorded working directory and the agent definitions that
/// the agent needs to restore the children. The tree under the resumed root has
/// a child that has a child, as the recording holds.
@Suite @MainActor struct RecordedNestedResumeTests {
  @Test
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
