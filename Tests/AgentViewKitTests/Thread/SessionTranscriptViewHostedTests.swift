#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The thread view over the transcript of a `SessionModel` (update.md §4.2,
  /// §4.7 "Row identity").
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionTranscriptViewHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row of the tests.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The number of agent messages in the chunk test.
    static let chunkMessageCount = 3

    /// The position of the agent message that the chunk test changes.
    static let chunkedPosition = 1

    /// The `session/update` value that tells that the agent runs.
    static let runningState = #"{"sessionUpdate":"state_update","state":"running"}"#

    /// The `session/update` value that tells that the agent is idle.
    static let idleState = #"{"sessionUpdate":"state_update","state":"idle"}"#

    /// A `session/update` value with one text chunk.
    ///
    /// - Parameters:
    ///   - kind: The `sessionUpdate` tag, such as `agent_message_chunk`.
    ///   - messageID: The `messageId` of the chunk.
    ///   - text: The text of the chunk.
    /// - Returns: The JSON text of the update.
    static func chunk(_ kind: String, messageID: String, text: String) -> String {
      #"{"sessionUpdate":"\#(kind)","messageId":"\#(messageID)","content":{"type":"text","text":"\#(text)"}}"#
    }

    /// The row keys of the rows that `harness` shows, in view order.
    ///
    /// - Parameter harness: The harness that shows the thread.
    /// - Returns: The row key of each row.
    static func rowKeys<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
      harness.accessibilityElements()
        .compactMap(\.identifier)
        .filter { $0.hasPrefix(ItemRow.identifierPrefix) }
        .map { String($0.dropFirst(ItemRow.identifierPrefix.count)) }
    }

    /// The text of the text blocks of a list of content blocks. Each chunk
    /// of a message is one block, so the text joins the blocks with no
    /// separator.
    ///
    /// - Parameter content: The content blocks of an entry.
    /// - Returns: The joined text.
    static func text(of content: [FoundationModelsACP.ContentBlock]) -> String {
      content.compactMap { block -> String? in
        if case .text(let text) = block { text.text } else { nil }
      }.joined()
    }

    /// The user message object of an entry.
    ///
    /// - Parameter entry: A transcript entry.
    /// - Returns: The object, or `nil` when the entry is not a user message.
    static func userMessage(_ entry: TranscriptEntry) -> UserMessageEntry? {
      if case .userMessage(let message) = entry { message } else { nil }
    }

    /// The text of the agent message entry at `position` of `model`.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - position: The position of the entry in the transcript.
    /// - Returns: The text, or `nil` when the entry is not an agent message.
    static func agentText(of model: SessionModel, at position: Int) -> String? {
      guard model.transcript.indices.contains(position),
        case .agentMessage(let entry) = model.transcript[position]
      else { return nil }
      return text(of: entry.content)
    }

    @Test func aUserMessageAThoughtAndAnAgentMessageShowThreeRowsInOrder() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }

      try await session.sendUpdate(Self.chunk("user_message_chunk", messageID: "order-u", text: "Question."))
      try await session.sendUpdate(Self.chunk("agent_thought_chunk", messageID: "order-m", text: "Thinking."))
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: "order-m", text: "Answer."))
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == 3 }

      let expected = session.model.transcript.map(\.id.rowKey)
      #expect(expected.count == 3)
      #expect(Self.rowKeys(in: harness) == expected)
      #expect(harness.element(identifier: UserMessageView.identifier(for: expected[0])) != nil)
      #expect(harness.element(identifier: ReasoningView.identifier(for: expected[1])) != nil)
      #expect(harness.element(identifier: AssistantMessageView.identifier(for: expected[2])) != nil)
    }

    @Test func theRowKeepsItsIdentityWhenAPendingUserMessageGetsItsMessageID() async throws {
      let session = try await ScriptedSession.open { $0.promptEchoOrder = .afterResult }
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }
      let model = session.model

      let prompt = Task { try await model.prompt([.text(TextContent(text: "Hello."))]) }
      await harness.pump(until: Self.waitTimeout) { !model.transcript.isEmpty }
      let firstEntry = try #require(model.transcript.first)
      let pending = try #require(Self.userMessage(firstEntry))
      #expect(firstEntry.id.origin == .local)
      _ = try await prompt.value
      await harness.pump(until: Self.waitTimeout) { pending.sendState == .sent }
      harness.pump()

      #expect(pending.messageId != nil)
      #expect(model.transcript.map(\.id) == [firstEntry.id])
      #expect(Self.rowKeys(in: harness) == [firstEntry.id.rowKey])
    }

    @Test func aToolCallEntryShowsTheToolCallView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }

      try await session.sendUpdate(
        #"{"sessionUpdate":"tool_call_update","toolCallId":"row-c","status":"pending","title":"Read"}"#)
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == 1 }

      let key = try #require(session.model.transcript.first?.rowKey)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key))?.label == "Read, Pending")
      #expect(harness.element(identifier: UnknownItemView.identifier) == nil)
    }

    @Test func theChunksOfOneMessageShowAsOneParagraph() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: "join-m", text: "Hello "))
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: "join-m", text: "world."))
      await harness.pump(until: Self.waitTimeout) { Self.agentText(of: model, at: 0) == "Hello world." }
      harness.pump()

      let paragraphs = harness.accessibilityElements().filter {
        $0.identifier == ResponseView.paragraphIdentifier(index: 0)
      }
      #expect(paragraphs.count == 1)
    }

    @Test func theScrollAnchorsSeeTheRowKeyOfEachRowInView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(
        ConversationView(session: session.model, anchors: anchors), size: Self.tallSize)
      defer { harness.close() }

      try await session.sendUpdate(Self.chunk("user_message_chunk", messageID: "anchor-u", text: "Question."))
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: "anchor-m", text: "Answer."))
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.count == 2 }

      #expect(anchors.visibleIDs == session.model.transcript.map(\.rowKey))
    }

    @Test func theLastAgentMessageShowsTheStreamingTailWhileTheAgentRuns() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }

      try await session.sendUpdate(Self.runningState)
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: "tail-m", text: "Partial **bold"))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ResponseView.tailIdentifier) != nil
      }
      #expect(harness.element(identifier: ResponseView.tailIdentifier) != nil)

      try await session.sendUpdate(Self.idleState)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ResponseView.tailIdentifier) == nil
      }
      #expect(harness.element(identifier: ResponseView.tailIdentifier) == nil)
      #expect(harness.element(identifier: ResponseView.paragraphIdentifier(index: 0)) != nil)
    }

    @Test func theLastThoughtIsInProgressWhileTheAgentRuns() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }

      try await session.sendUpdate(Self.runningState)
      try await session.sendUpdate(Self.chunk("agent_thought_chunk", messageID: "progress-t", text: "Thinking."))
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == 1 }
      let key = try #require(session.model.transcript.first?.rowKey)
      #expect(harness.element(identifier: ReasoningView.bodyIdentifier(for: key)) != nil)
      #expect(harness.element(identifier: ReasoningView.titleIdentifier(for: key)) == nil)

      try await session.sendUpdate(Self.idleState)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ReasoningView.titleIdentifier(for: key)) != nil
      }
      #expect(harness.element(identifier: ReasoningView.titleIdentifier(for: key)) != nil)
    }

    @Test func aChunkEvaluatesOnlyTheRowOfItsEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }
      let model = session.model
      for position in 0..<Self.chunkMessageCount {
        try await session.sendUpdate(
          Self.chunk("agent_message_chunk", messageID: "chunk-m\(position)", text: "Message \(position)."))
      }
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == Self.chunkMessageCount }
      let keys = model.transcript.map(\.id.rowKey)
      for key in keys {
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) >= 1)
        BodyEvaluationCounter.reset(ItemRow.contentCounterKey(for: key))
        BodyEvaluationCounter.reset(ItemRow.counterKey(for: key))
      }

      try await session.sendUpdate(
        Self.chunk("agent_message_chunk", messageID: "chunk-m\(Self.chunkedPosition)", text: " More."))
      await harness.pump(until: Self.waitTimeout) {
        Self.agentText(of: model, at: Self.chunkedPosition) == "Message \(Self.chunkedPosition). More."
      }
      harness.pump()

      for (position, key) in keys.enumerated() {
        let expected = position == Self.chunkedPosition ? 1 : 0
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) == expected, "\(key)")
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: key)) == 0, "\(key)")
        BodyEvaluationCounter.reset(ItemRow.contentCounterKey(for: key))
        BodyEvaluationCounter.reset(ItemRow.counterKey(for: key))
      }
    }
  }
#endif
