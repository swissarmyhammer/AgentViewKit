import AgentViewKit
import Foundation
import Testing

@MainActor
@Suite struct AgentThreadApplyTests {
  // MARK: - Fixtures

  /// Makes a thread that holds the items, in order.
  private func makeThread(_ items: [ThreadItem]) -> AgentThread {
    let thread = AgentThread()
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }

  /// Makes an assistant message item with one text block.
  private func assistant(_ id: String, _ text: String = "text") -> ThreadItem {
    .assistantMessage(Message(id: id, blocks: [ContentBlock(text: text)]))
  }

  /// Makes a tool call item.
  private func toolCall(_ id: String, title: String = "Read file") -> ThreadItem {
    .toolCall(ToolCallRecord(id: id, title: title, status: .inProgress))
  }

  /// The identifiers of the items of the thread, in order.
  private func ids(_ thread: AgentThread) -> [String] {
    thread.items.map(\.id)
  }

  /// Checks that the id lookup finds each item at its position.
  private func expectIndexIsConsistent(_ thread: AgentThread) {
    for item in thread.items {
      #expect(thread.item(id: item.id)?.record === item.record)
    }
  }

  /// Returns the tool call record of an item. The test fails when the item
  /// is missing or holds a record of a different type.
  private func toolCallRecord(_ item: ThreadItem?) throws -> ToolCallRecord {
    try #require(item?.record as? ToolCallRecord)
  }

  /// `true` when the item is a message from the user.
  private func isUserMessage(_ item: ThreadItem) -> Bool {
    if case .userMessage = item { true } else { false }
  }

  private static let permission = PermissionRequest(
    id: PermissionRequestID("perm-1"),
    title: "Run ls",
    options: []
  )

  private static let elicitation = ElicitationRequest(
    id: ElicitationRequestID("el-1"),
    server: "files",
    message: "Pick a folder.",
    mode: .url(URL(filePath: "/tmp"), elicitationId: "el-1")
  )

  private static let authorization = AuthorizationRequest(
    id: AuthorizationRequestID("auth-1"),
    serverName: "github",
    scopes: ["repo"],
    authorizationURL: URL(filePath: "/tmp/auth")
  )

  // MARK: - insert

  @Test func insertWithNoAnchorAppendsTheItem() {
    let thread = makeThread([assistant("a"), assistant("b")])

    thread.apply(.insert(assistant("c"), after: nil))

    #expect(ids(thread) == ["a", "b", "c"])
    expectIndexIsConsistent(thread)
  }

  @Test func insertAfterAnAnchorPutsTheItemAfterIt() {
    let thread = makeThread([assistant("a"), assistant("b")])

    thread.apply(.insert(assistant("c"), after: "a"))

    #expect(ids(thread) == ["a", "c", "b"])
    expectIndexIsConsistent(thread)
  }

  @Test func insertAfterAnUnknownAnchorAppendsTheItem() {
    let thread = makeThread([assistant("a")])

    thread.apply(.insert(assistant("c"), after: "missing"))

    #expect(ids(thread) == ["a", "c"])
  }

  @Test func insertOfAnExistingIdReplacesTheItemInPlace() {
    let thread = makeThread([assistant("a"), assistant("b")])
    let replacement = assistant("a", "new")

    thread.apply(.insert(replacement, after: "b"))

    #expect(ids(thread) == ["a", "b"])
    #expect(thread.items[0].record === replacement.record)
  }

  // MARK: - patch

  @Test func patchOfAnExistingToolCallChangesOnlyThatRecord() throws {
    let thread = makeThread([toolCall("t1"), toolCall("t2")])
    let other = try toolCallRecord(thread.item(id: "t2"))

    thread.apply(.patch(id: "t1", .toolCall(status: .value(.completed))))

    let patched = try toolCallRecord(thread.item(id: "t1"))
    #expect(patched.status == .completed)
    #expect(patched.title == "Read file")
    #expect(patched.revision == 1)
    #expect(other.status == .inProgress)
    #expect(other.revision == 0)
  }

  @Test func patchOfAnExistingRecordKeepsTheRecordObject() throws {
    let thread = makeThread([toolCall("t1")])
    let before = try toolCallRecord(thread.item(id: "t1"))

    thread.apply(.patch(id: "t1", .toolCall(title: .value("Write file"))))

    let after = try toolCallRecord(thread.item(id: "t1"))
    #expect(after === before)
    #expect(after.title == "Write file")
  }

