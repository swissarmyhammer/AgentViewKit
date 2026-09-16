import AgentViewKit
import Testing

@Suite @MainActor struct ExpandedBlocksStoreTests {
  /// A tool call item. The policy in these tests expands it.
  private static let toolCall = ThreadItem.toolCall(ToolCallRecord(id: "tool-1", title: "Read file"))

  /// A reasoning item. The policy in these tests does not expand it.
  private static let reasoning = ThreadItem.reasoning(Reasoning(id: "reasoning-1", segments: ["Think"]))

  /// Makes a store whose policy expands each tool call and no other item.
  private static func makeStoreThatExpandsToolCalls() -> ExpandedBlocksStore {
    ExpandedBlocksStore { item in
      if case .toolCall = item { return true }
      return false
    }
  }

  // MARK: - Toggle

  @Test func toggleFlipsOnlyTheGivenId() {
    let store = ExpandedBlocksStore()

    store.toggle("a")
    #expect(store.isExpanded("a"))
    #expect(!store.isExpanded("b"))

    store.toggle("a")
    #expect(!store.isExpanded("a"))
    #expect(!store.isExpanded("b"))
  }

  @Test func expandAndCollapseSetTheGivenIdOnly() {
    let store = ExpandedBlocksStore()
    store.expand("b")

    store.expand("a")
    store.expand("a")
    #expect(store.isExpanded("a"))

    store.collapse("a")
    store.collapse("a")
    #expect(!store.isExpanded("a"))
    #expect(store.isExpanded("b"))
  }

  @Test func anUnknownIdIsCollapsed() {
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded("never-seen"))
  }

  @Test func aToggleInvalidatesOnlyTheReadersOfThatId() {
    let store = ExpandedBlocksStore()
    let readerOfA = ChangeFlag.observing { _ = store.isExpanded("a") }
    let readerOfB = ChangeFlag.observing { _ = store.isExpanded("b") }

    store.toggle("a")

    #expect(readerOfA.value)
    #expect(!readerOfB.value)
  }

  // MARK: - Default policy

  @Test func theDefaultPolicyExpandsNoItem() {
    let store = ExpandedBlocksStore()

    #expect(!store.isExpanded(Self.toolCall))
    #expect(!store.isExpanded(Self.reasoning))
  }

  @Test func thePolicyDecidesAnItemWithNoDecision() {
    let store = Self.makeStoreThatExpandsToolCalls()

    #expect(store.isExpanded(Self.toolCall))
    #expect(!store.isExpanded(Self.reasoning))
  }

  @Test func aDecisionWinsOverThePolicy() {
    let store = Self.makeStoreThatExpandsToolCalls()

    store.collapse(Self.toolCall.id)
    store.expand(Self.reasoning.id)

    #expect(!store.isExpanded(Self.toolCall))
    #expect(store.isExpanded(Self.reasoning))
  }

  @Test func aDecisionEqualToTheCollapsedValueInvalidatesAPolicyReader() {
    let store = Self.makeStoreThatExpandsToolCalls()
    let reader = ChangeFlag.observing { _ = store.isExpanded(Self.toolCall) }

    store.collapse(Self.toolCall.id)

    #expect(reader.value)
    #expect(!store.isExpanded(Self.toolCall))
  }

  @Test func seedRecordsThePolicyValueForTheId() {
    let store = Self.makeStoreThatExpandsToolCalls()

    store.seed(Self.toolCall)
    store.seed(Self.reasoning)

    #expect(store.isExpanded(Self.toolCall.id))
    #expect(!store.isExpanded(Self.reasoning.id))
  }

  @Test func seedDoesNotReplaceADecision() {
    let store = Self.makeStoreThatExpandsToolCalls()
    store.collapse(Self.toolCall.id)

    store.seed(Self.toolCall)

    #expect(!store.isExpanded(Self.toolCall.id))
  }

  @Test func toggleAfterSeedFlipsThePolicyValue() {
    let store = Self.makeStoreThatExpandsToolCalls()
    store.seed(Self.toolCall)

    store.toggle(Self.toolCall.id)

    #expect(!store.isExpanded(Self.toolCall))
  }
}
