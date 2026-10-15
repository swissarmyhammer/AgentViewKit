import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import Foundation
import FoundationModelsACP
import Testing

/// The session of each prompt.
private let sessionID = "s1"

/// The text of each prompt.
private let promptText = "hello"

/// The JSON-RPC id of the first prompt request.
private let firstPromptID = 1.0

/// The JSON-RPC id of the second prompt request.
private let secondPromptID = 2.0

/// The JSON-RPC id of the request that marks the end of the frames of a
/// prompt. The agent answers the frames in arrival order, so each frame of
/// the prompt comes before the response to this request.
private let markerRequestID = 3.0

/// The method of the marker request. The scripted agent answers it with `{}`.
private let markerMethod = "session/marker"

extension RawWireClient {
  /// Writes a `session/prompt` request with one text block.
  ///
  /// - Parameter id: The JSON-RPC id.
  /// - Throws: The error of the transport.
  fileprivate func prompt(id: Double) async throws {
    let params = JSONValue.object([
      "sessionId": .string(sessionID),
      "prompt": .array([promptBlock]),
    ])
    try await request(method: "session/prompt", id: id, params: params)
  }
}

/// The label of the whole `user_message` echo of a prompt.
private let userMessageLabel = "user_message"

/// The label of a `running` state update.
private let runningLabel = "state_update/running"

/// The update of a `session/update` frame that tells that the agent runs.
private let runningUpdate = JSONValue.object([
  "sessionUpdate": .string("state_update"), "state": .string("running"),
])

/// The text block of each prompt.
private let promptBlock = JSONValue.object(["type": .string("text"), "text": .string(promptText)])

/// The labels of the `session/update` frames of ``InMemoryDemoAgent`` after
/// the prompt result, in the ACPAgent order: the echo, then `running`, then
/// the turn, then the idle state.
private let inMemoryTurnLabels = [
  userMessageLabel, runningLabel, "agent_message_chunk", "agent_message_chunk", "agent_message", "plan_update",
  "usage_update", "state_update/idle/end_turn",
]

/// Tells if `frame` is the response to the request with `id`.
private func isResponse(frame: JSONValue, to id: Double) -> Bool {
  frame["method"] == nil && frame["id"] == .number(id)
}

/// The update of a `session/update` frame that echoes a user message, or
/// `nil`.
private func userMessageEcho(in frame: JSONValue) -> JSONValue? {
  guard frame["method"]?.stringValue == "session/update",
    let update = frame["params"]?["update"],
    let kind = update["sessionUpdate"]?.stringValue,
    kind == "user_message_chunk" || kind == "user_message"
  else { return nil }
  return update
}

/// The label of a `session/update` frame: its `sessionUpdate` kind, then its
/// `state` and its `stopReason` when the update has them, joined with `/`.
/// For example `state_update/idle/end_turn`.
///
/// - Parameter frame: A frame of the agent.
/// - Returns: The label, or `nil` when the frame is not a `session/update`.
private func updateLabel(of frame: JSONValue) -> String? {
  guard frame["method"]?.stringValue == "session/update", let update = frame["params"]?["update"] else { return nil }
  let parts = [update["sessionUpdate"], update["state"], update["stopReason"]].compactMap { $0?.stringValue }
  return parts.joined(separator: "/")
}

/// The frames of one prompt, read from an agent.
private struct PromptFrames {
  /// The frames in arrival order.
  let frames: [JSONValue]

  /// The position of the response to the prompt.
  let responseIndex: Int

  /// The position of each echoed user message.
  let echoIndexes: [Int]

  /// Reads the frames.
  ///
  /// - Parameters:
  ///   - frames: The frames in arrival order.
  ///   - promptID: The JSON-RPC id of the prompt.
  init(frames: [JSONValue], promptID: Double) throws {
    self.frames = frames
    responseIndex = try #require(frames.firstIndex { isResponse(frame: $0, to: promptID) })
    echoIndexes = frames.indices.filter { userMessageEcho(in: frames[$0]) != nil }
  }

  /// The `messageId` of the prompt result.
  var resultMessageID: String? {
    frames[responseIndex]["result"]?["messageId"]?.stringValue
  }

  /// The one echoed user message.
  var echo: JSONValue? {
    echoIndexes.count == 1 ? userMessageEcho(in: frames[echoIndexes[0]]) : nil
  }

  /// The label of each `session/update` frame after the response, in arrival
  /// order (``updateLabel(of:)``).
  var updateLabelsAfterResponse: [String] {
    frames[(responseIndex + 1)...].compactMap(updateLabel(of:))
  }
}

/// Starts a plain scripted agent and gives the client end.
///
/// - Parameter configure: Changes the agent before it starts.
/// - Returns: The agent and the client end.
private func startScriptedAgent(
  _ configure: (ScriptedWireAgent) -> Void = { _ in }
) -> (ScriptedWireAgent, RawWireClient) {
  let (clientEnd, agentEnd) = InMemoryTransport.pair()
  let agent = ScriptedWireAgent(transport: agentEnd)
  configure(agent)
  agent.start()
  return (agent, RawWireClient(transport: clientEnd))
}

/// Sends one prompt to a scripted agent, then the marker request, and reads
/// each frame of the prompt.
///
/// - Parameter client: The client end of the scripted agent.
/// - Returns: The frames of the prompt.
private func promptFrames(from client: RawWireClient) async throws -> PromptFrames {
  try await client.prompt(id: firstPromptID)
  try await client.request(method: markerMethod, id: markerRequestID, params: .object([:]))
  let frames = try await client.frames { isResponse(frame: $0, to: markerRequestID) }
  return try PromptFrames(frames: frames, promptID: firstPromptID)
}