  @Test func eachPatchIncrementsTheRevisionByOne() throws {
    let thread = makeThread([toolCall("t1")])

    thread.apply(.patch(id: "t1", .toolCall(status: .value(.completed))))
    thread.apply(.patch(id: "t1", .toolCall()))

    #expect(try toolCallRecord(thread.item(id: "t1")).revision == 2)
  }

  @Test func patchOfAnUnknownIdInsertsANewRecordAtTheEnd() throws {
    let thread = makeThread([assistant("a")])

    thread.apply(
      .patch(id: "t9", .toolCall(title: .value("Search"), kind: .value(.search)))
    )

    #expect(ids(thread) == ["a", "t9"])
    let created = try toolCallRecord(thread.item(id: "t9"))
    #expect(created.title == "Search")
    #expect(created.kind == .search)
    #expect(created.status == .pending)
    #expect(created.revision == 0)
  }

  @Test func clearedFieldsAreSetToNilOrEmpty() throws {
    let record = ToolCallRecord(
      id: "t1",
      title: "Run",
      kind: .execute,
      status: .failed,
      content: [.diff(patch: "@@")],
      locations: [ToolCallLocation(path: "/a")],
      rawInput: .string("in"),
      rawOutput: .string("out"),
      meta: .bool(true)
    )
    let thread = makeThread([.toolCall(record)])

    thread.apply(
      .patch(
        id: "t1",
        .toolCall(
          title: .cleared, kind: .cleared, status: .cleared, content: .cleared,
          locations: .cleared, rawInput: .cleared, rawOutput: .cleared, meta: .cleared
        )
      )
    )

    #expect(record.title.isEmpty)
    #expect(record.kind == .other)
    #expect(record.status == .pending)
    #expect(record.content.isEmpty)
    #expect(record.locations.isEmpty)
    #expect(record.rawInput == nil)
    #expect(record.rawOutput == nil)
    #expect(record.meta == nil)
  }

  @Test func unchangedFieldsKeepTheirValues() {
    let record = ToolCallRecord(
      id: "t1", title: "Run", kind: .execute, rawInput: .string("in"), meta: .bool(true)
    )
    let thread = makeThread([.toolCall(record)])

    thread.apply(.patch(id: "t1", .toolCall()))

    #expect(record.title == "Run")
    #expect(record.kind == .execute)
    #expect(record.rawInput == .string("in"))
    #expect(record.meta == .bool(true))
  }

  @Test func aToolCallChunkAppendsToTheContent() {
    let record = ToolCallRecord(id: "t1", title: "Run", content: [.diff(patch: "a")])
    let thread = makeThread([.toolCall(record)])

    thread.apply(.patch(id: "t1", .toolCallChunk(.terminal(id: "term-1"))))

    #expect(record.content == [.diff(patch: "a"), .terminal(id: "term-1")])
    #expect(record.revision == 1)
  }

  @Test func aMessageChunkAppendsABlock() {
    let message = Message(id: "m1", blocks: [ContentBlock(text: "Hello")])
    let thread = makeThread([.assistantMessage(message)])

    thread.apply(.patch(id: "m1", .assistantMessageChunk(ContentBlock(text: " world"))))

    #expect(message.blocks == [ContentBlock(text: "Hello"), ContentBlock(text: " world")])
    #expect(message.revision == 1)
  }

  @Test func aMessageChunkForANewIdCreatesAMessageOfThatRole() throws {
    let thread = AgentThread()

    thread.apply(.patch(id: "u1", .userMessageChunk(ContentBlock(text: "Hi"))))

    let item = try #require(thread.item(id: "u1"))
    #expect(isUserMessage(item))
    let message = try #require(item.record as? Message)
    #expect(message.blocks == [ContentBlock(text: "Hi")])
    #expect(message.revision == 0)
  }

  @Test func aMessagePatchReplacesTheBlocksAndTheMeta() {
    let message = Message(id: "m1", blocks: [ContentBlock(text: "old")])
    let thread = makeThread([.userMessage(message)])

    thread.apply(
      .patch(
        id: "m1",
        .userMessage(content: .value([ContentBlock(text: "new")]), meta: .value(.number(1)))
      )
    )

    #expect(message.blocks == [ContentBlock(text: "new")])
    #expect(message.meta == .number(1))
  }

