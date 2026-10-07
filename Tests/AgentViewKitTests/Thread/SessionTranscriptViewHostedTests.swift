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

    /// The number of entries in the chunk test.
    static let chunkMessageCount = 3

    /// The position of the entry that the chunk test changes.
    static let chunkedPosition = 1

    /// The text chunks that the stream test sends to one agent message, in
    /// order. Each chunk after the first starts a new paragraph.
    static let streamedChunks = ["One.", "\n\nTwo.", "\n\nThree."]

    /// The `messageId` of the agent message of the stream test.
    static let streamedMessageID = "stream-m"

    /// A `session/update` value with one text chunk.
    ///
    /// - Parameters:
    ///   - kind: The `sessionUpdate` tag, such as `agent_message_chunk`.
    ///   - messageID: The `messageId` of the chunk.
    ///   - text: The text of the chunk. Each line break becomes the JSON
    ///     escape `\n`.
    /// - Returns: The JSON text of the update.
    static func chunk(_ kind: String, messageID: String, text: String) -> String {
      WireBlockJSON.makeChunk(kind, messageID: messageID, block: WireBlockJSON.makeText(text))
    }

    /// Tells whether `harness` shows `text` as the paragraphs that a pure
    /// call of `ParagraphSplitter` makes of it.
    ///
    /// The harness must show one paragraph element for each paragraph, and
    /// no more, and a text element with the text of each paragraph.
    ///
    /// - Parameters:
    ///   - text: The whole text of an entry.
    ///   - harness: The harness that shows the thread.
    /// - Returns: `true` when the harness shows each paragraph of `text`.
    static func showsParagraphs<Content: View>(of text: String, in harness: HostedViewHarness<Content>) -> Bool {
      let paragraphs = ParagraphSplitter.paragraphs(text)
      let elements = harness.accessibilityElements()
      let identifiers = elements.compactMap(\.identifier).filter {
        $0.hasPrefix(ResponseView.paragraphIdentifierPrefix)
      }
      let labels = Set(elements.compactMap(\.label))
      return identifiers == paragraphs.map { ResponseView.paragraphIdentifier(index: $0.id.index) }
        && paragraphs.allSatisfy { labels.contains($0.text) }
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

    /// The text of the agent message entry or the thought entry at
    /// `position` of `model`.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - position: The position of the entry in the transcript.
    /// - Returns: The text, or `nil` when the entry is not an agent message
    ///   or a thought.
    static func entryText(of model: SessionModel, at position: Int) -> String? {
      guard model.transcript.indices.contains(position) else { return nil }
      let entry = model.transcript[position]
      if case .agentMessage(let message) = entry { return text(of: message.content) }
      if case .thought(let thought) = entry { return text(of: thought.content) }
      return nil
    }

    /// Sends one chunk to each of ``chunkMessageCount`` entries of one kind,
    /// then one more chunk to the entry at ``chunkedPosition``, and expects
    /// that the last chunk evaluates the content of that row only.
    ///
    /// - Parameter kind: The `sessionUpdate` tag of the chunks, such as
    ///   `agent_message_chunk` or `agent_thought_chunk`.
    static func expectAChunkEvaluatesOnlyTheRowOfItsEntry(kind: String) async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: tallSize)
      defer { harness.close() }
      let model = session.model
      for position in 0..<chunkMessageCount {
        try await session.sendUpdate(chunk(kind, messageID: "chunk-m\(position)", text: "Message \(position)."))
      }
      await harness.pump(until: waitTimeout) { rowKeys(in: harness).count == chunkMessageCount }
      let keys = model.transcript.map(\.id.rowKey)
      for key in keys {
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) >= 1)
        BodyEvaluationCounter.reset(ItemRow.contentCounterKey(for: key))
        BodyEvaluationCounter.reset(ItemRow.counterKey(for: key))
      }

      try await session.sendUpdate(chunk(kind, messageID: "chunk-m\(chunkedPosition)", text: " More."))
      await harness.pump(until: waitTimeout) {
        entryText(of: model, at: chunkedPosition) == "Message \(chunkedPosition). More."
      }
      harness.pump()

      for (position, key) in keys.enumerated() {
        let expected = position == chunkedPosition ? 1 : 0
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) == expected, "\(key)")
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: key)) == 0, "\(key)")
        BodyEvaluationCounter.reset(ItemRow.contentCounterKey(for: key))
        BodyEvaluationCounter.reset(ItemRow.counterKey(for: key))
      }
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
      await harness.pump(until: Self.waitTimeout) { Self.entryText(of: model, at: 0) == "Hello world." }
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

    @Test func eachAppliedChunkShowsTheWholeEntryTextAndIdleChangesNothing() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model, actions: NoopThreadActions()), size: Self.tallSize)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(ScriptedSession.runningState)
      for (index, chunk) in Self.streamedChunks.enumerated() {
        try await session.sendUpdate(
          Self.chunk("agent_message_chunk", messageID: Self.streamedMessageID, text: chunk))
        model.flushPendingChunks()
        let sent = Self.streamedChunks[...index].joined()
        await harness.pump(until: Self.waitTimeout) { Self.entryText(of: model, at: 0) == sent }
        let text = try #require(Self.entryText(of: model, at: 0))
        await harness.pump(until: Self.waitTimeout) { Self.showsParagraphs(of: text, in: harness) }
        #expect(Self.showsParagraphs(of: text, in: harness), "\(text)")
        #expect(harness.element(identifier: ResponseView.tailIdentifier) == nil)
      }
      #expect(ComposerSessionModelHostedTests.isRunning(model))

      try await session.sendUpdate(ScriptedSession.idleState)
      await harness.pump(until: Self.waitTimeout) { !ComposerSessionModelHostedTests.isRunning(model) }
      harness.pump()

      #expect(Self.showsParagraphs(of: Self.streamedChunks.joined(), in: harness))
      #expect(harness.element(identifier: ResponseView.tailIdentifier) == nil)
    }

    @Test func aChunkEvaluatesOnlyTheRowOfItsEntry() async throws {
      try await Self.expectAChunkEvaluatesOnlyTheRowOfItsEntry(kind: "agent_message_chunk")
    }

    // MARK: - Overrides and the expanded policy

    /// The accessibility identifier of the host tool call view of the
    /// override test.
    static let customToolCallIdentifier = "custom-tool-call"

    /// The `toolCallId` of the tool call of the override and policy tests.
    static let overrideCallID = "override-c"

    /// The `messageId` of the agent message of the override test.
    static let overrideMessageID = "override-m"

    /// The title of the tool call of the override and policy tests.
    static let overrideCallTitle = "Read"

    /// The text of the content part of the tool call of the override and
    /// policy tests. The open body of the call shows it.
    static let overrideCallOutput = "Output."

    /// A `tool_call_update` value that sets the title, the status and one
    /// text content part of the tool call of the override and policy tests.
    ///
    /// - Parameter status: The ACP status, such as `pending`.
    /// - Returns: The JSON text of the update.
    static func overrideCallUpdate(status: String) -> String {
      let content = #"[{"type": "content", "content": \#(WireBlockJSON.makeText(overrideCallOutput))}]"#
      return WireBlockJSON.makeToolCallUpdate(
        id: overrideCallID,
        fields: #""status": "\#(status)", "title": "\#(overrideCallTitle)", "content": \#(content)"#)
    }

    /// The label of the host tool call view for a call with the title of the
    /// override test.
    ///
    /// - Parameter status: The ACP status of the call.
    /// - Returns: The label.
    static func customLabel(status: FoundationModelsACP.ToolCallStatus) -> String {
      ToolCallView.accessibilityLabel(title: overrideCallTitle, status: status)
    }

    @Test func aHostToolCallOverrideReplacesOnlyTheToolCallViewAndShowsAStatusChange() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.tallSize) {
        AgentThreadView(session: session.model, actions: NoopThreadActions())
          .toolCallView { call in
            Text(ToolCallView.accessibilityLabel(title: call.title ?? "", status: call.status ?? .pending))
              .accessibilityIdentifier(Self.customToolCallIdentifier)
          }
      }
      defer { harness.close() }

      try await session.sendUpdate(Self.overrideCallUpdate(status: "pending"))
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: Self.overrideMessageID, text: "Done."))
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == 2 }
      let keys = session.model.transcript.map(\.rowKey)
      #expect(keys.count == 2)
      let callKey = try #require(keys.first)
      let messageKey = try #require(keys.last)
      #expect(harness.element(identifier: Self.customToolCallIdentifier)?.label == Self.customLabel(status: .pending))
      #expect(harness.element(identifier: ToolCallView.identifier(for: callKey)) == nil)
      #expect(harness.element(identifier: AssistantMessageView.identifier(for: messageKey)) != nil)

      try await session.sendUpdate(Self.overrideCallUpdate(status: "completed"))
      let completed = Self.customLabel(status: .completed)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.customToolCallIdentifier)?.label == completed
      }

      #expect(harness.element(identifier: Self.customToolCallIdentifier)?.label == completed)
    }

    @Test func theExpandedPolicyOpensAToolCallEntryWhenTheModelSetsFailed() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let store = ExpandedBlocksStore { entry in
        if case .toolCall(let call) = entry { call.status == .failed } else { false }
      }
      let harness = HostedViewHarness(size: Self.tallSize) {
        AgentThreadView(session: session.model, actions: NoopThreadActions())
          .environment(\.expandedBlocksStore, store)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }

      try await session.sendUpdate(Self.overrideCallUpdate(status: "in_progress"))
      await harness.pump(until: Self.waitTimeout) { Self.rowKeys(in: harness).count == 1 }
      let key = try #require(session.model.transcript.first?.rowKey)
      let body = ToolCallView.bodyIdentifier(for: key)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) != nil)
      #expect(harness.element(identifier: body) == nil)

      try await session.sendUpdate(Self.overrideCallUpdate(status: "failed"))
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: body) != nil }

      #expect(harness.element(identifier: body) != nil)
    }
  }
#endif
