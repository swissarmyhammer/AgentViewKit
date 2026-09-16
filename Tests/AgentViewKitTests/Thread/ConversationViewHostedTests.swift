#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import SwiftUI
  import Testing

  @Suite(.serialized) @MainActor struct ConversationViewHostedTests {
    /// The number of items in the thread of the page tests.
    static let longItemCount = 300

    /// The number of items in the thread of the scroll tests. The thread is
    /// taller than the harness window.
    static let scrollItemCount = 30

    /// The page size of the modifier test.
    static let smallPageSize = 10

    /// The number of items in the thread of the modifier test.
    static let smallItemCount = 25

    /// The longest time that a test waits for a view change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// The identifier of the item that the scroll tests insert.
    static let insertedID = "inserted-message"

    /// The identifier of the error item in the banner tests.
    static let errorID = "refusal-error"

    /// The accessibility identifier of the custom empty state.
    static let customEmptyIdentifier = "custom-empty-state"

    /// The accessibility value of the list.
    ///
    /// - Parameter harness: The harness that shows the conversation.
    /// - Returns: The value, or `nil` when the list is not in the tree.
    static func listValue<Content: View>(in harness: HostedViewHarness<Content>) -> String? {
      harness.element(identifier: ConversationLayout.listIdentifier)?.value
    }

    /// Inserts a user message with ``insertedID`` at the end of `thread`.
    ///
    /// - Parameter thread: The thread.
    static func insertMessage(into thread: AgentThread) {
      thread.apply(
        .insert(.userMessage(ThreadFixtures.message(id: insertedID, text: "One more.")), after: nil))
    }

    /// Mounts a conversation of ``scrollItemCount`` items and waits until the
    /// manager sees the last item.
    ///
    /// - Returns: The thread, the manager, and the harness.
    static func mountScrolledConversation() async -> (
      AgentThread, ScrollAnchorManager, HostedViewHarness<ConversationView<ConversationEmptyState>>
    ) {
      let thread = ThreadFixtures.sampleThread(items: scrollItemCount)
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(thread: thread, anchors: anchors))
      harness.pump()
      let lastID = thread.items.last?.id
      await harness.pump(until: waitTimeout) { anchors.visibleIDs.last == lastID }
      return (thread, anchors, harness)
    }

    /// Scrolls the conversation to its first item and waits until the manager
    /// is not pinned.
    ///
    /// - Parameters:
    ///   - thread: The thread of the conversation.
    ///   - anchors: The manager of the conversation.
    ///   - harness: The harness that shows the conversation.
    static func scrollToTop<Content: View>(
      thread: AgentThread, anchors: ScrollAnchorManager, harness: HostedViewHarness<Content>
    ) async {
      if let firstID = thread.items.first?.id {
        anchors.onScroll(.item(firstID))
      }
      await harness.pump(until: waitTimeout) { !anchors.isPinnedToBottom }
    }

    // MARK: - Pages

    @Test func aLongThreadShowsTheLastPageAndALoadEarlierRow() async throws {
      let thread = ThreadFixtures.sampleThread(items: Self.longItemCount)
      let harness = HostedViewHarness(ConversationView(thread: thread))
      defer { harness.close() }
      harness.pump()

      let firstPage = ConversationLayout.listValue(
        shown: ConversationLayout.defaultPageSize, count: Self.longItemCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == firstPage }
      #expect(Self.listValue(in: harness) == firstPage)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) != nil)

      try harness.press(identifier: ConversationLayout.loadEarlierIdentifier)

      let allItems = ConversationLayout.listValue(
        shown: Self.longItemCount, count: Self.longItemCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == allItems }
      #expect(Self.listValue(in: harness) == allItems)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    @Test func thePageSizeModifierSetsThePage() async {
      let thread = ThreadFixtures.sampleThread(items: Self.smallItemCount)
      let view = ConversationView(thread: thread).conversationPageSize(Self.smallPageSize)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      let expected = ConversationLayout.listValue(
        shown: Self.smallPageSize, count: Self.smallItemCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == expected }
      #expect(Self.listValue(in: harness) == expected)
    }

    @Test func aShortThreadShowsNoLoadEarlierRow() async {
      let thread = ThreadFixtures.sampleThread(items: Self.smallItemCount)
      let harness = HostedViewHarness(ConversationView(thread: thread))
      defer { harness.close() }
      harness.pump()

      let expected = ConversationLayout.listValue(
        shown: Self.smallItemCount, count: Self.smallItemCount)
      await harness.pump(until: Self.waitTimeout) { Self.listValue(in: harness) == expected }
      #expect(Self.listValue(in: harness) == expected)
      #expect(harness.element(identifier: ConversationLayout.loadEarlierIdentifier) == nil)
    }

    // MARK: - Empty state

    @Test func anEmptyThreadShowsTheDefaultEmptyState() {
      let harness = HostedViewHarness(ConversationView(thread: AgentThread()))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) != nil)
      #expect(harness.element(identifier: ConversationLayout.listIdentifier) == nil)
    }

    @Test func theEmptyStateSlotReplacesTheDefault() async {
      let thread = AgentThread()
      let view = ConversationView(thread: thread) {
        Text("Nothing yet")
          .accessibilityIdentifier(Self.customEmptyIdentifier)
      }
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: Self.customEmptyIdentifier)?.label == "Nothing yet")
      #expect(harness.element(identifier: ConversationLayout.emptyStateIdentifier) == nil)

      Self.insertMessage(into: thread)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ConversationLayout.listIdentifier) != nil
      }
      #expect(harness.element(identifier: Self.customEmptyIdentifier) == nil)
      #expect(harness.element(identifier: ItemRow.identifier(for: Self.insertedID)) != nil)
    }

    // MARK: - Scroll anchoring

    @Test func anInsertWhilePinnedKeepsTheLastItemVisible() async {
      let (thread, anchors, harness) = await Self.mountScrolledConversation()
      defer { harness.close() }
      #expect(anchors.isPinnedToBottom)

      Self.insertMessage(into: thread)
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.last == Self.insertedID }

      #expect(anchors.visibleIDs.last == Self.insertedID)
      #expect(anchors.isPinnedToBottom)
      #expect(harness.element(identifier: ItemRow.identifier(for: Self.insertedID)) != nil)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    @Test func anInsertWhileUnpinnedShowsOneNewInThePill() async {
      let (thread, anchors, harness) = await Self.mountScrolledConversation()
      defer { harness.close() }
      await Self.scrollToTop(thread: thread, anchors: anchors, harness: harness)
      #expect(!anchors.isPinnedToBottom)

      Self.insertMessage(into: thread)
      let expected = ScrollToBottomPill.title(newItemCount: 1)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ScrollToBottomPill.identifier)?.label == expected
      }

      #expect(expected == "1 new")
      #expect(harness.element(identifier: ScrollToBottomPill.identifier)?.label == expected)
      #expect(anchors.newItemsSinceUnpinned == 1)
      #expect(anchors.visibleIDs.last != Self.insertedID)
    }

    @Test func aPressOnThePillPinsAndHidesIt() async throws {
      let (thread, anchors, harness) = await Self.mountScrolledConversation()
      defer { harness.close() }
      await Self.scrollToTop(thread: thread, anchors: anchors, harness: harness)
      Self.insertMessage(into: thread)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ScrollToBottomPill.identifier) != nil
      }

      try harness.press(identifier: ScrollToBottomPill.identifier)
      await harness.pump(until: Self.waitTimeout) {
        anchors.visibleIDs.last == Self.insertedID
          && harness.element(identifier: ScrollToBottomPill.identifier) == nil
      }

      #expect(anchors.isPinnedToBottom)
      #expect(anchors.newItemsSinceUnpinned == 0)
      #expect(anchors.visibleIDs.last == Self.insertedID)
      #expect(harness.element(identifier: ScrollToBottomPill.identifier) == nil)
    }

    // MARK: - Banner and errors

    @Test func theShowErrorButtonMovesToTheRelatedError() async throws {
      let thread = ThreadFixtures.sampleThread(items: Self.scrollItemCount)
      let error = ThreadError(id: Self.errorID, kind: .refusal(explanation: nil))
      thread.apply(.insert(.error(error), after: thread.items.first?.id))
      thread.apply(.setState(.idle(.refusal)))
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(ConversationView(thread: thread, anchors: anchors))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: StateBanner.bannerIdentifier) != nil)
      try harness.press(identifier: StateBanner.showErrorIdentifier)
      await harness.pump(until: Self.waitTimeout) {
        anchors.visibleIDs.contains(Self.errorID)
      }

      #expect(anchors.visibleIDs.contains(Self.errorID))
      #expect(harness.element(identifier: ItemRow.identifier(for: Self.errorID)) != nil)
    }

    @Test func anIdleThreadShowsNoBanner() {
      let thread = ThreadFixtures.sampleThread(items: Self.smallItemCount)
      let harness = HostedViewHarness(ConversationView(thread: thread))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: StateBanner.bannerIdentifier) == nil)
    }

    @Test func theHostErrorActionsReachTheErrorCards() async {
      let thread = AgentThread()
      thread.apply(.insert(.error(ThreadError(id: Self.errorID, kind: .timeout)), after: nil))
      let view = ConversationView(thread: thread)
        .errorActions(ErrorActions(retry: { _ in }))
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      let retry = ErrorView.actionIdentifier(for: .retry)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: retry) != nil }
      #expect(harness.element(identifier: retry) != nil)
    }
  }
#endif
