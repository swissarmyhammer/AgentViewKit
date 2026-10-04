import AgentViewKit
import DemoSupport
import Foundation
import FoundationModelsACP
import Testing

/// The byte that ends each JSON-RPC frame on the wire.
private let frameEnd = UInt8(ascii: "\n")

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

/// The client end of an agent. It writes raw request frames and reads the raw
/// frames of the agent.
private struct RawClient {
  /// The client end of the transport.
  let transport: InMemoryTransport

  /// Writes one request frame.
  ///
  /// - Parameters:
  ///   - method: The JSON-RPC method.
  ///   - id: The JSON-RPC id.
  ///   - params: The parameters.
  func request(_ method: String, id: Double, params: AgentViewKit.JSONValue) async throws {
    let frame = AgentViewKit.JSONValue.object([
      "jsonrpc": .string("2.0"), "id": .number(id), "method": .string(method), "params": params,
    ])
    try await transport.write(Data((frame.jsonString + "\n").utf8))
  }

  /// Writes a `session/prompt` request with one text block.
  ///
  /// - Parameter id: The JSON-RPC id.
  func prompt(id: Double) async throws {
    let params = AgentViewKit.JSONValue.object([
      "sessionId": .string(sessionID),
      "prompt": .array([.object(["type": .string("text"), "text": .string(promptText)])]),
    ])
    try await request("session/prompt", id: id, params: params)
  }

  /// Reads the frames of the agent until a frame matches `isLast`.
  ///
  /// - Parameter isLast: Tells if a frame is the last frame to read.
  /// - Returns: The frames in arrival order, the last frame included.
  func frames(through isLast: (AgentViewKit.JSONValue) -> Bool) async throws -> [AgentViewKit.JSONValue] {
    var frames: [AgentViewKit.JSONValue] = []
    var buffer = Data()
    for try await chunk in transport.bytes {
      buffer.append(chunk)
      while let end = buffer.firstIndex(of: frameEnd) {
        let line = Data(buffer[buffer.startIndex..<end])
        buffer = Data(buffer[buffer.index(after: end)...])
        let frame = try JSONDecoder().decode(AgentViewKit.JSONValue.self, from: line)
        frames.append(frame)
        if isLast(frame) { return frames }
      }
    }
    return frames
  }
}

/// Tells if `frame` is the response to the request with `id`.
private func isResponse(_ frame: AgentViewKit.JSONValue, to id: Double) -> Bool {
  frame["method"] == nil && frame["id"] == .number(id)
}

/// The update of a `session/update` frame that echoes a user message, or
/// `nil`.
private func userMessageEcho(in frame: AgentViewKit.JSONValue) -> AgentViewKit.JSONValue? {
  guard frame["method"]?.stringValue == "session/update",
    let update = frame["params"]?["update"],
    let kind = update["sessionUpdate"]?.stringValue,
    kind == "user_message_chunk" || kind == "user_message"
  else { return nil }
  return update
}

/// The frames of one prompt, read from an agent.
private struct PromptFrames {
  /// The frames in arrival order.
  let frames: [AgentViewKit.JSONValue]

  /// The position of the response to the prompt.
  let responseIndex: Int

  /// The position of each echoed user message.
  let echoIndexes: [Int]

  /// Reads the frames.
  ///
  /// - Parameters:
  ///   - frames: The frames in arrival order.
  ///   - promptID: The JSON-RPC id of the prompt.
  init(_ frames: [AgentViewKit.JSONValue], promptID: Double) throws {
    self.frames = frames
    responseIndex = try #require(frames.firstIndex { isResponse($0, to: promptID) })
    echoIndexes = frames.indices.filter { userMessageEcho(in: frames[$0]) != nil }
  }

  /// The `messageId` of the prompt result.
  var resultMessageID: String? {
    frames[responseIndex]["result"]?["messageId"]?.stringValue
  }

  /// The one echoed user message.
  var echo: AgentViewKit.JSONValue? {
    echoIndexes.count == 1 ? userMessageEcho(in: frames[echoIndexes[0]]) : nil
  }
}

