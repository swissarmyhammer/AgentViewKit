import AgentViewKit
import Testing

/// Tests of ``ThreadChange/compact(marker:removing:)``.
@MainActor
@Suite struct CompactionChangeTests {
  // MARK: - Fixtures

  /// Makes a thread with a user message, a reasoning item, two tool calls,
  /// and an assistant message, in that order.
  private func makeThread() -> AgentThread {
    let thread = AgentThread()
    let items: [ThreadItem] = [
      .userMessage(Message(id: "u1", blocks: [ContentBlock(text: "Question")])),
      .reasoning(Reasoning(id: "r1", segments: ["Think"])),
      .toolCall(ToolCallRecord(id: "t1", title: "Read file")),
      .toolCall(ToolCallRecord(id: "t2", title: "Edit file")),
      .assistantMessage(Message(id: "a1", blocks: [ContentBlock(text: "Answer")])),
    ]
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }

  /// The identifiers of the items of the thread, in order.
  private func ids(_ thread: AgentThread) -> [String] {
    thread.items.map(\.id)
  }

  // MARK: - Tests

  @Test func compactRemovesTheItemsAndInsertsTheMarkerAtTheFirstRemovedIndex() {
    let thread = makeThread()
    let marker = CompactionMarker(id: "k1", summary: "Earlier work")

    thread.apply(.compact(marker: marker, removing: ["r1", "t1", "t2"]))

    #expect(ids(thread) == ["u1", "k1", "a1"])
    #expect(thread.position(of: "k1") == 1)
    #expect(thread.position(of: "a1") == 2)
    #expect(thread.item(id: "t1") == nil)
    #expect(thread.item(id: "k1")?.record === marker)
  }

  @Test func compactRecordsTheRemovedIDsInThreadOrderAndTheKindCounts() {
    let thread = makeThread()
    let marker = CompactionMarker(id: "k1", summary: nil)

    thread.apply(.compact(marker: marker, removing: ["t2", "r1", "t1"]))

    #expect(marker.removedItemIDs == ["r1", "t1", "t2"])
    #expect(marker.removedKinds == ["reasoning": 1, "tool-call": 2])
    #expect(marker.removedCount == 3)
  }

  @Test func compactIgnoresUnknownIDs() {
    let thread = makeThread()
    let marker = CompactionMarker(id: "k1", summary: nil)

    thread.apply(.compact(marker: marker, removing: ["missing", "t1"]))

    #expect(ids(thread) == ["u1", "r1", "k1", "t2", "a1"])
    #expect(marker.removedItemIDs == ["t1"])
  }

  @Test func compactWithNoKnownIDsInsertsTheMarkerAtTheEnd() {
    let thread = makeThread()
    let marker = CompactionMarker(id: "k1", summary: nil)

    thread.apply(.compact(marker: marker, removing: ["missing"]))

    #expect(ids(thread).last == "k1")
    #expect(thread.lastItemID == "k1")
    #expect(marker.removedItemIDs.isEmpty)
    #expect(marker.removedKinds.isEmpty)
  }

  @Test func compactOfTheWholeThreadLeavesOnlyTheMarker() {
    let thread = makeThread()
    let marker = CompactionMarker(id: "k1", summary: nil)

    thread.apply(.compact(marker: marker, removing: ids(thread)))

    #expect(ids(thread) == ["k1"])
    #expect(thread.lastItemID == "k1")
    #expect(marker.removedCount == 5)
  }

  @Test func compactReplacesAMarkerWithTheSameID() {
    let thread = makeThread()
    let earlier = CompactionMarker(id: "k1", summary: "Old")
    thread.apply(.insert(.compaction(earlier), after: "a1"))
    let marker = CompactionMarker(id: "k1", summary: "New")

    thread.apply(.compact(marker: marker, removing: ["u1"]))

    #expect(ids(thread) == ["k1", "r1", "t1", "t2", "a1"])
    #expect(thread.item(id: "k1")?.record === marker)
    #expect(marker.revision == earlier.revision + 1)
    #expect(marker.removedItemIDs == ["u1"])
  }

  @Test func theKindNameOfEachItemKind() {
    let cases: [(ThreadItem, String)] = [
      (.system(SystemPrompt(id: "s", text: "")), "system"),
      (.userMessage(Message(id: "u", blocks: [])), "user"),
      (.assistantMessage(Message(id: "a", blocks: [])), "assistant"),
      (.reasoning(Reasoning(id: "r", segments: [])), "reasoning"),
      (.toolCall(ToolCallRecord(id: "t", title: "")), "tool-call"),
      (.structured(StructuredRecord(id: "st", schemaName: "", payload: .null)), "structured"),
      (.compaction(CompactionMarker(id: "c", summary: nil)), "compaction"),
      (.error(ThreadError(id: "e", kind: .timeout)), "error"),
      (.unknown(UnknownRecord(id: "x", kind: "", raw: .null)), "unknown"),
    ]
    for (item, name) in cases {
      #expect(item.kindName == name)
    }
  }
}
