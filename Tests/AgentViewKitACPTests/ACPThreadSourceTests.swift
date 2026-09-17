import AgentViewKit
import AgentViewKitACP
import AgentViewKitTestSupport
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

  /// The message of an assistant message item, or `nil` for another item.
  private func assistantMessage(_ item: ThreadItem?) -> Message? {
    if case .assistantMessage(let message) = item { message } else { nil }
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

  @Test func mirrorPendingRequestsFollowsTheSessionAndTheClient() async throws {
    let source = makeSource()
    let client = SwiftUIACPClient()
    let sessionId = SessionId(rawValue: "s1")
    let session = client.session(for: sessionId)
    let permission = try SessionUpdateFixtures.decode(
      RequestPermissionRequest.self, toolCallPermissionJSON)
    let elicitation = try SessionUpdateFixtures.decode(
      CreateElicitationRequest.self, urlElicitationJSON)
    let mirror = Task { await source.mirrorPendingRequests(of: session, client: client, sessionId: sessionId) }
    let permissionCall = Task { await session.awaitPermissionDecision(for: permission) }
    let elicitationCall = Task { try await client.createElicitation(elicitation) }

    let added = await waitUntil {
      source.thread.pendingPermissions.count == 1 && source.thread.pendingElicitations.count == 1
    }
    #expect(added)

    let pendingPermission = try #require(session.pendingPermissionRequests.first)
    session.answerPermissionRequest(pendingPermission.id, with: PermissionOptionId(rawValue: "yes"))
    let pendingElicitation = try #require(client.pendingElicitations.first)
    client.declineElicitation(pendingElicitation.id)
    _ = await permissionCall.value
    _ = try await elicitationCall.value

    let resolved = await waitUntil {
      source.thread.pendingPermissions.isEmpty && source.thread.pendingElicitations.isEmpty
    }
    #expect(resolved)
    mirror.cancel()
    await mirror.value
  }
}
