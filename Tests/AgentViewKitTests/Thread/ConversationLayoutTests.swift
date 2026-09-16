import AgentViewKit
import Testing

@Suite @MainActor struct ConversationLayoutTests {
  /// The page size of these tests.
  static let pageSize = 200

  /// The number of items of these tests.
  static let itemCount = 300

  // MARK: - Shown count

  @Test func onePageShowsThePageSize() {
    #expect(
      ConversationLayout.shownCount(count: Self.itemCount, pageSize: Self.pageSize, pageCount: 1)
        == Self.pageSize)
  }

  @Test func twoPagesShowEachItem() {
    #expect(
      ConversationLayout.shownCount(count: Self.itemCount, pageSize: Self.pageSize, pageCount: 2)
        == Self.itemCount)
  }

  @Test func aShortThreadShowsEachItem() {
    #expect(ConversationLayout.shownCount(count: 5, pageSize: Self.pageSize, pageCount: 1) == 5)
  }

  @Test func aPageSizeBelowOneCountsAsOne() {
    #expect(ConversationLayout.shownCount(count: Self.itemCount, pageSize: 0, pageCount: 3) == 3)
    #expect(ConversationLayout.shownCount(count: Self.itemCount, pageSize: -4, pageCount: 0) == 1)
  }

  @Test func anOverflowShowsEachItem() {
    #expect(
      ConversationLayout.shownCount(count: Self.itemCount, pageSize: .max, pageCount: 2)
        == Self.itemCount)
  }

  // MARK: - Page count

  @Test func theLastItemNeedsOnePage() {
    #expect(
      ConversationLayout.pageCount(
        toShow: Self.itemCount - 1, count: Self.itemCount, pageSize: Self.pageSize) == 1)
  }

  @Test func theFirstItemOfTheLastPageNeedsOnePage() {
    let firstOfLastPage = Self.itemCount - Self.pageSize
    #expect(
      ConversationLayout.pageCount(
        toShow: firstOfLastPage, count: Self.itemCount, pageSize: Self.pageSize) == 1)
    #expect(
      ConversationLayout.pageCount(
        toShow: firstOfLastPage - 1, count: Self.itemCount, pageSize: Self.pageSize) == 2)
  }

  @Test func theFirstItemNeedsEachPage() {
    #expect(
      ConversationLayout.pageCount(toShow: 0, count: Self.itemCount, pageSize: Self.pageSize) == 2)
  }

  // MARK: - List value

  @Test func theListValueTellsTheShownAndTotalCounts() {
    #expect(ConversationLayout.listValue(shown: 200, count: 300) == "200 of 300 items")
  }

  // MARK: - Related error

  /// Makes items with one error of each kind in `kinds`, in order. The id of
  /// each error is `error-` and its position.
  static func errorItems(_ kinds: [ThreadError.Kind]) -> [ThreadItem] {
    kinds.enumerated().map { position, kind in
      .error(ThreadError(id: "error-\(position)", kind: kind))
    }
  }

  @Test func aRefusalFindsTheNewestRefusalOrGuardrailError() {
    let items = Self.errorItems([
      .refusal(explanation: nil), .guardrailViolation(explanation: nil), .timeout,
    ])

    #expect(ConversationLayout.relatedErrorID(in: items, state: .idle(.refusal)) == "error-1")
  }

  @Test func maxTokensFindsTheContextSizeError() {
    let items = Self.errorItems([
      .contextSizeExceeded(contextSize: 10, tokenCount: 20), .refusal(explanation: nil),
    ])

    #expect(ConversationLayout.relatedErrorID(in: items, state: .idle(.maxTokens)) == "error-0")
  }

  @Test func aStateWithNoRelatedKindFindsNoError() {
    let items = Self.errorItems([.refusal(explanation: nil), .timeout])

    #expect(ConversationLayout.relatedErrorID(in: items, state: .idle(.maxTurnRequests)) == nil)
    #expect(ConversationLayout.relatedErrorID(in: items, state: .requiresAction) == nil)
    #expect(ConversationLayout.relatedErrorID(in: items, state: .running) == nil)
  }

  @Test func noMatchingErrorFindsNothing() {
    let items = Self.errorItems([.timeout])

    #expect(ConversationLayout.relatedErrorID(in: items, state: .idle(.refusal)) == nil)
  }
}
