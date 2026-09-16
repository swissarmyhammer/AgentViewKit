import AgentViewKit
import Foundation
import Testing

@Suite struct ThreadItemTests {
  /// Makes one item for each case of ``ThreadItem``, each with a different id.
  private static func oneItemForEachCase() -> [(item: ThreadItem, id: String)] {
    [
      (.system(SystemPrompt(id: "system-1", text: "Be brief.")), "system-1"),
      (.userMessage(Message(id: "user-1", blocks: [ContentBlock(text: "Hello")])), "user-1"),
      (
        .assistantMessage(Message(id: "assistant-1", blocks: [ContentBlock(text: "Hi")])),
        "assistant-1"
      ),
      (.reasoning(Reasoning(id: "reasoning-1", segments: ["Think"])), "reasoning-1"),
      (.toolCall(ToolCallRecord(id: "tool-1", title: "Read file")), "tool-1"),
      (
        .structured(StructuredRecord(id: "structured-1", schemaName: "Chart", payload: .null)),
        "structured-1"
      ),
      (.compaction(CompactionMarker(id: "compaction-1", summary: "Earlier work")), "compaction-1"),
      (.error(ThreadError(id: "error-1", kind: .timeout)), "error-1"),
      (.unknown(UnknownRecord(id: "unknown-1", kind: "new_kind", raw: .null)), "unknown-1"),
    ]
  }

  // MARK: - Identity

  @Test func theItemIdIsTheRecordIdForEachCase() {
    let items = Self.oneItemForEachCase()

    #expect(items.count == 9)
    for (item, id) in items {
      #expect(item.id == id)
      #expect(item.record.id == id)
    }
  }

  @Test func theItemRecordIsTheSameObjectAsTheCaseRecord() {
    let message = Message(id: "user-1", blocks: [])
    let item = ThreadItem.userMessage(message)

    #expect(item.record === message)
  }

  // MARK: - Revision

  @Test func aNewRecordHasRevisionZero() {
    for (item, _) in Self.oneItemForEachCase() {
      #expect(item.record.revision == 0)
    }
  }

  @Test func bumpIncrementsTheRevisionByOneForEachCase() {
    for (item, _) in Self.oneItemForEachCase() {
      let record = item.record

      record.bump()
      #expect(record.revision == 1)
      record.bump()
      #expect(record.revision == 2)
    }
  }

  @Test func bumpChangesOnlyTheRevision() {
    let call = ToolCallRecord(id: "tool-1", title: "Read file", kind: .read, status: .pending)

    call.bump()

    #expect(call.id == "tool-1")
    #expect(call.title == "Read file")
    #expect(call.kind == .read)
    #expect(call.status == .pending)
  }

  // MARK: - Metadata

  @Test func aRecordKeepsItsMetaUnchanged() {
    let meta = JSONValue.object(["source": .string("acp")])
    let record = UnknownRecord(id: "unknown-1", kind: "x", raw: .null, meta: meta)

    #expect(record.meta == meta)
    #expect(ThreadItem.unknown(record).record.meta == meta)
  }

  // MARK: - Observation

  @Test func bumpNotifiesAnObserverOfTheRevision() {
    let reasoning = Reasoning(id: "reasoning-1", segments: [])
    let changed = ChangeFlag()

    withObservationTracking {
      _ = reasoning.revision
    } onChange: {
      changed.set()
    }
    reasoning.bump()

    #expect(changed.value)
  }

  // MARK: - Records

  @Test func aToolCallRecordHasTheDefaultValues() {
    let call = ToolCallRecord(id: "tool-1", title: "Run")

    #expect(call.kind == .other)
    #expect(call.status == .pending)
    #expect(call.content.isEmpty)
    #expect(call.locations.isEmpty)
    #expect(call.rawInput == nil)
    #expect(call.rawOutput == nil)
    #expect(call.startedAt == nil)
    #expect(call.endedAt == nil)
  }

  @Test func aToolCallRecordKeepsItsContentAndLocations() {
    let started = Date(timeIntervalSince1970: 10)
    let ended = Date(timeIntervalSince1970: 20)
    let content: [ToolContent] = [
      .block(ContentBlock(text: "Done")), .diff(patch: "@@ -1 +1 @@"), .terminal(id: "term-1"),
    ]
    let call = ToolCallRecord(
      id: "tool-1",
      title: "Edit",
      kind: .edit,
      status: .completed,
      content: content,
      locations: [ToolCallLocation(path: "/tmp/a.swift", line: 3)],
      rawInput: .object(["path": .string("/tmp/a.swift")]),
      rawOutput: .string("ok"),
      startedAt: started,
      endedAt: ended
    )

    #expect(call.content == content)
    #expect(call.locations == [ToolCallLocation(path: "/tmp/a.swift", line: 3)])
    #expect(call.rawInput?["path"] == .string("/tmp/a.swift"))
    #expect(call.rawOutput == .string("ok"))
    #expect(call.startedAt == started)
    #expect(call.endedAt == ended)
  }

  @Test func aThreadErrorKeepsItsKind() {
    let kinds: [ThreadError.Kind] = [
      .contextSizeExceeded(contextSize: 4096, tokenCount: 5000),
      .rateLimited(resetAt: Date(timeIntervalSince1970: 0)),
      .guardrailViolation(explanation: "blocked"),
      .refusal(explanation: nil),
      .timeout,
      .acp(code: -32603, message: "Internal error"),
      .unknown(message: "x"),
    ]

    for kind in kinds {
      #expect(ThreadError(id: "error-1", kind: kind).kind == kind)
    }
  }

  @Test func eachRecordTypeConformsToThreadRecord() {
    let types: [any ThreadRecord.Type] = [
      SystemPrompt.self, Message.self, Reasoning.self, ToolCallRecord.self,
      StructuredRecord.self, CompactionMarker.self, ThreadError.self, UnknownRecord.self,
    ]

    #expect(types.count == 8)
  }
}