  @Test func aReasoningChunkAddsASegment() {
    let reasoning = Reasoning(id: "r1", segments: ["First."])
    let thread = makeThread([.reasoning(reasoning)])

    thread.apply(.patch(id: "r1", .reasoningChunk("Second.")))
    thread.apply(.patch(id: "r1", .reasoning(signature: .value("sig"))))

    #expect(reasoning.segments == ["First.", "Second."])
    #expect(reasoning.signature == "sig")
    #expect(reasoning.revision == 2)
  }

  @Test func aSystemPatchChangesTheText() {
    let prompt = SystemPrompt(id: "s1", text: "Old")
    let thread = makeThread([.system(prompt)])

    thread.apply(.patch(id: "s1", .system(text: .value("New"))))

    #expect(prompt.text == "New")
  }

  @Test func aStructuredPatchChangesThePayload() {
    let record = StructuredRecord(id: "x1", schemaName: "AgentViewKit.Chart", payload: .null)
    let thread = makeThread([.structured(record)])

    thread.apply(.patch(id: "x1", .structured(payload: .value(.number(2)))))
    thread.apply(.patch(id: "x1", .structured(schemaName: .cleared)))

    #expect(record.payload == .number(2))
    #expect(record.schemaName.isEmpty)
  }

  @Test func aCompactionPatchClearsTheSummary() {
    let marker = CompactionMarker(id: "c1", summary: "Short")
    let thread = makeThread([.compaction(marker)])

    thread.apply(.patch(id: "c1", .compaction(summary: .cleared)))

    #expect(marker.summary == nil)
  }

  @Test func anErrorPatchChangesTheKind() {
    let error = ThreadError(id: "e1", kind: .timeout)
    let thread = makeThread([.error(error)])

    thread.apply(.patch(id: "e1", .error(kind: .value(.refusal(explanation: "No")))))

    #expect(error.kind == .refusal(explanation: "No"))
  }

  @Test func anUnknownPatchChangesTheRawValue() {
    let record = UnknownRecord(id: "u1", kind: "_widget", raw: .null)
    let thread = makeThread([.unknown(record)])

    thread.apply(.patch(id: "u1", .unknown(raw: .value(.string("x")))))

    #expect(record.raw == .string("x"))
    #expect(record.kind == "_widget")
  }

  @Test func aPatchOfAnotherKindReplacesTheItemInPlace() throws {
    let thread = makeThread([assistant("a"), assistant("b")])

    thread.apply(.patch(id: "a", .toolCall(title: .value("Run"))))

    #expect(ids(thread) == ["a", "b"])
    let replaced = try toolCallRecord(thread.item(id: "a"))
    #expect(replaced.title == "Run")
    #expect(replaced.revision == 1)
  }

  // MARK: - replace

  @Test func replaceSwapsTheRecordAndIncrementsTheRevision() {
    let original = Message(id: "a", blocks: [])
    original.bump()
    let thread = makeThread([.assistantMessage(original), assistant("b")])
    let replacement = assistant("a", "new")

    thread.apply(.replace(replacement))

    #expect(ids(thread) == ["a", "b"])
    #expect(thread.items[0].record === replacement.record)
    #expect(replacement.record.revision == 2)
  }

  @Test func replaceOfAnUnknownIdAppendsTheItem() {
    let thread = makeThread([assistant("a")])

    thread.apply(.replace(assistant("z")))

    #expect(ids(thread) == ["a", "z"])
    expectIndexIsConsistent(thread)
  }

  // MARK: - remove

  @Test func removeTakesOutTheItemAndKeepsTheIndexConsistent() throws {
    let thread = makeThread([toolCall("t1"), toolCall("t2"), toolCall("t3")])

    thread.apply(.remove(id: "t1"))

    #expect(ids(thread) == ["t2", "t3"])
    #expect(thread.item(id: "t1") == nil)
    expectIndexIsConsistent(thread)
    thread.apply(.patch(id: "t3", .toolCall(title: .value("Last"))))
    #expect(try toolCallRecord(thread.items[1]).title == "Last")
    #expect(try toolCallRecord(thread.items[0]).revision == 0)
  }

