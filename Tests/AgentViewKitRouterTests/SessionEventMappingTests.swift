import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import Testing

/// The id of the unknown records that the tests make.
private let unknownID = "unknown-1"

/// Applies the changes of one event to a new thread.
///
/// - Parameter event: The session event.
/// - Returns: The thread after the changes.
@MainActor
private func thread(after event: SessionEvent) -> AgentThread {
  let thread = AgentThread()
  for change in SessionEventMapping.changes(
    for: event, textID: "t1", reasoningID: "r1", makeUnknownID: { unknownID })
  {
    thread.apply(change)
  }
  return thread
}

/// The unknown record of the thread with the id.
@MainActor
private func unknownRecord(_ thread: AgentThread, id: String) -> UnknownRecord? {
  guard case .unknown(let record)? = thread.item(id: id) else { return nil }
  return record
}

/// One test for each `SessionEvent` case.
@MainActor
@Suite struct SessionEventMappingTests {
  @Test func turnStartedSetsTheStateToRunning() {
    #expect(thread(after: .turnStarted(RouterFixtures.turnStart)).state == .running)
  }

  @Test func textDeltaAppendsToTheStreamOfTheTextRow() {
    let changes = SessionEventMapping.changes(for: .textDelta("Hello"), textID: "t1")
    guard case .appendStreaming(let id, let text)? = changes.first, changes.count == 1 else {
      Issue.record("Expected one appendStreaming change, got \(changes)")
      return
    }
    #expect(id == "t1")
    #expect(text == "Hello")
  }

  @Test func textResetClosesTheStreamOfTheTextRow() {
    let changes = SessionEventMapping.changes(for: .textReset, textID: "t1")
    guard case .closeStreaming(let id)? = changes.first, changes.count == 1 else {
      Issue.record("Expected one closeStreaming change, got \(changes)")
      return
    }
    #expect(id == "t1")
  }

  @Test func reasoningDeltaAppendsToTheStreamOfTheReasoningRow() {
    let thread = thread(after: .reasoningDelta("Think"))
    #expect(thread.streaming["r1"]?.text == "Think")
    #expect(thread.streaming["t1"] == nil)
  }

  @Test func toolCallMakesAToolCallInProgress() {
    let thread = thread(after: .toolCall(id: "c1", name: "read", argumentsJSON: #"{"path": "a.swift"}"#))
    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("Expected a tool call record")
      return
    }
    #expect(call.title == "read")
    #expect(call.status == .inProgress)
    #expect(call.rawInput == .object(["path": .string("a.swift")]))
  }

  @Test func toolCallKeepsArgumentsThatAreNotJSONAsText() {
    let thread = thread(after: .toolCall(id: "c1", name: "read", argumentsJSON: "not json"))
    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("Expected a tool call record")
      return
    }
    #expect(call.rawInput == .string("not json"))
  }

