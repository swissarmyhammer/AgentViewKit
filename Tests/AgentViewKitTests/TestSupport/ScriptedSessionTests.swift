import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The session model over the scripted wire agent of the view tests.
@Suite @MainActor struct ScriptedSessionTests {
  @Test func theSessionModelHasTheScriptedSessionID() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    #expect(session.model.sessionId == SessionId(rawValue: ScriptedSession.sessionID))
  }

  @Test func anUpdateFromTheAgentReachesTheTranscript() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model

    try await session.sendUpdate(
      #"{"sessionUpdate":"agent_message_chunk","messageId":"m1","content":{"type":"text","text":"Hi."}}"#)

    #expect(await waitUntil { model.transcript.count == 1 })
  }

  @Test func theConfigureClosureChangesTheAgentBeforeItStarts() async throws {
    let session = try await ScriptedSession.open { $0.results["session/new"] = #"{"sessionId":"custom"}"# }
    defer { session.close() }

    #expect(session.model.sessionId == SessionId(rawValue: "custom"))
  }
}
