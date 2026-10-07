#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct ConversationViewHostedTests {
    /// The number of entries in the transcript of the page tests.
    static let longEntryCount = 300

    /// The number of entries in the transcript of the scroll tests. The
    /// transcript is taller than the harness window.
    static let scrollEntryCount = 30

    /// The page size of the modifier test.
    static let smallPageSize = 10

    /// The number of entries in the transcript of the modifier test.
    static let smallEntryCount = 25

    /// The longest time that a test waits for a view change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// The message id of the agent message that the scroll tests add.
    static let insertedMessageID = "inserted-message"

    /// The start of the message id of each agent message that a test sends.
    static let messagePrefix = "conversation-m"

    /// The accessibility identifier of the custom empty state.
    static let customEmptyIdentifier = "custom-empty-state"

    /// The accessibility value of the list.
    ///
    /// - Parameter harness: The harness that shows the conversation.
    /// - Returns: The value, or `nil` when the list is not in the tree.
    static func listValue<Content: View>(in harness: HostedViewHarness<Content>) -> String? {
      harness.element(identifier: ConversationLayout.listIdentifier)?.value
    }

    /// Opens a scripted session whose transcript has `count` agent messages.
    ///
    /// - Parameter count: The number of agent messages.
    /// - Returns: The session, after the model shows each message.
    /// - Throws: The error of the scripted session.
    static func openSession(messages count: Int) async throws -> ScriptedSession {
      let session = try await ScriptedSession.open()
      try await sendMessages(count, to: session)
      return session
    }

    /// Sends `count` agent messages to the end of the transcript of
    /// `session`.
    ///
    /// - Parameters:
    ///   - count: The number of agent messages.
    ///   - session: The scripted session.
    /// - Throws: The error of the scripted session.
    static func sendMessages(_ count: Int, to session: ScriptedSession) async throws {
      let total = session.model.transcript.count + count
      for index in 0..<count {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "agent_message_chunk", messageID: "\(messagePrefix)\(index)", text: "Done."))
      }
      _ = await waitUntil { session.model.transcript.count == total }
    }

    /// Adds an agent message with ``insertedMessageID`` at the end of the
    /// transcript of `session`.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The row key of the new entry.
    /// - Throws: The error of the scripted session, or an error when the
    ///   model does not show the new entry.
    static func insertMessage(into session: ScriptedSession) async throws -> String {
      let count = session.model.transcript.count
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk(
          "agent_message_chunk", messageID: insertedMessageID, text: "One more."))
      _ = await waitUntil { session.model.transcript.count > count }
      return try #require(session.model.transcript.last?.rowKey)
    }

    /// Mounts a conversation of ``scrollEntryCount`` entries and waits until
    /// the manager sees the last entry.
    ///
    /// - Returns: The session, the manager, and the harness.
    /// - Throws: The error of the scripted session.
    static func mountScrolledConversation() async throws -> (
      ScriptedSession, ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>
    ) {
      let session = try await openSession(messages: scrollEntryCount)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(session: session.model, anchors: anchors))
      harness.pump()
      let lastKey = session.model.transcript.last?.rowKey
      await harness.pump(until: waitTimeout) { anchors.visibleIDs.last == lastKey }
      return (session, anchors, harness)
    }

    /// Scrolls the conversation to its first entry and waits until the
    /// manager is not pinned.
    ///
    /// The helper jumps as the thread minimap does with no proxy: it calls
    /// ``ScrollAnchorManager/noteJump(to:)`` before it sends the scroll. The
    /// jump cancels the scroll to the bottom that the mount can leave pending.
    /// Without the jump, that late scroll can move the list back to the
    /// bottom, and the manager then stays pinned.
    ///
    /// - Parameters:
    ///   - session: The session model of the conversation.
    ///   - anchors: The manager of the conversation.
    ///   - harness: The harness that shows the conversation.
    static func scrollToTop<Content: View>(
      session: SessionModel, anchors: ScrollAnchorManager, harness: HostedViewHarness<Content>
    ) async {
      if let firstKey = session.transcript.first?.rowKey {
        anchors.noteJump(to: firstKey)
        anchors.onScroll(.item(firstKey))
      }
      await harness.pump(until: waitTimeout) { !anchors.isPinnedToBottom }
    }

    // MARK: - Pages

    @Test func aLongTranscriptShowsTheLastPageAndALoadEarlierRow() async throws {
      let session = try await Self.openSession(messages: Self.longEntryCount)
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.pump()

      let firstPage = ConversationLayout.listValue(
        shown: ConversationLayout.defaultPageSize, count: Self.longEntryCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == firstPage }
      #expect(Self.listValue(in: harness) == firstPage)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) != nil)

      try harness.press(identifier: ConversationLayout.loadEarlierIdentifier)

      let allEntries = ConversationLayout.listValue(
        shown: Self.longEntryCount, count: Self.longEntryCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == allEntries }
      #expect(Self.listValue(in: harness) == allEntries)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    @Test func thePageSizeModifierSetsThePage() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let view = ConversationView(session: session.model).conversationPageSize(Self.smallPageSize)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      let expected = ConversationLayout.listValue(
        shown: Self.smallPageSize, count: Self.smallEntryCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == expected }
      #expect(Self.listValue(in: harness) == expected)
    }

    @Test func aShortTranscriptShowsNoLoadEarlierRow() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.pump()

      let expected = ConversationLayout.listValue(
        shown: Self.smallEntryCount, count: Self.smallEntryCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == expected }
      #expect(Self.listValue(in: harness) == expected)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    // MARK: - Empty state

    @Test func anEmptyTranscriptShowsTheDefaultEmptyState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(harness.element(identifier: ConversationLayout.listIdentifier) == nil)
    }

    @Test func theEmptyStateSlotReplacesTheDefault() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let view = ConversationView(session: session.model) {
        Text("Nothing yet")
          .accessibilityIdentifier(Self.customEmptyIdentifier)
      }
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: Self.customEmptyIdentifier)?.label == "Nothing yet")
      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) == nil)

      let insertedKey = try await Self.insertMessage(into: session)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ConversationLayout.listIdentifier) != nil
      }
      #expect(harness.element(identifier: Self.customEmptyIdentifier) == nil)
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
    }

    // MARK: - Scroll anchoring

    @Test func anInsertWhilePinnedKeepsTheLastEntryVisible() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      #expect(anchors.isPinnedToBottom)

      let insertedKey = try await Self.insertMessage(into: session)
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.last == insertedKey }

      #expect(anchors.visibleIDs.last == insertedKey)
      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    @Test func anInsertWhileUnpinnedShowsOneNewInThePill() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      await Self.scrollToTop(session: session.model, anchors: anchors, harness: harness)
      #expect(!anchors.isPinnedToBottom)

      let insertedKey = try await Self.insertMessage(into: session)
      let expected = ScrollToBottomPill.title(newItemCount: 1)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ScrollToBottomPill.identifier)?.label == expected
      }

      #expect(expected == "1 new")
      #expect(harness.element(identifier: ScrollToBottomPill.identifier)?.label == expected)
      #expect(anchors.newItemsSinceUnpinned == 1)
      #expect(anchors.visibleIDs.last != insertedKey)
    }

    @Test func aPressOnThePillPinsAndHidesIt() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      await Self.scrollToTop(session: session.model, anchors: anchors, harness: harness)
      let insertedKey = try await Self.insertMessage(into: session)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ScrollToBottomPill.identifier) != nil
      }

      try harness.press(identifier: ScrollToBottomPill.identifier)
      await harness.pump(until: Self.waitTimeout) {
        anchors.visibleIDs.last == insertedKey
          && harness.element(identifier: ScrollToBottomPill.identifier) == nil
      }

      #expect(anchors.isPinnedToBottom)
      #expect(anchors.newItemsSinceUnpinned == 0)
      #expect(anchors.visibleIDs.last == insertedKey)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    // MARK: - Banner and errors

    @Test func theShowErrorButtonMovesToTheErrorEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      session.model.appendError(code: .internalError, message: "failed", data: nil)
      let errorKey = try #require(session.model.transcript.first?.rowKey)
      try await Self.sendMessages(Self.scrollEntryCount, to: session)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(session: session.model, anchors: anchors))
      defer { harness.close() }
      harness.pump()
      let lastKey = session.model.transcript.last?.rowKey
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.last == lastKey }
      #expect(!anchors.visibleIDs.contains(errorKey))

      try await session.sendUpdate(
        SessionStateBannersHostedTests.stateUpdate(#""state": "idle", "stopReason": "refusal""#))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: StateBanner.showErrorIdentifier) != nil
      }
      try harness.press(identifier: StateBanner.showErrorIdentifier)
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.contains(errorKey) }

      #expect(anchors.visibleIDs.contains(errorKey))
      #expect(harness.element(identifier: ItemRow.identifier(for: errorKey)) != nil)
    }

    @Test func aSessionWithNoStateUpdateShowsNoBanner() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: StateBanner.bannerIdentifier) == nil)
    }
  }
#endif