  @Test(arguments: [
    (FoundationModelsRouter.ToolCallStatus.running, AgentViewKit.ToolCallStatus.inProgress),
    (.completed, .completed),
    (.failed, .failed),
  ])
  func toolStatusSetsTheStatus(
    status: FoundationModelsRouter.ToolCallStatus, expected: AgentViewKit.ToolCallStatus
  ) {
    let thread = thread(after: .toolStatus(id: "c1", status: status, summary: nil, output: nil))
    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("Expected a tool call record")
      return
    }
    #expect(call.status == expected)
    #expect(call.content.isEmpty)
    #expect(call.rawOutput == nil)
  }

  @Test func toolStatusWithOutputSetsTheContentAndTheSummary() {
    let output: [SegmentPayload] = [
      .text(id: "s1", content: "42 lines"),
      .structure(id: "s2", schemaName: "Lines", contentJSON: #"{"count": 42}"#),
      .attachment(id: "s3", label: "log", url: "file:///tmp/log.txt"),
      .custom(id: "s4", typeDiscriminator: "Legacy", contentJSON: #"{"a": 1}"#, description: nil),
      .unknown(id: "s5", description: "future"),
    ]
    let thread = thread(after: .toolStatus(id: "c1", status: .completed, summary: "42 lines", output: output))
    guard case .toolCall(let call)? = thread.item(id: "c1") else {
      Issue.record("Expected a tool call record")
      return
    }
    #expect(call.rawOutput == .string("42 lines"))
    let contents = call.content.map { content -> ContentBlock.Content? in
      guard case .block(let block) = content else { return nil }
      return block.content
    }
    #expect(contents.count == output.count)
    #expect(contents[0] == .text("42 lines"))
    #expect(contents[1] == .structured(schemaName: "Lines", payload: .object(["count": .number(42)])))
    #expect(contents[2] == .attachment(URL(string: "file:///tmp/log.txt")!))
    #expect(
      contents[3]
        == .unknown(
          kind: "custom",
          raw: .object(["typeDiscriminator": .string("Legacy"), "content": .object(["a": .number(1)])])))
    guard case .unknown(let kind, _)? = contents[4] else {
      Issue.record("Expected an unknown block for an unknown segment")
      return
    }
    #expect(kind == "segment")
  }

  @Test func toolInvocationBecomesAnUnknownRecord() throws {
    let thread = thread(after: .toolInvocation(RouterFixtures.invocation))
    let record = try #require(unknownRecord(thread, id: "tool-invocation-run-3"))
    #expect(record.kind == "toolInvocation")
    #expect(record.raw["tool"] == .string("files"))
  }

  @Test func toolCallReportMakesOneStructuredRecordForEachAttachment() throws {
    let report = ToolCallReport(
      tool: "files",
      op: "read",
      correlationID: "run-5",
      sessionID: RouterFixtures.sessionID,
      attachments: [
        ToolCallAttachment(schemaName: "Diff", contentJSON: #"{"lines": 3}"#),
        ToolCallAttachment(schemaName: "Log", contentJSON: #"{"text": "ok"}"#),
      ]
    )
    let thread = thread(after: .toolCallReport(report))
    #expect(thread.items.count == 2)
    guard case .structured(let first)? = thread.item(id: "run-5#attachment-0"),
      case .structured(let second)? = thread.item(id: "run-5#attachment-1")
    else {
      Issue.record("Expected two structured records")
      return
    }
    #expect(first.schemaName == "Diff")
    #expect(first.payload == .object(["lines": .number(3)]))
    #expect(first.meta?["correlationID"] == .string("run-5"))
    #expect(second.schemaName == "Log")
  }

  @Test func entryRecordedGivesNoChange() {
    #expect(SessionEventMapping.changes(for: .entryRecorded(id: "e1", kind: .response)).isEmpty)
  }

  @Test func compactionMakesACompactionMarker() throws {
    let result = CompactionResult(
      id: "k1", summary: "Earlier work", tokensBefore: 900, tokensAfter: 300, stagesApplied: ["elide"])
    let thread = thread(after: .compaction(result))
    guard case .compaction(let marker)? = thread.item(id: "k1") else {
      Issue.record("Expected a compaction marker")
      return
    }
    #expect(marker.summary == "Earlier work")
    #expect(marker.meta?["tokensBefore"] == .number(900))
    #expect(marker.meta?["tokensAfter"] == .number(300))
    #expect(marker.meta?["stagesApplied"] == .array([.string("elide")]))
  }

  @Test func discoveryPrimingFailedBecomesAnUnknownRecord() throws {
    let thread = thread(after: .discoveryPrimingFailed(.toolNotMounted(tool: "search")))
    let record = try #require(unknownRecord(thread, id: unknownID))
    #expect(record.kind == "discoveryPrimingFailed")
  }

  @Test func generationStalledBecomesAnUnknownRecord() throws {
    let stall = GenerationStall(
      timeWithoutProgress: .seconds(30), timeInFlight: .seconds(60), visibility: .wholeAnswer)
    let thread = thread(after: .generationStalled(stall))
    let record = try #require(unknownRecord(thread, id: unknownID))
    #expect(record.kind == "generationStalled")
    #expect(record.raw == .string(stall.description))
  }

  @Test func runSettledBecomesAnUnknownRecord() throws {
    let thread = thread(after: .runSettled(RouterFixtures.settled))
    let record = try #require(unknownRecord(thread, id: "run-settled-run-4"))
    #expect(record.kind == "runSettled")
    #expect(record.raw["detail"] == .string("Done"))
  }

  @Test func formElicitationRequestedAddsAPendingElicitation() throws {
    let thread = thread(after: .elicitationRequested(try RouterFixtures.formElicitation()))
    let request = try #require(thread.pendingElicitations.first)
    #expect(thread.pendingElicitations.count == 1)
    #expect(request.id.rawValue == RouterFixtures.elicitationId.ulidString)
    #expect(request.server == "files")
    #expect(request.message == "Name the file")
    guard case .form(let schema) = request.mode else {
      Issue.record("Expected a form request")
      return
    }
    #expect(schema["type"] == .string("object"))
    #expect(schema["properties"]?["name"]?["type"] == .string("string"))
  }

  @Test func urlElicitationRequestedAddsAPendingURLElicitation() throws {
    let thread = thread(after: .elicitationRequested(RouterFixtures.urlElicitation()))
    let request = try #require(thread.pendingElicitations.first)
    #expect(request.mode == .url(RouterFixtures.url, elicitationId: RouterFixtures.elicitationId.ulidString))
  }

  @Test func elicitationRequestedWithNoRequestBecomesAnUnknownRecord() throws {
    let thread = thread(after: .elicitationRequested(RouterFixtures.settled))
    #expect(thread.pendingElicitations.isEmpty)
    let record = try #require(unknownRecord(thread, id: "elicitation-run-4"))
    #expect(record.kind == "elicitationRequested")
  }

  @Test func turnEndedSetsTheUsageAndTheStopReason() throws {
    let usage = TokenUsage(
      tokensIn: RouterFixtures.tokensIn, tokensOut: RouterFixtures.tokensOut,
      contextFill: RouterFixtures.contextFill, finishReason: .maxTokens)
    let thread = thread(after: .turnEnded(usage))
    #expect(
      thread.usage
        == ContextUsage(
          used: RouterFixtures.tokensIn + RouterFixtures.tokensOut, size: RouterFixtures.contextSize))
    #expect(thread.state == .idle(.maxTokens))
  }

  @Test func turnEndedWithNoFillGivesASizeOfZero() {
    let usage = TokenUsage(
      tokensIn: RouterFixtures.tokensIn, tokensOut: RouterFixtures.tokensOut, contextFill: 0)
    let thread = thread(after: .turnEnded(usage))
    #expect(thread.usage?.size == 0)
    #expect(thread.state == .idle(.endTurn))
  }

  // MARK: - Seed rows

  @Test func seedRowsKeepTheirIDsAndKinds() throws {
    let projection = SessionProjection()
    projection.apply(.textDelta("Hi"))
    projection.apply(.entryRecorded(id: "e1", kind: .response))
    projection.apply(.reasoningDelta("Hmm"))
    projection.apply(.entryRecorded(id: "e2", kind: .reasoning))
    projection.apply(.toolCall(id: "c1", name: "read", argumentsJSON: "{}"))
    projection.apply(
      .toolStatus(id: "c1", status: .completed, summary: "ok", output: [.text(id: "s1", content: "ok")]))
    projection.apply(
      .compaction(
        CompactionResult(id: "k1", summary: nil, tokensBefore: 2, tokensAfter: 1, stagesApplied: [])))
    let thread = AgentThread()
    for row in projection.transcript {
      for change in SessionEventMapping.changes(for: row) {
        thread.apply(change)
      }
    }
    #expect(thread.items.map(\.id) == ["e1", "e2", "c1", "k1"])
    guard case .assistantMessage(let message)? = thread.item(id: "e1"),
      case .reasoning(let reasoning)? = thread.item(id: "e2"),
      case .toolCall(let call)? = thread.item(id: "c1"),
      case .compaction? = thread.item(id: "k1")
    else {
      Issue.record("Expected a message, a reasoning record, a tool call, and a marker")
      return
    }
    #expect(message.blocks == [ContentBlock(text: "Hi")])
    #expect(reasoning.segments == ["Hmm"])
    #expect(call.status == .completed)
    #expect(call.rawOutput == .string("ok"))
    #expect(call.content == [.block(ContentBlock(text: "ok"))])
  }

  // MARK: - Responses

  @Test func acceptWithAnObjectKeepsTheValuesThatTheRouterTakes() {
    let response = SessionEventMapping.response(
      for: .accept(
        .object([
          "name": .string("a.swift"),
          "count": .number(2),
          "force": .bool(true),
          "tags": .array([.string("x")]),
          "mixed": .array([.number(1)]),
          "nothing": .null,
          "nested": .object([:]),
        ])))
    #expect(
      response
        == .accept(content: [
          "name": .string("a.swift"), "count": .number(2), "force": .boolean(true),
          "tags": .stringArray(["x"]),
        ]))
  }

  @Test func acceptWithNoContentGivesAnAcceptWithNoContent() {
    #expect(SessionEventMapping.response(for: .accept(nil)) == .accept(content: nil))
  }

  @Test func declineAndCancelKeepTheirActions() {
    #expect(SessionEventMapping.response(for: .decline) == .decline)
    #expect(SessionEventMapping.response(for: .cancel) == .cancel)
  }
}
