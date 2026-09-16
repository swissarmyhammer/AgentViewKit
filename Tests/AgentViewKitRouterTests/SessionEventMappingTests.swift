import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import Testing

/// The id of the unknown records that the tests make.
private let unknownID = "unknown-1"

/// The line count in the structured output of the tool status fixture.
private let lineCount = 42.0

/// The value in the legacy custom segment of the tool status fixture.
private let legacyValue = 1.0

/// The line count in the first attachment of the report fixture.
private let diffLineCount = 3.0

/// The number value in the accepted form of the response fixture.
private let fileCount = 2.0

/// Applies the changes of one event to a new thread.
///
/// - Parameter event: The session event.
/// - Returns: The thread after the changes.
@MainActor
private func thread(after event: SessionEvent) -> AgentThread {
  let thread = AgentThread()
  let changes = SessionEventMapping.changes(
    for: event, textID: "t1", reasoningID: "r1", makeUnknownID: { unknownID })
  for change in changes {
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

/// The tool call record of the thread with the id `c1`.
@MainActor
private func toolCall(_ thread: AgentThread) throws -> ToolCallRecord {
  guard case .toolCall(let call)? = thread.item(id: "c1") else {
    throw MissingRecord()
  }
  return call
}

/// The error of a test that does not find the record that it reads.
private struct MissingRecord: Error {}

/// One test for each `SessionEvent` case.
@MainActor
@Suite struct SessionEventMappingTests {
  @Test func turnStartedSetsTheStateToRunning() {
    #expect(thread(after: .turnStarted(RouterFixtures.turnStart)).state == .running)
  }

  @Test func textDeltaAppendsToTheStreamOfTheTextRow() {
    let thread = thread(after: .textDelta("Hello"))
    #expect(thread.streaming["t1"]?.text == "Hello")
    #expect(thread.streaming["r1"] == nil)
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

  @Test func toolCallMakesAToolCallInProgress() throws {
    let call = try toolCall(
      thread(after: .toolCall(id: "c1", name: "read", argumentsJSON: #"{"path": "a.swift"}"#)))
    #expect(call.title == "read")
    #expect(call.status == .inProgress)
    #expect(call.rawInput == .object(["path": .string("a.swift")]))
  }

  @Test func toolCallKeepsArgumentsThatAreNotJSONAsText() throws {
    let call = try toolCall(thread(after: .toolCall(id: "c1", name: "read", argumentsJSON: "not json")))
    #expect(call.rawInput == .string("not json"))
  }

  @Test(arguments: [
    (FoundationModelsRouter.ToolCallStatus.running, AgentViewKit.ToolCallStatus.inProgress),
    (.completed, .completed),
    (.failed, .failed),
  ])
  func toolStatusSetsTheStatus(
    status: FoundationModelsRouter.ToolCallStatus, expected: AgentViewKit.ToolCallStatus
  ) throws {
    let call = try toolCall(thread(after: .toolStatus(id: "c1", status: status, summary: nil, output: nil)))
    #expect(call.status == expected)
    #expect(call.content.isEmpty)
    #expect(call.rawOutput == nil)
  }

  @Test func toolStatusWithOutputSetsTheContentAndTheSummary() throws {
    let unknownSegment = SegmentPayload.unknown(id: "s5", description: "future")
    let output: [SegmentPayload] = [
      .text(id: "s1", content: "42 lines"),
      .structure(id: "s2", schemaName: "Lines", contentJSON: #"{"count": \#(lineCount)}"#),
      .attachment(id: "s3", label: "log", url: "file:///tmp/log.txt"),
      .custom(
        id: "s4", typeDiscriminator: "Legacy", contentJSON: #"{"a": \#(legacyValue)}"#, description: nil),
      unknownSegment,
    ]
    let expected: [ToolContent] = [
      .block(ContentBlock(text: "42 lines")),
      .block(
        ContentBlock(
          content: .structured(schemaName: "Lines", payload: .object(["count": .number(lineCount)])))),
      .block(ContentBlock(content: .attachment(URL(string: "file:///tmp/log.txt")!))),
      .block(
        ContentBlock(
          content: .unknown(
            kind: "custom",
            raw: .object([
              "typeDiscriminator": .string("Legacy"), "content": .object(["a": .number(legacyValue)]),
            ])
          ))),
      .block(
        ContentBlock(
          content: .unknown(kind: "segment", raw: AgentViewKit.JSONValue.encodedOrNull(unknownSegment)))),
    ]
    let call = try toolCall(
      thread(after: .toolStatus(id: "c1", status: .completed, summary: "42 lines", output: output)))
    #expect(call.rawOutput == .string("42 lines"))
    #expect(call.content == expected)
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
        ToolCallAttachment(schemaName: "Diff", contentJSON: #"{"lines": \#(diffLineCount)}"#),
        ToolCallAttachment(schemaName: "Log", contentJSON: #"{"text": "ok"}"#),
      ]
    )
    let thread = thread(after: .toolCallReport(report))
    #expect(thread.items.count == report.attachments.count)
    guard case .structured(let first)? = thread.item(id: "run-5#attachment-0"),
      case .structured(let second)? = thread.item(id: "run-5#attachment-1")
    else {
      Issue.record("Expected two structured records")
      return
    }
    #expect(first.schemaName == "Diff")
    #expect(first.payload == .object(["lines": .number(diffLineCount)]))
    #expect(first.meta?["correlationID"] == .string("run-5"))
    #expect(second.schemaName == "Log")
  }

  @Test func entryRecordedGivesNoChange() {
    #expect(SessionEventMapping.changes(for: .entryRecorded(id: "e1", kind: .response)).isEmpty)
  }

  @Test func compactionMakesACompactionMarker() throws {
    let result = CompactionResult(
      id: "k1",
      summary: "Earlier work",
      tokensBefore: RouterFixtures.tokensBeforeCompaction,
      tokensAfter: RouterFixtures.tokensAfterCompaction,
      stagesApplied: ["elide"]
    )
    let thread = thread(after: .compaction(result))
    guard case .compaction(let marker)? = thread.item(id: "k1") else {
      Issue.record("Expected a compaction marker")
      return
    }
    #expect(marker.summary == "Earlier work")
    #expect(marker.meta?["tokensBefore"] == .number(Double(RouterFixtures.tokensBeforeCompaction)))
    #expect(marker.meta?["tokensAfter"] == .number(Double(RouterFixtures.tokensAfterCompaction)))
    #expect(marker.meta?["stagesApplied"] == .array([.string("elide")]))
  }

  @Test func discoveryPrimingFailedBecomesAnUnknownRecord() throws {
    let thread = thread(after: .discoveryPrimingFailed(.toolNotMounted(tool: "search")))
    let record = try #require(unknownRecord(thread, id: unknownID))
    #expect(record.kind == "discoveryPrimingFailed")
  }

  @Test func generationStalledBecomesAnUnknownRecord() throws {
    let stall = GenerationStall(
      timeWithoutProgress: RouterFixtures.stallTime, timeInFlight: RouterFixtures.flightTime,
      visibility: .wholeAnswer)
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
    #expect(thread.usage == RouterFixtures.contextUsage)
    #expect(thread.state == .idle(.maxTokens))
  }

  @Test func turnEndedWithNoFillGivesASizeOfZero() {
    let usage = TokenUsage(
      tokensIn: RouterFixtures.tokensIn, tokensOut: RouterFixtures.tokensOut, contextFill: .zero)
    let thread = thread(after: .turnEnded(usage))
    #expect(thread.usage == ContextUsage(used: RouterFixtures.usedTokens, size: .zero))
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
        CompactionResult(
          id: "k1", summary: nil, tokensBefore: RouterFixtures.tokensBeforeCompaction,
          tokensAfter: RouterFixtures.tokensAfterCompaction, stagesApplied: [])))
    let thread = AgentThread()
    for row in projection.transcript {
      for change in SessionEventMapping.changes(for: row) {
        thread.apply(change)
      }
    }
    #expect(thread.items.map(\.id) == ["e1", "e2", "c1", "k1"])
    guard case .assistantMessage(let message)? = thread.item(id: "e1"),
      case .reasoning(let reasoning)? = thread.item(id: "e2"),
      case .compaction? = thread.item(id: "k1")
    else {
      Issue.record("Expected a message, a reasoning record, and a marker")
      return
    }
    let call = try toolCall(thread)
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
          "count": .number(fileCount),
          "force": .bool(true),
          "tags": .array([.string("x")]),
          "mixed": .array([.number(fileCount)]),
          "nothing": .null,
          "nested": .object([:]),
        ])))
    let expected = ElicitationResponse.accept(content: [
      "name": .string("a.swift"),
      "count": .number(fileCount),
      "force": .boolean(true),
      "tags": .stringArray(["x"]),
    ])
    #expect(response == expected)
  }

  @Test func acceptWithNoContentGivesAnAcceptWithNoContent() {
    #expect(SessionEventMapping.response(for: .accept(nil)) == .accept(content: nil))
  }

  @Test func declineAndCancelKeepTheirActions() {
    #expect(SessionEventMapping.response(for: .decline) == .decline)
    #expect(SessionEventMapping.response(for: .cancel) == .cancel)
  }
}
