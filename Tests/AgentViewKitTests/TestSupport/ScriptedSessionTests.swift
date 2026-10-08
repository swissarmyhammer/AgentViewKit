import AgentViewKitTestSupport
import Foundation
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

  @Test func theSessionUpdateFrameHoldsTheSessionIdAndTheUpdate() throws {
    let update = JSONValue.object(["sessionUpdate": .string("state_update")])

    let frame = try JSONValue(json: ScriptedSession.sessionUpdateFrame(sessionId: .string("s1"), update: update))

    #expect(frame["method"]?.stringValue == "session/update")
    #expect(frame["params"]?["sessionId"]?.stringValue == "s1")
    #expect(frame["params"]?["update"] == update)
  }

  @Test func theSessionUpdateFrameHasTheScriptedSessionIdByDefault() throws {
    let update = JSONValue.object(["sessionUpdate": .string("state_update")])

    let frame = try JSONValue(json: ScriptedSession.sessionUpdateFrame(update: update))

    #expect(frame["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)
  }

  @Test func anAgentMessageChunkUpdateHasTheMembersOfATextChunkOnTheWire() throws {
    let update = try ScriptedSession.agentMessageChunkUpdate(messageID: "chunk-m", text: "Hello.")

    #expect(Self.memberNames(of: update) == ["sessionUpdate", "messageId", "content"])
    #expect(Self.memberNames(of: try #require(update["content"])) == ["type", "text"])
  }

  @Test func anAgentMessageChunkUpdateDecodesAsATextChunkOfItsMessage() throws {
    let json = try ScriptedSession.agentMessageChunkUpdate(messageID: "chunk-m", text: "Hello.").jsonString

    let update = try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))

    #expect(update == BackgroundRunScript.makeChunkUpdate(messageID: "chunk-m", text: "Hello."))
  }

  @Test func theConfigureClosureChangesTheAgentBeforeItStarts() async throws {
    let session = try await ScriptedSession.open { $0.results["session/new"] = #"{"sessionId":"custom"}"# }
    defer { session.close() }

    #expect(session.model.sessionId == SessionId(rawValue: "custom"))
  }

  /// The member names of a JSON object.
  ///
  /// - Parameter value: The JSON value.
  /// - Returns: The member names, or an empty set when the value is not an
  ///   object.
  static func memberNames(of value: JSONValue) -> Set<String> {
    guard case .object(let members) = value else { return [] }
    return Set(members.keys)
  }
}
