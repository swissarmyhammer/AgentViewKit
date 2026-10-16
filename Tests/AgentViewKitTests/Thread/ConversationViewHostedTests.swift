#if DEBUG
  @testable import AgentViewKit
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
    /// A test that calls this helper must not check the state that the
    /// report writes, such as ``ScrollAnchorManager/visibleIDs``. That check
    /// reads back the input of the test, and it proves nothing about the
    /// view. A test checks only the reaction to the report or to an action:
    /// the pill, the count of new entries, the pin state, the anchor that an
    /// action sets, and the frames of the rows.
    ///
    /// The action of `onScrollTargetVisibilityChange` is a closure in the
    /// body of `ConversationView`, so a test cannot get it.
    /// `ScrollAnchorManagerTests` covers what the manager does with a report.
    /// ``aScrollUpMakesTheListReportItsRowsAndShowThePill()`` and
    /// ``aPressOnThePillScrollsTheListToTheLastRow()`` give no report: they
    /// check that the actions of the list give the reports to
    /// ``ScrollAnchorManager``.
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

    /// Makes a new manager, and mounts the conversation of `session` with that
    /// manager. The helper gives no visibility report to the manager.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The manager and the harness.
    static func makeManagedConversation(
      of session: ScriptedSession
    ) -> (ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>) {
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(session: session.model, anchors: anchors))
      return (anchors, harness)
    }

    /// Mounts the conversation of `session` with a new manager
    /// (``makeManagedConversation(of:)``), and gives the manager the report of
    /// the rows at the bottom (``reportRows(at:of:to:)``).
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The manager and the harness.
    static func mountConversation(
      of session: ScriptedSession
    ) -> (ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>) {
      let (anchors, harness) = makeManagedConversation(of: session)
      reportRows(at: .bottom, of: session.model, to: anchors)
      return (anchors, harness)
    }

    /// Scrolls the conversation to its first entry, lays it out one time,
    /// and gives the manager the report of the rows at the top
    /// (``reportRows(at:of:to:)``). The report unpins the manager.
    ///
    /// The helper scrolls with ``jump(to:anchors:harness:)``. Without the
    /// jump, the late scroll to the bottom that the mount can leave pending
    /// can move the list back to the bottom.
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
      jump(to: firstKey, anchors: anchors, harness: harness)
      reportRows(at: .top, of: session, to: anchors)
    }

    /// Scrolls the conversation to the row with `key`, and lays it out one
    /// time. The helper gives no visibility report to the manager.
    ///
    /// The helper jumps as the thread minimap does with no proxy: it calls
    /// ``ScrollAnchorManager/noteJump(to:)`` before it sends the scroll. The
    /// jump cancels the scroll to the bottom that the mount can leave pending.
    /// The jump does not change the pin state of the manager.
    ///
    /// - Parameters:
    ///   - key: The row key of the entry to scroll to.
    ///   - anchors: The manager of the conversation.
    ///   - harness: The harness that shows the conversation.
    static func jump<Content: View>(
      to key: String, anchors: ScrollAnchorManager, harness: HostedViewHarness<Content>
    ) {
      anchors.noteJump(to: key)
      anchors.onScroll(.item(key))
      harness.hostingView.layoutSubtreeIfNeeded()
    }

    /// Records each scroll target that `anchors` sends, and then gives the
    /// target to the scroll closure that the conversation set.
    ///
    /// Call this helper after the first layout of the conversation: the
    /// conversation sets ``ScrollAnchorManager/onScroll`` when it appears.
    ///
    /// - Parameter anchors: The manager of the conversation.
    /// - Returns: The recorder of the scroll targets.
    static func recordScrollTargets(of anchors: ScrollAnchorManager) -> ReportRecorder<ScrollAnchorTarget> {
      let targets = ReportRecorder<ScrollAnchorTarget>()
      let viewScroll = anchors.onScroll
      anchors.onScroll = { target in
        targets.report(target)
        viewScroll(target)
      }
      return targets
    }

    /// Mounts the conversation of `session` with a new manager
    /// (``makeManagedConversation(of:)``), records the scroll targets of the
    /// manager, and scrolls up to the row with `firstKey`. The helper gives no
    /// visibility report to the manager: only the actions of the list tell the
    /// manager which rows are in view.
    ///
    /// - Parameters:
    ///   - session: The scripted session, with more entries than the harness
    ///     window shows.
    ///   - firstKey: The row key of the first entry of the transcript.
    /// - Returns: The manager, the recorder of its scroll targets, and the
    ///   harness, after the scroll and one ``HostedViewHarness/render()`` pass.
    static func mountAndScrollUp(
      _ session: ScriptedSession, to firstKey: String
    ) -> (
      ScrollAnchorManager, ReportRecorder<ScrollAnchorTarget>,
      HostedViewHarness<ConversationView<ConversationEmptyState>>
    ) {
      let (anchors, harness) = makeManagedConversation(of: session)
      harness.render()
      let targets = recordScrollTargets(of: anchors)
      jump(to: firstKey, anchors: anchors, harness: harness)
      harness.render()
      return (anchors, targets, harness)
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
      harness.render()

      let firstPage = ConversationLayout.listValue(
        shown: ConversationLayout.defaultPageSize, count: Self.longEntryCount)
      #expect(Self.listValue(in: harness) == firstPage)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) != nil)

      try harness.press(identifier: ConversationLayout.loadEarlierIdentifier)

      let allEntries = ConversationLayout.listValue(
        shown: Self.longEntryCount, count: Self.longEntryCount)
      #expect(Self.listValue(in: harness) == allEntries)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    @Test func thePageSizeModifierSetsThePage() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let view = ConversationView(session: session.model).conversationPageSize(Self.smallPageSize)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.render()

      let expected = ConversationLayout.listValue(
        shown: Self.smallPageSize, count: Self.smallEntryCount)
      #expect(Self.listValue(in: harness) == expected)
    }

    @Test func aShortTranscriptShowsNoLoadEarlierRow() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.render()

      let expected = ConversationLayout.listValue(
        shown: Self.smallEntryCount, count: Self.smallEntryCount)
      #expect(Self.listValue(in: harness) == expected)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    // MARK: - Empty state

    @Test func anEmptyTranscriptShowsTheDefaultEmptyState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.render()

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
      harness.render()

      #expect(harness.element(identifier: Self.customEmptyIdentifier)?.label == "Nothing yet")
      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) == nil)

      let insertedKey = try await Self.insertMessage(into: session)
      harness.render()
      #expect(harness.element(identifier: ConversationLayout.listIdentifier) != nil)
      #expect(harness.element(identifier: Self.customEmptyIdentifier) == nil)
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
    }

    // MARK: - Scroll anchoring

    /// The reaction of the view to a given report of the rows at the bottom,
    /// around an insert: the manager is pinned, the list has the row of the
    /// new entry, and the view shows no pill.
    ///
    /// The pin state comes from the manager: a report of the bottom rows pins
    /// it only when the last row of the report is the last item that the
    /// view told it. After the model has the new entry, one layout pass runs
    /// the change action of the list, which tells the manager about the
    /// append. Until the list reports the new row, the manager can be
    /// unpinned, and that pass can show the pill. Then the test gives the
    /// manager the report of the rows at the bottom, and one more layout pass
    /// shows the reaction of the view to the state of the manager.
    ///
    /// The test does not check the rows in view that the manager keeps: the
    /// given report writes them. Gap: the test gives the visibility reports
    /// to the manager itself (``reportRows(at:of:to:)``).
    /// ``aScrollUpMakesTheListReportItsRowsAndShowThePill()`` checks that the
    /// list sends them.
    @Test func anInsertAfterAGivenBottomReportShowsTheNewRowWithNoPill() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      #expect(anchors.isPinnedToBottom)

      let insertedKey = try await Self.insertMessage(into: session)
      harness.hostingView.layoutSubtreeIfNeeded()
      Self.reportRows(at: .bottom, of: session.model, to: anchors)
      harness.hostingView.layoutSubtreeIfNeeded()

      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ItemRow.identifier(for: insertedKey)) != nil)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    /// The reaction of the view to an insert after a given report of the
    /// rows at the top: the view tells the manager about the append, the
    /// count of the manager is one, the pill shows "1 new", and the list
    /// does not move to the new row.
    ///
    /// The report of the rows at the top unpins the manager. After the model
    /// has the new entry, the first layout pass runs the change action of the
    /// list, which tells the manager about the append, and the second layout
    /// pass shows the count in the pill. The test reads the frame of the new
    /// row to know that the list did not scroll to it.
    ///
    /// The test does not check the rows in view that the manager keeps: the
    /// given report writes them. Gap: the test gives the visibility reports
    /// to the manager itself (``reportRows(at:of:to:)``).
    /// ``aScrollUpMakesTheListReportItsRowsAndShowThePill()`` checks that the
    /// list sends them.
    @Test func anInsertAfterAGivenTopReportShowsOneNewInThePill() async throws {
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
      #expect(!Self.showsRow(insertedKey, in: harness))
    }

    /// The reaction of the view to a press on the pill: the count of new
    /// entries of the manager goes to zero. Then the reaction of the view to
    /// a given report of the rows at the bottom: the manager is pinned, and
    /// the pill goes away.
    ///
    /// The test checks the count before it gives a report, because a report
    /// of the bottom rows also pins the manager and sets the count to zero.
    /// Only the press can set the count to zero before that report. The test
    /// does not check the pin state right after the press: a geometry change
    /// of the list can send the old rows in view to the manager again, and
    /// that unpins it until the list reports its new rows.
    ///
    /// The test does not check that the list scrolls to the new entry: in
    /// the off-screen harness window, the scroll to the bottom that the press
    /// requests does not move the list in the render pass of the press and
    /// one more layout pass. ``aPressOnThePillScrollsTheListToTheLastRow()``
    /// waits for that scroll. The test does not check the rows in view that
    /// the manager keeps: the given report writes them.
    ///
    /// Gap: the test gives the visibility reports to the manager itself
    /// (``reportRows(at:of:to:)``).
    /// ``aScrollUpMakesTheListReportItsRowsAndShowThePill()`` checks that the
    /// list sends them.
    @Test func aPressOnThePillSetsTheNewEntryCountToZero() async throws {
      let (session, anchors, harness) = try await Self.mountScrolledConversation()
      defer { session.close() }
      defer { harness.close() }
      try Self.scrollToTop(session: session.model, anchors: anchors, harness: harness)
      _ = try await Self.insertMessage(into: session)
      Self.layOutTheManagerChange(in: harness)
      #expect(anchors.newItemsSinceUnpinned == 1)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) != nil)

      try harness.press(identifier: ScrollToBottomPill.identifier)

      #expect(anchors.newItemsSinceUnpinned == 0)

      Self.reportRows(at: .bottom, of: session.model, to: anchors)
      harness.hostingView.layoutSubtreeIfNeeded()

      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    /// The link between the list and the manager, with no given report: a
    /// scroll up makes the list report its rows in view to the manager, the
    /// report unpins the manager, and the view shows the pill.
    ///
    /// The test gives no visibility report to the manager. The jump sets the
    /// rows in view of the manager to the first row only, and it does not
    /// change the pin state. Thus only the actions of the list can write more
    /// rows and unpin the manager. In the harness window, SwiftUI calls the
    /// `onScrollTargetVisibilityChange` action in the layout pass that moves
    /// the list, so the test checks at once after that pass, with no wait.
    @Test func aScrollUpMakesTheListReportItsRowsAndShowThePill() async throws {
      let session = try await Self.openSession(messages: Self.scrollEntryCount)
      defer { session.close() }
      let firstKey = try #require(session.model.transcript.first?.rowKey)
      let (anchors, _, harness) = Self.mountAndScrollUp(session, to: firstKey)
      defer { harness.close() }

      #expect(Self.showsRow(firstKey, in: harness))
      #expect(anchors.visibleIDs.first == firstKey)
      #expect(anchors.visibleIDs.count > 1)
      #expect(!anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) != nil)
    }

    /// The link between the pill, the manager and the list, with no given
    /// report: a press on the pill pins the manager, the manager sends the
    /// scroll to the bottom, the list moves to the last row, and the pill
    /// goes away.
    ///
    /// The manager sends the scroll on the next main-actor tick after the
    /// press. The press always requests that scroll, and no jump cancels it,
    /// so the test waits for the event that the recorder gets the bottom
    /// target. Then one ``HostedViewHarness/render()`` pass moves the list,
    /// and the list reports its new rows to the manager in that pass.
    @Test func aPressOnThePillScrollsTheListToTheLastRow() async throws {
      let session = try await Self.openSession(messages: Self.scrollEntryCount)
      defer { session.close() }
      let model = session.model
      let firstKey = try #require(model.transcript.first?.rowKey)
      let lastKey = try #require(model.transcript.last?.rowKey)
      let (anchors, targets, harness) = Self.mountAndScrollUp(session, to: firstKey)
      defer { harness.close() }
      try #require(Self.showsRow(firstKey, in: harness))
      try #require(!Self.showsRow(lastKey, in: harness))
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) != nil)

      try harness.press(identifier: ScrollToBottomPill.identifier)
      try #require(anchors.isPinnedToBottom)
      try #require(harness.element(identifier: ScrollToBottomPill.identifier) == nil)

      await ObservationWait.until { targets.values.last == .bottom }
      harness.render()

      #expect(Self.showsRow(lastKey, in: harness))
      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    // MARK: - Banner and errors

    /// The reaction of the view to a press on the Show Error button: the list
    /// scrolls to the error entry, and the manager keeps the error entry as
    /// its anchor.
    ///
    /// After the model has the new state, one layout pass shows the button.
    /// After the press, one layout pass moves the list, and the test reads
    /// the frame of the error row. The press sets the anchor; no report that
    /// the test gives sets it. The test gives no report after the press, and
    /// it does not check the rows in view that the manager keeps.
    ///
    /// Gap: the mount gives the report of the rows at the bottom to the
    /// manager itself (``reportRows(at:of:to:)``).
    /// ``aScrollUpMakesTheListReportItsRowsAndShowThePill()`` checks that the
    /// list sends the reports.
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
      #expect(anchors.anchorID == errorKey)
    }

    @Test func aSessionWithNoStateUpdateShowsNoBanner() async throws {
      let session = try await Self.openSession(messages: Self.smallEntryCount)
      defer { session.close() }
      let harness = HostedViewHarness(ConversationView(session: session.model))
      defer { harness.close() }
      harness.render()

      #expect(harness.element(identifier: StateBanner.bannerIdentifier) == nil)
    }
  }
#endif