  @Test func removeOfAnUnknownIdChangesNothing() {
    let thread = makeThread([assistant("a")])

    thread.apply(.remove(id: "missing"))

    #expect(ids(thread) == ["a"])
  }

  // MARK: - clear

  @Test func clearEmptiesTheItemsAndTheSideTables() {
    let thread = makeThread([assistant("a"), toolCall("t1")])
    thread.apply(.setPlan(Plan(id: PlanID("p1"), entries: [])))
    thread.apply(.upsertTerminal(TerminalPatch(id: TerminalID("term-1"))))
    thread.apply(.addPermission(Self.permission))
    thread.apply(.addElicitation(Self.elicitation))
    thread.apply(.addAuthorization(Self.authorization))
    thread.apply(.appendStreaming(id: "a", text: "x"))
    thread.apply(.setState(.running))

    thread.apply(.clear)

    #expect(thread.items.isEmpty)
    #expect(thread.item(id: "a") == nil)
    #expect(thread.plans.isEmpty)
    #expect(thread.terminals.isEmpty)
    #expect(thread.pendingPermissions.isEmpty)
    #expect(thread.pendingElicitations.isEmpty)
    #expect(thread.pendingAuthorizations.isEmpty)
    #expect(thread.streaming.isEmpty)
    #expect(thread.state == .running)
  }

  @Test func afterClearAPatchCreatesTheRecordAgain() {
    let thread = makeThread([assistant("a")])

    thread.apply(.clear)
    thread.apply(.patch(id: "a", .assistantMessageChunk(ContentBlock(text: "again"))))

    #expect(ids(thread) == ["a"])
    expectIndexIsConsistent(thread)
  }

  // MARK: - Thread-level values

  @Test func setStateChangesTheState() {
    let thread = AgentThread()

    thread.apply(.setState(.idle(.endTurn)))

    #expect(thread.state == .idle(.endTurn))
  }

  @Test func setPlanStoresThePlanByItsId() {
    let thread = AgentThread()
    let first = Plan(id: PlanID("p1"), entries: [])
    let second = Plan(
      id: PlanID("p1"),
      entries: [PlanEntry(content: "Step", priority: .high, status: .pending)]
    )

    thread.apply(.setPlan(first))
    thread.apply(.setPlan(second))

    #expect(thread.plans == [PlanID("p1"): second])
  }

  @Test func removePlanTakesOutThePlan() {
    let thread = AgentThread()
    thread.apply(.setPlan(Plan(id: PlanID("p1"), entries: [])))

    thread.apply(.removePlan(PlanID("p1")))

    #expect(thread.plans.isEmpty)
  }

  @Test func upsertTerminalCreatesARecordOnFirstSight() throws {
    let thread = AgentThread()
    let id = TerminalID("term-1")

    thread.apply(
      .upsertTerminal(
        TerminalPatch(id: id, command: .value("ls"), outputChunk: Data("a".utf8))
      )
    )

    let terminal = try #require(thread.terminals[id])
    #expect(terminal.command == "ls")
    #expect(terminal.output == Data("a".utf8))
    #expect(terminal.revision == 0)
  }

  @Test func upsertTerminalPatchesAnExistingRecordInPlace() throws {
    let thread = AgentThread()
    let id = TerminalID("term-1")
    thread.apply(.upsertTerminal(TerminalPatch(id: id, command: .value("ls"))))
    let terminal = try #require(thread.terminals[id])

    thread.apply(
      .upsertTerminal(
        TerminalPatch(
          id: id,
          cwd: .value("/tmp"),
          exitStatus: .value(TerminalRecord.ExitStatus(code: 0)),
          outputChunk: Data("b".utf8)
        )
      )
    )

    #expect(thread.terminals[id] === terminal)
    #expect(terminal.command == "ls")
    #expect(terminal.cwd == "/tmp")
    #expect(terminal.exitStatus == TerminalRecord.ExitStatus(code: 0))
    #expect(terminal.output == Data("b".utf8))
    #expect(terminal.revision == 1)
  }

  @Test func upsertTerminalReplacesTheOutputBeforeItAppendsTheChunk() throws {
    let thread = AgentThread()
    let id = TerminalID("term-1")
    thread.apply(.upsertTerminal(TerminalPatch(id: id, outputChunk: Data("old".utf8))))

    thread.apply(
      .upsertTerminal(
        TerminalPatch(id: id, output: .value(Data("new".utf8)), outputChunk: Data("!".utf8))
      )
    )

    #expect(try #require(thread.terminals[id]).output == Data("new!".utf8))
  }