@MainActor
@Suite struct DemoAgentMessageIdTests {
  // MARK: - ScriptedWireAgent

  @Test func theScriptedPromptResultHasAUUIDMessageId() async throws {
    let (agent, client) = startScriptedAgent()
    defer { agent.stop() }

    let prompt = try await promptFrames(from: client)

    let messageID = try #require(prompt.resultMessageID)
    #expect(UUID(uuidString: messageID) != nil)
  }

  @Test func theScriptedAgentSendsTheResultThenAUserMessageEchoThenTheFollowUpsByDefault() async throws {
    let (agent, client) = startScriptedAgent { agent in
      agent.followUps["session/prompt"] = { request, _ in
        let sessionId = request["params"]?["sessionId"] ?? .null
        return [ScriptedWireAgent.makeSessionUpdateFrame(params: .object(["sessionId": sessionId, "update": runningUpdate]))]
      }
    }
    defer { agent.stop() }

    let prompt = try await promptFrames(from: client)

    let echo = try #require(prompt.echo)
    #expect(prompt.updateLabelsAfterResponse == [userMessageLabel, runningLabel])
    #expect(prompt.echoIndexes == [prompt.responseIndex + 1])
    #expect(echo["messageId"]?.stringValue == prompt.resultMessageID)
    #expect(echo["content"] == .array([promptBlock]))
    #expect(prompt.frames[prompt.echoIndexes[0]]["params"]?["sessionId"] == .string(sessionID))
  }

  @Test func theScriptedAgentEchoesAChunkBeforeTheResultWhenTheOptionsAreSet() async throws {
    let (agent, client) = startScriptedAgent { agent in
      agent.promptEchoOrder = .beforeResult
      agent.promptEchoKind = .userMessageChunk
    }
    defer { agent.stop() }

    let prompt = try await promptFrames(from: client)

    let echo = try #require(prompt.echo)
    #expect(prompt.echoIndexes == [prompt.responseIndex - 1])
    #expect(echo["sessionUpdate"] == .string("user_message_chunk"))
    #expect(echo["messageId"]?.stringValue == prompt.resultMessageID)
    #expect(echo["content"] == promptBlock)
  }

  @Test func eachScriptedPromptGetsANewMessageId() async throws {
    let (agent, client) = startScriptedAgent()
    defer { agent.stop() }

    try await client.prompt(id: firstPromptID)
    try await client.prompt(id: secondPromptID)
    let frames = try await client.frames { isResponse(frame: $0, to: secondPromptID) }
    let ids = [firstPromptID, secondPromptID].map { id in
      frames.first { isResponse(frame: $0, to: id) }?["result"]?["messageId"]?.stringValue
    }

    #expect(ids.allSatisfy { $0 != nil })
    #expect(ids[0] != ids[1])
  }

  @Test func aHeldPromptAnswerStopsTheAgentUntilTheRelease() async throws {
    // The hold state of the agent at the time when it reads the marker
    // request. The lead-in of the marker method records it.
    var holdsWhenTheMarkerIsRead: [Bool] = []
    let (agent, client) = startScriptedAgent { agent in
      agent.heldMethods = ["session/prompt"]
      agent.leadIns[markerMethod] = { [weak agent] _, _ in
        holdsWhenTheMarkerIsRead.append(agent?.isHoldingAnswer ?? false)
        return []
      }
    }
    defer { agent.stop() }

    try await client.prompt(id: firstPromptID)
    try await client.request(method: markerMethod, id: markerRequestID, params: .object([:]))
    await ObservationWait.until { agent.isHoldingAnswer }
    // A held answer stops the reader of the agent. The reader handles one
    // frame at a time, and the prompt came before the marker request, so
    // the marker request stays unread until the release.
    #expect(agent.messages(method: "session/prompt").count == 1)
    #expect(agent.messages(method: markerMethod).isEmpty)
    agent.releaseHeldAnswer()
    let frames = try await client.frames { isResponse(frame: $0, to: markerRequestID) }
    let prompt = try PromptFrames(frames: frames, promptID: firstPromptID)

    #expect(holdsWhenTheMarkerIsRead == [false])
    #expect(prompt.resultMessageID != nil)
    #expect(prompt.echo != nil)
  }

  @Test func aReleaseBeforeThePromptLetsTheNextAnswerGoOutAtOnce() async throws {
    let (agent, client) = startScriptedAgent { $0.heldMethods = ["session/prompt"] }
    defer { agent.stop() }
    agent.releaseHeldAnswer()

    let prompt = try await promptFrames(from: client)

    #expect(prompt.resultMessageID != nil)
  }

  // MARK: - InMemoryDemoAgent

  @Test func theInMemoryAgentSendsTheResultThenTheEchoThenRunningThenTheTurnThenIdle() async throws {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agent = InMemoryDemoAgent.start(on: agentEnd)
    defer { agent.stop() }
    let client = RawWireClient(transport: clientEnd)

    try await client.prompt(id: firstPromptID)
    let frames = try await client.frames { $0["params"]?["update"]?["state"] == .string("idle") }
    let prompt = try PromptFrames(frames: frames, promptID: firstPromptID)

    let messageID = try #require(prompt.resultMessageID)
    #expect(UUID(uuidString: messageID) != nil)
    let echo = try #require(prompt.echo)
    #expect(prompt.updateLabelsAfterResponse == inMemoryTurnLabels)
    #expect(echo["messageId"]?.stringValue == messageID)
    #expect(echo["content"] == .array([promptBlock]))
  }
}
