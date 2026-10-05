import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Decodes each fixture.
private func updates(_ fixtures: String...) throws -> [SessionUpdate] {
  try fixtures.map(SessionUpdateFixtures.decode)
}

/// An agent message chunk with the text.
private func agentChunk(_ text: String, id: String = "m1") -> String {
  """
  {"sessionUpdate": "agent_message_chunk", "messageId": "\(id)",
   "content": {"type": "text", "text": "\(text)"}}
  """
}

/// A thought chunk with the text.
private func thoughtChunk(_ text: String, id: String = "t1") -> String {
  """
  {"sessionUpdate": "agent_thought_chunk", "messageId": "\(id)",
   "content": {"type": "text", "text": "\(text)"}}
  """
}

/// A permission request with a tool call subject.
private let toolCallPermissionJSON = #"""
  {"sessionId": "s1", "title": "Edit a.swift",
   "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"}],
   "subject": {"type": "tool_call",
               "toolCall": {"toolCallId": "c1", "title": "Edit a.swift", "kind": "edit"}}}
  """#

/// A URL elicitation of the session `s1`.
private let urlElicitationJSON = #"""
  {"sessionId": "s1", "message": "Sign in", "mode": "url",
   "url": "https://example.com/auth", "elicitationId": "e1"}
  """#

/// An elicitation with a mode that the kit does not know.
private let unknownElicitationJSON = #"{"sessionId": "s1", "message": "Pick", "mode": "picker"}"#

@MainActor
@Suite struct ACPThreadSourceTests {
  /// Makes a source with no stream updates, for the tests that call
  /// `apply(_:)` and the mirror functions.
  private func makeSource() -> ACPThreadSource {
    ACPThreadSource(thread: AgentThread(), updates: AsyncStream { $0.finish() }, agentName: "Agent")
  }

  /// Applies each fixture to the source.
  private func apply(_ fixtures: String..., to source: ACPThreadSource) throws {
    for fixture in fixtures {
      source.apply(try SessionUpdateFixtures.decode(fixture))
    }
  }

  // MARK: - Streams

  @Test func threeAgentMessageChunksMakeOneStreamingMessage() async throws {
    let thread = AgentThread()
    let (stream, continuation) = AsyncStream.makeStream(of: SessionUpdate.self)
    let source = ACPThreadSource(thread: thread, updates: stream, agentName: "Agent")
    let run = Task { await source.run() }

    for update in try updates(agentChunk("Hello"), agentChunk(", "), agentChunk("world.")) {
      continuation.yield(update)
    }
    let joined = await waitUntil {
      thread.streaming["m1"]?.flush()
      return thread.streaming["m1"]?.text == "Hello, world."
    }

    #expect(joined)
    #expect(thread.streaming.count == 1)
    #expect(thread.items.map(\.id) == ["m1"])
    #expect(assistantMessage(thread.item(id: "m1"))?.blocks == [])

    continuation.finish()
    await run.value

    #expect(thread.streaming.isEmpty)
    #expect(
      assistantMessage(thread.item(id: "m1"))?.blocks
        == [AgentViewKit.ContentBlock(text: "Hello, world.")])
  }

  @Test func runReadsTheStreamOneTime() async throws {
    let thread = AgentThread()
    let update = try SessionUpdateFixtures.decode(SessionUpdateFixtures.usage)
    let stream = AsyncStream<SessionUpdate> { continuation in
      continuation.yield(update)
      continuation.finish()
    }
    let source = ACPThreadSource(thread: thread, updates: stream, agentName: "Agent")

    await source.run()
    thread.apply(.setUsage(nil))
    await source.run()

    #expect(thread.usage == nil)
  }

  @Test func toolCallUpdateFromTheStreamMakesANewRecord() async throws {
    let thread = AgentThread()
    let update = try SessionUpdateFixtures.decode(SessionUpdateFixtures.toolCallUpdate)
    let stream = AsyncStream<SessionUpdate> { continuation in
      continuation.yield(update)
      continuation.finish()
    }
    let source = ACPThreadSource(thread: thread, updates: stream, agentName: "Agent")

    await source.run()

    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("The thread has no tool call c1.")
      return
    }
    #expect(call.title == "Read file")
    #expect(call.status == .lost)
  }

  @Test func wholeAgentMessageClosesTheStreamAndReplacesTheContent() throws {
    let source = makeSource()

    try apply(agentChunk("Draft"), SessionUpdateFixtures.agentMessage, to: source)

    #expect(source.thread.streaming.isEmpty)
    #expect(
      assistantMessage(source.thread.item(id: "m1"))?.blocks
        == [AgentViewKit.ContentBlock(text: "Done.")])
  }

  @Test func stateUpdateClosesEachStreamAndSetsTheState() throws {
    let source = makeSource()

    try apply(
      thoughtChunk("Think"), thoughtChunk("ing"), SessionUpdateFixtures.stateIdle, to: source)

    #expect(source.thread.streaming.isEmpty)
    #expect(source.thread.state == .idle(.maxTokens))
    guard case .reasoning(let reasoning)? = source.thread.item(id: "t1") else {
      Issue.record("The thread has no reasoning t1.")
      return
    }
    #expect(reasoning.segments == ["Thinking"])
  }

  @Test func streamForAnotherIdClosesTheOpenStream() throws {
    let source = makeSource()

    try apply(thoughtChunk("Plan"), agentChunk("Answer"), to: source)

    #expect(Array(source.thread.streaming.keys) == ["m1"])
    guard case .reasoning(let reasoning)? = source.thread.item(id: "t1") else {
      Issue.record("The thread has no reasoning t1.")
      return
    }
    #expect(reasoning.segments == ["Plan"])
    #expect(source.thread.items.map(\.id) == ["t1", "m1"])
  }

  @Test func imageChunkClosesTheStreamAndKeepsTheOrderOfTheBlocks() throws {
    let source = makeSource()
    let image = #"""
      {"sessionUpdate": "agent_message_chunk", "messageId": "m1",
       "content": {"type": "image", "data": "AAE=", "mimeType": "image/png"}}
      """#

    try apply(agentChunk("Before"), image, agentChunk("After"), to: source)
    source.apply(try SessionUpdateFixtures.decode(SessionUpdateFixtures.stateIdle))

    #expect(
      assistantMessage(source.thread.item(id: "m1"))?.blocks
        == [
          AgentViewKit.ContentBlock(text: "Before"),
          AgentViewKit.ContentBlock(
            content: .image(AgentViewKit.ImageContent(data: Data([0, 1]), mimeType: "image/png"))),
          AgentViewKit.ContentBlock(text: "After"),
        ])
  }

  @Test func textChunkWithAnnotationsIsAddedAsABlock() throws {
    let source = makeSource()
    let annotated = #"""
      {"sessionUpdate": "agent_message_chunk", "messageId": "m1",
       "content": {"type": "text", "text": "Hidden", "annotations": {"audience": ["assistant"]}}}
      """#

    try apply(annotated, to: source)

    #expect(source.thread.streaming.isEmpty)
    #expect(
      assistantMessage(source.thread.item(id: "m1"))?.blocks
        == [
          AgentViewKit.ContentBlock(
            content: .text("Hidden"), annotations: AgentViewKit.Annotations(audience: [.assistant]))
        ])
  }

  @Test func userMessageChunkStreamsAndKeepsTheMeta() throws {
    let source = makeSource()

    try apply(SessionUpdateFixtures.userMessageChunk, SessionUpdateFixtures.stateIdle, to: source)

    guard case .userMessage(let message)? = source.thread.item(id: "u1") else {
      Issue.record("The thread has no user message u1.")
      return
    }
    #expect(message.blocks == [AgentViewKit.ContentBlock(text: "Fix the bug.")])
    #expect(message.meta == .object(["source": .string("replay")]))
  }

  @Test func chunkForARecordOfAnotherKindReplacesTheRecord() throws {
    let source = makeSource()

    try apply(SessionUpdateFixtures.toolCallUpdate, agentChunk("Text", id: "c1"), to: source)
    source.apply(try SessionUpdateFixtures.decode(SessionUpdateFixtures.stateIdle))

    #expect(
      assistantMessage(source.thread.item(id: "c1"))?.blocks
        == [AgentViewKit.ContentBlock(text: "Text")])
  }

  // MARK: - Pending requests

  @Test func mirrorPermissionsAddsTheToolCallAndTheRequest() throws {
    let source = makeSource()
    let id = UUID()
    let request = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self, toolCallPermissionJSON)

    source.mirrorPermissions([TestPermission(id: id, request: request)])
    source.mirrorPermissions([TestPermission(id: id, request: request)])

    #expect(source.thread.pendingPermissions.map(\.id) == [PermissionRequestID(id.uuidString)])
    guard case .toolCall(let call)? = source.thread.item(id: "c1") else {
      Issue.record("The thread has no tool call c1.")
      return
    }
    #expect(call.kind == .edit)
    #expect(call.revision == 0)
  }

  @Test func mirrorPermissionsResolvesARequestThatIsGone() throws {
    let source = makeSource()
    let request = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self, toolCallPermissionJSON)
    let first = TestPermission(id: UUID(), request: request)
    let second = TestPermission(id: UUID(), request: request)

    source.mirrorPermissions([first, second])
    source.mirrorPermissions([second])

    #expect(source.thread.pendingPermissions.map(\.id) == [PermissionRequestID(second.id.uuidString)])
  }

  @Test func mirrorElicitationsAddsAndResolvesAndSkipsAnUnknownMode() throws {
    let source = makeSource()
    let url = TestElicitation(
      id: UUID(),
      request: try SessionUpdateFixtures.decode(CreateElicitationRequest.self, urlElicitationJSON))
    let unknown = TestElicitation(
      id: UUID(),
      request: try SessionUpdateFixtures.decode(
        CreateElicitationRequest.self, unknownElicitationJSON))

    source.mirrorElicitations([url, unknown])

    #expect(source.thread.pendingElicitations.map(\.id) == [ElicitationRequestID(url.id.uuidString)])
    #expect(source.thread.pendingElicitations.first?.server == "Agent")

    source.mirrorElicitations([TestElicitation]())

    #expect(source.thread.pendingElicitations.isEmpty)
  }

  @Test func mirrorPendingRequestsFollowsTheSessionModel() async throws {
    let harness = try await WireHarness()
    defer { harness.agent.stop() }
    let source = try await harness.openNewSession()
    let session = try #require(source.session)
    let mirror = Task { await source.mirrorPendingRequests(of: session) }

    try await harness.agent.send(agentRequest("session/request_permission", id: 100, params: toolCallPermissionJSON))
    try await harness.agent.send(agentRequest("elicitation/create", id: 101, params: urlElicitationJSON))
    let added = await waitUntil {
      source.thread.pendingPermissions.count == 1 && source.thread.pendingElicitations.count == 1
    }
    #expect(added)

    let pendingPermission = try #require(session.pendingPermissions.first)
    session.selectPermission(pendingPermission.id, option: PermissionOptionId(rawValue: "yes"))
    let pendingElicitation = try #require(session.pendingElicitations.first)
    session.declineElicitation(pendingElicitation.id)

    let resolved = await waitUntil {
      source.thread.pendingPermissions.isEmpty && source.thread.pendingElicitations.isEmpty
    }
    #expect(resolved)
    mirror.cancel()
    await mirror.value
  }

  // MARK: - Session model

  @Test func aPromptShowsTheUserMessageAndTheAgentMessage() async throws {
    let harness = try await WireHarness { agent in
      agent.followUps["session/prompt"] = { _, _ in
        [SessionUpdateFixtures.agentMessage, SessionUpdateFixtures.stateIdle].map(updateFrame)
      }
    }
    defer { harness.agent.stop() }
    let source = try await harness.openNewSession()
    let session = try #require(source.session)
    let run = Task { await source.run() }

    let response = try await harness.agent.bounded {
      try await session.prompt([.text(FoundationModelsACP.TextContent(text: "Hi"))])
    }

    let shown = await waitUntil { source.thread.state == .idle(.maxTokens) }
    #expect(shown)
    #expect(source.thread.items.map(\.id) == [response.messageId.rawValue, "m1"])
    #expect(userMessage(source.thread.items.first)?.blocks == [AgentViewKit.ContentBlock(text: "Hi")])
    #expect(
      assistantMessage(source.thread.item(id: "m1"))?.blocks == [AgentViewKit.ContentBlock(text: "Done.")])
    harness.agent.stop()
    await harness.agent.bounded { await run.value }
  }

  @Test func aNewSessionSeedsTheConfigOptionsAndTheCommandsOfTheResponse() async throws {
    let harness = try await WireHarness { agent in
      agent.results["session/new"] = newSessionWithOptionsResult
    }
    defer { harness.agent.stop() }

    let source = try await harness.openNewSession()

    #expect(source.thread.configOptions.map(\.id) == [ConfigOptionID("mode")])
    #expect(source.thread.availableCommands.map(\.name) == ["review"])
  }

  @Test func aResumeShowsTheReplayedEntries() async throws {
    let replay = [
      SessionUpdateFixtures.userMessage, SessionUpdateFixtures.agentThought, SessionUpdateFixtures.agentMessage,
      SessionUpdateFixtures.toolCallUpdate, SessionUpdateFixtures.terminalUpdate, SessionUpdateFixtures.planUpdate,
      SessionUpdateFixtures.unknownUpdate, compactionUpdate,
    ]
    let harness = try await WireHarness { agent in
      agent.leadIns["session/resume"] = { _, _ in replay.map(updateFrame) }
    }
    defer { harness.agent.stop() }

    let source = try await harness.agent.bounded {
      try await ACPThreadSource.resumeSession(
        SessionId(rawValue: sessionID), cwd: AbsolutePath(rawValue: sessionCwd), on: harness.connection,
        thread: AgentThread(), agentName: "Agent")
    }

    let thread = source.thread
    #expect(Array(thread.items.map(\.id).prefix(replayedItemIDs.count)) == replayedItemIDs)
    #expect(userMessage(thread.item(id: "u1"))?.blocks == [AgentViewKit.ContentBlock(text: "Fix it.")])
    #expect(userMessage(thread.item(id: "u1"))?.meta == .object(["edited": .bool(true)]))
    #expect(reasoning(thread.item(id: "t1"))?.segments == ["Plan", "Act"])
    #expect(assistantMessage(thread.item(id: "m1"))?.blocks == [AgentViewKit.ContentBlock(text: "Done.")])
    #expect(toolCall(thread.item(id: "c1"))?.title == "Read file")
    // The kit does not decode terminal output. `TerminalEntry.text` gives it.
    #expect(thread.terminals[TerminalID("term1")]?.output.isEmpty == true)
    #expect(thread.plans[PlanID("p1")] != nil)
    #expect(unknownKinds(of: thread) == ["mood_update", "compaction_update"])
    #expect(thread.streaming.isEmpty)
    let resume = try #require(harness.agent.messages(method: "session/resume").first)
    #expect(resume["params"]?["replayFrom"] == .object(["type": .string("start")]))
  }

  @Test func aSourceOverAnOpenSessionShowsTheErrorOfAFailedPrompt() async throws {
    let harness = try await WireHarness { agent in
      agent.failingMethods = ["session/prompt"]
    }
    defer { harness.agent.stop() }
    let session = try #require(try await harness.openNewSession().session)
    _ = try? await harness.agent.bounded {
      try await session.prompt([.text(FoundationModelsACP.TextContent(text: "Hi"))])
    }

    let source = ACPThreadSource(thread: AgentThread(), session: session, agentName: "Agent")

    let errors = source.thread.items.compactMap { item in
      if case .error(let error) = item { error.kind } else { nil }
    }
    #expect(errors == [.acp(code: internalErrorCode, message: "failed")])
  }
}

// MARK: - Wire harness

/// The id of the session of the wire tests.
private let sessionID = "s1"

/// The working directory of the session of the wire tests.
private let sessionCwd = "/tmp/source"

/// The JSON-RPC error code that a scripted failure of the agent sends.
private let internalErrorCode = -32603

/// The ids of the items that the replay of ``ACPThreadSourceTests`` adds, in
/// order. The unknown updates get generated ids, so they are not in the list.
private let replayedItemIDs = ["u1", "t1", "m1", "c1"]

/// An `initialize` result with protocol version 2 and the session
/// capabilities, so that the connection model can resume a session.
private let initializeResult = #"""
  {"info": {"name": "agent", "version": "1.0.0"}, "protocolVersion": 2,
   "capabilities": {"session": {}}}
  """#

/// A `session/new` result with a config option and a command.
private let newSessionWithOptionsResult = #"""
  {"sessionId": "s1",
   "configOptions": [{"configId": "mode", "name": "Mode", "type": "select", "currentValue": "ask",
                      "options": [{"value": "ask", "name": "Ask"}]}],
   "availableCommands": [{"name": "review", "description": "Review the code"}]}
  """#

/// A compaction update, which the stable schema reads as an unknown update.
private let compactionUpdate = #"""
  {"sessionUpdate": "compaction_update", "compactionId": "k1", "status": "completed"}
  """#

/// A `session/update` frame of the session with one update.
///
/// - Parameter update: The JSON text of the update.
/// - Returns: The frame.
private func updateFrame(_ update: String) -> String {
  #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"\#(sessionID)","update":\#(update)}}"#
}

/// A JSON-RPC request from the agent.
///
/// - Parameters:
///   - method: The method of the request.
///   - id: The JSON-RPC id of the request.
///   - params: The JSON text of the parameters.
/// - Returns: The frame.
private func agentRequest(_ method: String, id: Int, params: String) -> String {
  #"{"jsonrpc":"2.0","id":\#(id),"method":"\#(method)","params":\#(params)}"#
}

/// The objects of a test over the scripted agent: the agent and the
/// connection model, after `initialize`.
@MainActor
private struct WireHarness {
  /// The scripted agent.
  let agent: ScriptedWireAgent

  /// The connection model of the client, with no chunk delay.
  let connection = ConnectionModel(coalescingCadence: .zero)

  /// Connects the model to a scripted agent and sends `initialize`.
  ///
  /// - Parameter configure: Changes the agent before it starts.
  init(configure: (ScriptedWireAgent) -> Void = { _ in }) async throws {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    agent = ScriptedWireAgent(transport: agentEnd)
    agent.results["initialize"] = initializeResult
    agent.results["session/new"] = #"{"sessionId": "\#(sessionID)"}"#
    configure(agent)
    agent.start()
    let connection = connection
    _ = await connection.connect(over: clientEnd)
    _ = try await agent.bounded {
      try await connection.initialize(
        InitializeRequest(info: Implementation(name: "AgentViewKitTests", version: "1.0.0"), protocolVersion: .v2))
    }
  }

  /// Opens a new session on a new thread.
  ///
  /// - Returns: The source of the session.
  func openNewSession() async throws -> ACPThreadSource {
    try await agent.bounded {
      try await ACPThreadSource.openNewSession(
        NewSessionRequest(cwd: AbsolutePath(rawValue: sessionCwd)), on: connection, thread: AgentThread(),
        agentName: "Agent")
    }
  }
}

// MARK: - Item helpers

/// The message of a user message item, or `nil` for another item.
@MainActor
private func userMessage(_ item: ThreadItem?) -> Message? {
  if case .userMessage(let message) = item { message } else { nil }
}

/// The message of an assistant message item, or `nil` for another item.
@MainActor
private func assistantMessage(_ item: ThreadItem?) -> Message? {
  if case .assistantMessage(let message) = item { message } else { nil }
}

/// The record of a reasoning item, or `nil` for another item.
@MainActor
private func reasoning(_ item: ThreadItem?) -> Reasoning? {
  if case .reasoning(let reasoning) = item { reasoning } else { nil }
}

/// The record of a tool call item, or `nil` for another item.
@MainActor
private func toolCall(_ item: ThreadItem?) -> ToolCallRecord? {
  if case .toolCall(let call) = item { call } else { nil }
}

/// The kinds of the unknown items of a thread, in order.
@MainActor
private func unknownKinds(of thread: AgentThread) -> [String] {
  thread.items.compactMap { item in
    if case .unknown(let unknown) = item { unknown.kind } else { nil }
  }
}
