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

    /// The longest time that a test waits for a view change, in seconds. A
    /// wait ends when its condition is true, so the limit costs no time on a
    /// pass.
    static let waitTimeout: TimeInterval = 5

    /// The message id of the agent message that the scroll tests add.
    static let insertedMessageID = "inserted-message"

    /// The start of the message id of each agent message that a test sends.
    static let messagePrefix = "conversation-m"

    /// The accessibility identifier of the custom empty state.
    static let customEmptyIdentifier = "custom-empty-state"

    /// The number of rows in each visibility report that a scroll test gives
    /// to the manager. The harness window shows more rows than this count,
    /// so each report holds only rows that are in view.
    static let reportedRowCount = 3

    /// An edge of the list in a visibility report that a test gives to the
    /// manager.
    enum ListEdge {
      /// The first rows of the transcript are in view.
      case top

      /// The last rows of the transcript are in view, and the end of the
      /// list is at the bottom edge of the viewport.
      case bottom
    }

    /// Gives `anchors` the visibility report that the list of a
    /// ``ConversationView`` sends when it shows the rows at `edge`.
    ///
    /// The hosted tests do not wait for the report of SwiftUI. SwiftUI sends
    /// it from `onScrollTargetVisibilityChange` on a later update, and for the
    /// off-screen harness window it can send no report. A wait for it holds
    /// `HostedTestLock` and stops all hosted tests. Thus each scroll test
    /// gives the reports to the manager itself, in a fixed order. A report
    /// holds the row keys in transcript order, and a list that is not at the
    /// bottom reports the distance `.greatestFiniteMagnitude`, as
    /// `ConversationView` does.
    ///
    /// Gap: no hosted test proves that SwiftUI calls the
    /// `onScrollTargetVisibilityChange` action of `ConversationView`, or that
    /// the action gives the report to ``ScrollAnchorManager``. The action is
    /// a closure in the body of the view, so a test cannot get it.
    /// `ScrollAnchorManagerTests` covers what the manager does with a report.
    /// Task ^2pbwh3e adds the check of the link on a real screen.
    ///
    /// - Parameters:
    ///   - edge: The edge of the list that is in view.
    ///   - model: The session model of the conversation.
    ///   - anchors: The manager of the conversation.
    static func reportRows(at edge: ListEdge, of model: SessionModel, to anchors: ScrollAnchorManager) {
      let keys = model.transcript.map(\.rowKey)
      switch edge {
      case .top:
        anchors.noteVisible(ids: Array(keys.prefix(reportedRowCount)), distanceFromBottom: .greatestFiniteMagnitude)
      case .bottom:
        anchors.noteVisible(ids: Array(keys.suffix(reportedRowCount)), distanceFromBottom: 0)
      }
    }

    /// The accessibility value of the list.
    ///
    /// - Parameter harness: The harness that shows the conversation.
    /// - Returns: The value, or `nil` when the list is not in the tree.
    static func listValue<Content: View>(in harness: HostedViewHarness<Content>) -> String? {
      harness.element(identifier: ConversationLayout.listIdentifier)?.value
    }

    /// Whether the row of the entry with `key` is in the visible part of the
    /// list.
    ///
    /// The check compares the accessibility frames of the row and the list,
    /// which show the layout now. It does not read
    /// ``ScrollAnchorManager/visibleIDs``: a jump sets `visibleIDs` to the
    /// item of the jump at once, before the list moves. Also, after a long
    /// jump, the lazy stack can lay out a row first at an old position and
    /// then move it. SwiftUI reports the rows in view for the first layout,
    /// and it does not report again when only the rows move.
    ///
    /// - Parameters:
    ///   - key: The row key of the entry.
    ///   - harness: The harness that shows the conversation.
    /// - Returns: `true` when part of the row is in the list frame.
    static func showsRow<Content: View>(_ key: String, in harness: HostedViewHarness<Content>) -> Bool {
      let list = harness.frame(identifier: ConversationLayout.listIdentifier)
      let row = harness.frame(identifier: ItemRow.identifier(for: key))
      return if let list, let row { !list.intersection(row).isEmpty } else { false }
    }

    /// Opens a scripted session whose transcript has `count` agent messages.
    ///
    /// When a send fails, the helper closes the session before it throws.
    ///
    /// - Parameter count: The number of agent messages.
    /// - Returns: The session, after the model shows each message.
    /// - Throws: The error of the scripted session.
    static func openSession(messages count: Int) async throws -> ScriptedSession {
      let session = try await ScriptedSession.open()
      do {
        try await sendMessages(count, to: session)
      } catch {
        session.close()
        throw error
      }
      return session
    }

    /// Sends `count` agent messages to the end of the transcript of
    /// `session`.
    ///
    /// The helper waits for the event that the model holds each message.
    ///
    /// - Parameters:
    ///   - count: The number of agent messages.
    ///   - session: The scripted session.
    /// - Throws: The error of the scripted session.
    static func sendMessages(_ count: Int, to session: ScriptedSession) async throws {
      let model = session.model
      let total = model.transcript.count + count
      for index in 0..<count {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "agent_message_chunk", messageID: "\(messagePrefix)\(index)", text: "Done."))
      }
      await ObservationWait.until { model.transcript.count == total }
    }

    /// Adds an agent message with ``insertedMessageID`` at the end of the
    /// transcript of `session`.
    ///
    /// The helper waits for the event that the model holds the new entry.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The row key of the new entry.
    /// - Throws: The error of the scripted session.
    static func insertMessage(into session: ScriptedSession) async throws -> String {
      let model = session.model
      let count = model.transcript.count
      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk(
          "agent_message_chunk", messageID: insertedMessageID, text: "One more."))
      await ObservationWait.until { model.transcript.count > count }
      return try #require(model.transcript.last?.rowKey)
    }

    /// Mounts a conversation of ``scrollEntryCount`` entries, and gives the
    /// manager the report of the rows at the bottom
    /// (``reportRows(at:of:to:)``).
    ///
    /// The harness lays out the view one time when it mounts it. That pass
    /// shows the end of the list, and the list tells the manager its last
    /// entry.
    ///
    /// - Returns: The session, the manager, and the harness.
    /// - Throws: The error of the scripted session.
    static func mountScrolledConversation() async throws -> (
      ScriptedSession, ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>
    ) {
      let session = try await openSession(messages: scrollEntryCount)
      let (anchors, harness) = mountConversation(of: session)
      return (session, anchors, harness)
    }

    /// Mounts the conversation of `session` with a new manager, and gives the
    /// manager the report of the rows at the bottom
    /// (``reportRows(at:of:to:)``).
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The manager and the harness.
    static func mountConversation(
      of session: ScriptedSession
    ) -> (ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>) {
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(session: session.model, anchors: anchors))
      reportRows(at: .bottom, of: session.model, to: anchors)
      return (anchors, harness)
    }

    /// Scrolls the conversation to its first entry, lays it out one time,
    /// and gives the manager the report of the rows at the top
    /// (``reportRows(at:of:to:)``). The report unpins the manager.
    ///
    /// The helper jumps as the thread minimap does with no proxy: it calls
    /// ``ScrollAnchorManager/noteJump(to:)`` before it sends the scroll. The
    /// jump cancels the scroll to the bottom that the mount can leave pending.
    /// Without the jump, that late scroll can move the list back to the
    /// bottom.
    ///
    /// - Parameters:
    ///   - session: The session model of the conversation.
    ///   - anchors: The manager of the conversation.
    ///   - harness: The harness that shows the conversation.
    /// - Throws: An issue when the transcript has no entry.
    static func scrollToTop<Content: View>(
      session: SessionModel, anchors: ScrollAnchorManager, harness: HostedViewHarness<Content>
    ) throws {
      let firstKey = try #require(session.transcript.first?.rowKey)
      anchors.noteJump(to: firstKey)
      anchors.onScroll(.item(firstKey))
      harness.hostingView.layoutSubtreeIfNeeded()
      reportRows(at: .top, of: session, to: anchors)
    }

    /// Lays out the views of `harness` two times: the first pass runs the
    /// change actions of the conversation, which tell the manager about the
    /// change, and the second pass shows the new state of the manager, such
    /// as the scroll-to-bottom pill.
    ///
    /// - Parameter harness: The harness that shows the conversation.
    static func layOutTheManagerChange<Content: View>(in harness: HostedViewHarness<Content>) {
      harness.hostingView.layoutSubtreeIfNeeded()
      harness.hostingView.layoutSubtreeIfNeeded()
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

    /// An insert while the list is at the bottom keeps the manager pinned,
    /// shows the new row, and shows no pill.
    ///
    /// After the model has the new entry, one layout pass runs the change
    /// action of the list, which tells the manager about the append. Until
    /// the list reports the new row, the manager can be unpinned, and that
    /// pass can show the pill. Then the test gives the manager the report of
    /// the rows at the bottom, and one more layout pass shows the state of
    /// the manager after that report.
    ///
    /// Gap: the test gives the visibility reports to the manager itself
    /// (``reportRows(at:of:to:)``). No hosted test proves that SwiftUI sends
    /// them. Task ^2pbwh3e checks that on a real screen.
    @Test func anInsertWhilePinnedKeepsTheLastEntryVisible() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      #expect(anchors.isPinnedToBottom)

      let insertedKey = try await Self.insertMessage(into: session)
      harness.hostingView.layoutSubtreeIfNeeded()
      Self.reportRows(at: .bottom, of: session.model, to: anchors)
      harness.hostingView.layoutSubtreeIfNeeded()

      #expect(anchors.visibleIDs.last == insertedKey)
      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    /// An insert while the list shows its first rows adds one to the count
    /// of the manager, and the pill shows "1 new".
    ///
    /// The report of the rows at the top unpins the manager. After the model
    /// has the new entry, the first layout pass tells the manager about the
    /// append, and the second layout pass shows the count in the pill.
    ///
    /// Gap: the test gives the visibility reports to the manager itself
    /// (``reportRows(at:of:to:)``). No hosted test proves that SwiftUI sends
    /// them. Task ^2pbwh3e checks that on a real screen.
    @Test func anInsertWhileUnpinnedShowsOneNewInThePill() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      try Self.scrollToTop(session: session.model, anchors: anchors, harness: harness)
      #expect(!anchors.isPinnedToBottom)

      let insertedKey = try await Self.insertMessage(into: session)
      Self.layOutTheManagerChange(in: harness)

      let expected = ScrollToBottomPill.title(newItemCount: 1)
      #expect(expected == "1 new")
      #expect(anchors.newItemsSinceUnpinned == 1)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier)?.label == expected)
      #expect(anchors.visibleIDs.last != insertedKey)
    }

    /// A press on the pill pins the manager, sets the count to zero, and
    /// hides the pill.
    ///
    /// The press pins the manager at once. Then the test gives the manager
    /// the report of the rows at the bottom, which the list sends after the
    /// scroll to the end, and lays out the views one time.
    ///
    /// Gap: the test gives the visibility reports to the manager itself
    /// (``reportRows(at:of:to:)``). No hosted test proves that SwiftUI sends
    /// them. Task ^2pbwh3e checks that on a real screen.
    @Test func aPressOnThePillPinsAndHidesIt() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      try Self.scrollToTop(session: session.model, anchors: anchors, harness: harness)
      let insertedKey = try await Self.insertMessage(into: session)
      Self.layOutTheManagerChange(in: harness)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) != nil)

      try harness.press(identifier: ScrollToBottomPill.identifier)
      Self.reportRows(at: .bottom, of: session.model, to: anchors)
      harness.hostingView.layoutSubtreeIfNeeded()

      #expect(anchors.isPinnedToBottom)
      #expect(anchors.newItemsSinceUnpinned == 0)
      #expect(anchors.visibleIDs.last == insertedKey)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    // MARK: - Banner and errors

    /// The Show Error button scrolls the list to the error entry, and the
    /// manager keeps the error row in its rows in view.
    ///
    /// After the model has the new state, one layout pass shows the button.
    /// After the press, one layout pass moves the list, and the test reads
    /// the frame of the error row. Then the test gives the manager the
    /// report of the rows at the top, which the list sends after the jump.
    ///
    /// Gap: the test gives the visibility reports to the manager itself
    /// (``reportRows(at:of:to:)``). No hosted test proves that SwiftUI sends
    /// them. Task ^2pbwh3e checks that on a real screen.
    @Test func theShowErrorButtonMovesToTheErrorEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      model.appendError(code: .internalError, message: "failed", data: nil)
      let errorKey = try #require(model.transcript.first?.rowKey)
      try await Self.sendMessages(Self.scrollEntryCount, to: session)
      let (anchors, harness) = Self.mountConversation(of: session)
      defer { harness.close() }
      #expect(!Self.showsRow(errorKey, in: harness))

      let stateBefore = model.agentState
      try await session.sendUpdate(
        SessionStateBannersHostedTests.stateUpdate(#""state": "idle", "stopReason": "refusal""#))
      await ObservationWait.until { model.agentState != stateBefore }
      harness.hostingView.layoutSubtreeIfNeeded()
      try harness.press(identifier: StateBanner.showErrorIdentifier)
      harness.hostingView.layoutSubtreeIfNeeded()

      #expect(Self.showsRow(errorKey, in: harness))
      #expect(harness.element(identifier: ItemRow.identifier(for: errorKey)) != nil)
      Self.reportRows(at: .top, of: model, to: anchors)
      // A Load Earlier press now keeps the error row as the anchor.
      #expect(anchors.visibleIDs.first == errorKey)
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