/// Starts a plain scripted agent and gives the client end.
///
/// - Parameter configure: Changes the agent before it starts.
/// - Returns: The agent and the client end.
private func startScriptedAgent(
  _ configure: (ScriptedWireAgent) -> Void = { _ in }
) -> (ScriptedWireAgent, RawClient) {
  let (clientEnd, agentEnd) = InMemoryTransport.pair()
  let agent = ScriptedWireAgent(transport: agentEnd)
  configure(agent)
  agent.start()
  return (agent, RawClient(transport: clientEnd))
}

/// Sends one prompt to a scripted agent, then the marker request, and reads
/// each frame of the prompt.
private func promptFrames(of agent: ScriptedWireAgent, client: RawClient) async throws -> PromptFrames {
  try await agent.bounded {
    try await client.prompt(id: firstPromptID)
    try await client.request(markerMethod, id: markerRequestID, params: .object([:]))
    let frames = try await client.frames { isResponse($0, to: markerRequestID) }
    return try PromptFrames(frames, promptID: firstPromptID)
  }
}

@MainActor
@Suite struct DemoAgentMessageIdTests {
  // MARK: - ScriptedWireAgent

  @Test func theScriptedPromptResultHasAUUIDMessageId() async throws {
    let (agent, client) = startScriptedAgent()
    defer { agent.stop() }

    let prompt = try await promptFrames(of: agent, client: client)

    let messageID = try #require(prompt.resultMessageID)
    #expect(UUID(uuidString: messageID) != nil)
  }

  @Test func theScriptedAgentEchoesThePromptBeforeTheResultByDefault() async throws {
    let (agent, client) = startScriptedAgent()
    defer { agent.stop() }

    let prompt = try await promptFrames(of: agent, client: client)

    let echo = try #require(prompt.echo)
    #expect(prompt.echoIndexes == [prompt.responseIndex - 1])
    #expect(echo["sessionUpdate"] == .string("user_message_chunk"))
    #expect(echo["messageId"]?.stringValue == prompt.resultMessageID)
    #expect(echo["content"] == .object(["type": .string("text"), "text": .string(promptText)]))
    #expect(prompt.frames[prompt.echoIndexes[0]]["params"]?["sessionId"] == .string(sessionID))
  }

  @Test func theScriptedAgentEchoesThePromptAfterTheResultWhenTheOptionIsSet() async throws {
    let (agent, client) = startScriptedAgent { $0.promptEchoOrder = .afterResult }
    defer { agent.stop() }

    let prompt = try await promptFrames(of: agent, client: client)

    let echo = try #require(prompt.echo)
    #expect(prompt.echoIndexes == [prompt.responseIndex + 1])
    #expect(echo["messageId"]?.stringValue == prompt.resultMessageID)
  }

  @Test func eachScriptedPromptGetsANewMessageId() async throws {
    let (agent, client) = startScriptedAgent()
    defer { agent.stop() }

    let ids = try await agent.bounded {
      try await client.prompt(id: firstPromptID)
      try await client.prompt(id: secondPromptID)
      let frames = try await client.frames { isResponse($0, to: secondPromptID) }
      return [firstPromptID, secondPromptID].map { id in
        frames.first { isResponse($0, to: id) }?["result"]?["messageId"]?.stringValue
      }
    }

    #expect(ids.allSatisfy { $0 != nil })
    #expect(ids[0] != ids[1])
  }

  // MARK: - InMemoryDemoAgent

  @Test func theInMemoryAgentGivesAMessageIdAndOneEchoBeforeTheResult() async throws {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agent = InMemoryDemoAgent.start(on: agentEnd)
    defer { agent.stop() }
    let client = RawClient(transport: clientEnd)

    let prompt = try await agent.bounded {
      try await client.prompt(id: firstPromptID)
      let frames = try await client.frames { $0["params"]?["update"]?["state"] == .string("idle") }
      return try PromptFrames(frames, promptID: firstPromptID)
    }

    let messageID = try #require(prompt.resultMessageID)
    #expect(UUID(uuidString: messageID) != nil)
    let echo = try #require(prompt.echo)
    #expect(prompt.echoIndexes == [prompt.responseIndex - 1])
    #expect(echo["messageId"]?.stringValue == messageID)
    #expect(echo["content"] == .object(["type": .string("text"), "text": .string(promptText)]))
  }
}
