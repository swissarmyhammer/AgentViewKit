import AgentViewKit
import Foundation
import Testing

/// Tests of ``BranchSet``, ``ThreadChange/addBranch(afterUserMessage:items:)``,
/// and ``ThreadChange/selectBranch(afterUserMessage:index:)``.
@MainActor
@Suite struct BranchesTests {
  // MARK: - Fixtures

  /// The id of the first user message of ``makeThread()``.
  static let firstUser = "u1"

  /// The id of the second user message of ``makeThread()``.
  static let secondUser = "u2"

  /// Makes a thread with two turns: `u1`, `a1`, `u2`, `a2`.
  private func makeThread() -> AgentThread {
    let thread = AgentThread()
    let items: [ThreadItem] = [
      .userMessage(Message(id: Self.firstUser, blocks: [ContentBlock(text: "First")])),
      .assistantMessage(Message(id: "a1", blocks: [ContentBlock(text: "One")])),
      .userMessage(Message(id: Self.secondUser, blocks: [ContentBlock(text: "Second")])),
      .assistantMessage(Message(id: "a2", blocks: [ContentBlock(text: "Two")])),
    ]
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }

  /// An alternative answer with the id.
  private func answer(_ id: String) -> ThreadItem {
    .assistantMessage(Message(id: id, blocks: [ContentBlock(text: "Other")]))
  }

  /// The identifiers of the items of the thread, in order.
  private func ids(_ thread: AgentThread) -> [String] {
    thread.items.map(\.id)
  }

  /// The identifiers of each alternative of the branch set.
  private func alternativeIDs(_ set: BranchSet?) -> [[String]] {
    set?.alternatives.map { $0.map(\.id) } ?? []
  }

  // MARK: - Add

  @Test func aNewThreadHasNoBranches() {
    #expect(makeThread().branches.isEmpty)
  }

  @Test func addBranchKeepsTheTrailingItemsAsTheSelectedAlternative() {
    let thread = makeThread()

    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    let set = thread.branches[Self.secondUser]
    #expect(alternativeIDs(set) == [["a2"], ["b2"]])
    #expect(set?.selectedIndex == 0)
    #expect(set?.count == 2)
    #expect(ids(thread) == ["u1", "a1", "u2", "a2"])
  }

  @Test func addBranchToAKnownSetAppendsTheAlternative() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("c2")]))

    #expect(alternativeIDs(thread.branches[Self.secondUser]) == [["a2"], ["b2"], ["c2"]])
    #expect(thread.branches[Self.secondUser]?.selectedIndex == 0)
  }

  @Test func addBranchAfterAnUnknownMessageChangesNothing() {
    let thread = makeThread()

    thread.apply(.addBranch(afterUserMessage: "missing", items: [answer("b2")]))
    thread.apply(.addBranch(afterUserMessage: "a1", items: [answer("b2")]))

    #expect(thread.branches.isEmpty)
  }

  // MARK: - Select

  @Test func selectingIndexOneSwapsTheTrailingItems() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 1))

    #expect(ids(thread) == ["u1", "a1", "u2", "b2"])
    #expect(thread.branches[Self.secondUser]?.selectedIndex == 1)
    #expect(thread.position(of: "b2") == 3)
    #expect(thread.item(id: "a2") == nil)
    #expect(thread.lastItemID == "b2")
  }

  @Test func selectingBackRestoresTheItemsWithTheirChanges() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))
    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 1))
    thread.apply(.insert(answer("b3"), after: nil))

    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 0))

    #expect(ids(thread) == ["u1", "a1", "u2", "a2"])
    #expect(alternativeIDs(thread.branches[Self.secondUser]) == [["a2"], ["b2", "b3"]])
    #expect(thread.lastItemID == "a2")
  }

  @Test func theBranchOfAnEarlierMessageHoldsTheLaterTurns() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.firstUser, items: [answer("b1")]))
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.selectBranch(afterUserMessage: Self.firstUser, index: 1))

    #expect(ids(thread) == ["u1", "b1"])
    #expect(thread.branches[Self.secondUser] != nil)

    thread.apply(.selectBranch(afterUserMessage: Self.firstUser, index: 0))

    #expect(ids(thread) == ["u1", "a1", "u2", "a2"])
  }

  @Test func selectingTheSelectedIndexOrABadIndexChangesNothing() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 0))
    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 2))
    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: -1))
    thread.apply(.selectBranch(afterUserMessage: "missing", index: 1))

    #expect(ids(thread) == ["u1", "a1", "u2", "a2"])
    #expect(thread.branches[Self.secondUser]?.selectedIndex == 0)
  }

  @Test func anEmptyBranchRemovesTheTrailingItems() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: []))

    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 1))

    #expect(ids(thread) == ["u1", "a1", "u2"])
    #expect(thread.lastItemID == Self.secondUser)
  }

  @Test func aSwapKeepsTheCheckpoints() {
    let thread = makeThread()
    let checkpoint = Checkpoint(
      id: CheckpointID("c1"), turnIndex: 0, createdAt: Date(timeIntervalSince1970: 0),
      label: "First", canRestoreCode: false, canRestoreConversation: true)
    thread.apply(.setCheckpoints([checkpoint]))
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.selectBranch(afterUserMessage: Self.secondUser, index: 1))

    #expect(thread.checkpoints == [checkpoint])
  }

  @Test func clearRemovesTheBranches() {
    let thread = makeThread()
    thread.apply(.addBranch(afterUserMessage: Self.secondUser, items: [answer("b2")]))

    thread.apply(.clear)

    #expect(thread.branches.isEmpty)
  }

  // MARK: - Lookup

  @Test func theBranchUserMessageOfAnAssistantMessageIsTheUserMessageBeforeIt() {
    let thread = makeThread()
    thread.apply(.insert(answer("a3"), after: nil))

    #expect(thread.branchUserMessageID(forAssistantMessage: "a1") == Self.firstUser)
    #expect(thread.branchUserMessageID(forAssistantMessage: "a2") == Self.secondUser)
    #expect(thread.branchUserMessageID(forAssistantMessage: "a3") == nil)
    #expect(thread.branchUserMessageID(forAssistantMessage: Self.firstUser) == nil)
    #expect(thread.branchUserMessageID(forAssistantMessage: "missing") == nil)
  }

  @Test func anAssistantMessageBeforeAnyUserMessageHasNoBranchUserMessage() {
    let thread = AgentThread()
    thread.apply(.insert(answer("a0"), after: nil))

    #expect(thread.branchUserMessageID(forAssistantMessage: "a0") == nil)
  }
}