  @Test func setConfigOptionsReplacesTheOptions() {
    let thread = AgentThread()
    let option = ConfigOption(
      id: ConfigOptionID("mode"), name: "Mode", kind: .boolean(current: true)
    )

    thread.apply(.setConfigOptions([option]))

    #expect(thread.configOptions == [option])
  }

  @Test func setAvailableCommandsReplacesTheCommands() {
    let thread = AgentThread()
    let command = SlashCommand(name: "review", description: "Review the change.")

    thread.apply(.setAvailableCommands([command]))

    #expect(thread.availableCommands == [command])
  }

  @Test func setUsageChangesNoRecordRevision() throws {
    let thread = makeThread([toolCall("t1")])

    thread.apply(.setUsage(ContextUsage(used: 10, size: 100)))

    #expect(thread.usage == ContextUsage(used: 10, size: 100))
    #expect(try toolCallRecord(thread.item(id: "t1")).revision == 0)
    thread.apply(.setUsage(nil))
    #expect(thread.usage == nil)
  }

  @Test func patchInfoFoldsTheFields() {
    let thread = AgentThread()
    let date = Date(timeIntervalSince1970: 1_000)

    thread.apply(.patchInfo(ThreadInfoPatch(title: .value("Plan"), updatedAt: .value(date))))
    thread.apply(.patchInfo(ThreadInfoPatch(updatedAt: .cleared)))

    #expect(thread.info == ThreadInfo(title: "Plan", updatedAt: nil))
  }

  // MARK: - Pending requests

  @Test func addPermissionAppendsTheRequestOnce() {
    let thread = AgentThread()
    var changed = Self.permission
    changed.title = "Run ls -la"

    thread.apply(.addPermission(Self.permission))
    thread.apply(.addPermission(changed))

    #expect(thread.pendingPermissions == [changed])
  }

  @Test func resolvePermissionRemovesTheRequest() {
    let thread = AgentThread()
    thread.apply(.addPermission(Self.permission))

    thread.apply(.resolvePermission(Self.permission.id))

    #expect(thread.pendingPermissions.isEmpty)
  }

  @Test func addElicitationAppendsTheRequest() {
    let thread = AgentThread()

    thread.apply(.addElicitation(Self.elicitation))

    #expect(thread.pendingElicitations == [Self.elicitation])
  }

  @Test func resolveElicitationRemovesTheRequest() {
    let thread = AgentThread()
    thread.apply(.addElicitation(Self.elicitation))

    thread.apply(.resolveElicitation(Self.elicitation.id))

    #expect(thread.pendingElicitations.isEmpty)
  }

  @Test func addAuthorizationAppendsTheRequest() {
    let thread = AgentThread()

    thread.apply(.addAuthorization(Self.authorization))

    #expect(thread.pendingAuthorizations == [Self.authorization])
  }

  @Test func resolveAuthorizationRemovesTheRequest() {
    let thread = AgentThread()
    thread.apply(.addAuthorization(Self.authorization))

    thread.apply(.resolveAuthorization(Self.authorization.id))

    #expect(thread.pendingAuthorizations.isEmpty)
  }

  // MARK: - Streaming

  @Test func appendStreamingOnANewIdCreatesTheMessage() throws {
    let thread = AgentThread()

    thread.apply(.appendStreaming(id: "m1", text: "Hel"))

    let message = try #require(thread.streaming["m1"])
    #expect(message.id == "m1")
    #expect(message.text == "Hel")
  }

  @Test func appendStreamingOnAnExistingIdAddsTheText() throws {
    let thread = AgentThread()
    thread.apply(.appendStreaming(id: "m1", text: "Hel"))
    let message = try #require(thread.streaming["m1"])

    thread.apply(.appendStreaming(id: "m1", text: "lo"))

    #expect(thread.streaming["m1"] === message)
    #expect(message.text == "Hello")
  }

  @Test func closeStreamingRemovesTheMessage() {
    let thread = AgentThread()
    thread.apply(.appendStreaming(id: "m1", text: "Hi"))

    thread.apply(.closeStreaming(id: "m1"))

    #expect(thread.streaming["m1"] == nil)
  }
}
