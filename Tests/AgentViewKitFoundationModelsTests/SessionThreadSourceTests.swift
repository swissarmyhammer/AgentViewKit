import AgentViewKit
import AgentViewKitFoundationModels
import AgentViewKitTestSupport
import Foundation
import FoundationModels
import Testing

/// The values and the helpers of the source tests.
enum SourceSamples {
  /// The id of the response entry that the fake model makes.
  static let responseID = "response-1"

  /// The id of the tool calls entry that the fake model makes.
  static let toolCallsID = "tool-calls-1"

  /// The id of the tool call that the fake model makes.
  static let toolCallID = "call-1"

  /// The arguments of the tool call, as JSON text.
  static let toolArguments = #"{"path":"README.md"}"#

  /// The instructions of the sessions.
  static let instructions = "Be brief."

  /// The prompt of the tests.
  static let prompt = "Read the file."

  /// The chunks of the gated stream. The fake waits at the gate after the
  /// chunks of each group.
  static let chunkGroups = [["A ", "B "], ["C ", "D "], ["E ", "F "], ["G"]]

  /// The full text of the gated stream.
  static let streamedText = chunkGroups.joined().joined()

  /// The context size of the error test.
  static let contextSize = 4_096

  /// The token count of the error test.
  static let tokenCount = 5_000

  /// The context window size of the usage test.
  nonisolated static let windowSize = 1_000

  /// The tokens that the usage test counts for each transcript entry.
  nonisolated static let tokensPerEntry = 10

  /// The cost that the usage test puts on the thread before the stream.
  static let cost = ContextUsage.Cost(amount: costAmount, currency: "USD")

  /// The amount of ``cost``.
  static let costAmount = 1.5

  /// The events of a gated stream: the chunk groups with a gate after each
  /// group but the last.
  static var gatedStreamEvents: [FakeEvent] {
    chunkGroups.enumerated().flatMap { position, group -> [FakeEvent] in
      let chunks = group.map { FakeEvent.text(entryID: responseID, text: $0) }
      return position < chunkGroups.count - 1 ? chunks + [.waitForGate] : chunks
    }
  }

  /// Waits until a gated stream shows its first text.
  ///
  /// A stream snapshot comes one event late, so the text of the last chunk
  /// before a gate stays back until the next chunk. The function waits for
  /// the response entry in the transcript, opens the first gate, and then
  /// waits for the text. After this function, the stream has one gate fewer.
  ///
  /// - Parameters:
  ///   - session: The session of the stream.
  ///   - thread: The thread that the stream fills.
  ///   - gate: The gate of the fake model of the session.
  /// - Returns: `true` when the streaming message has text.
  static func openFirstGateAndWaitForText(
    session: LanguageModelSession,
    thread: AgentThread,
    gate: FakeGate
  ) async -> Bool {
    let started = await waitUntil { session.transcript.last?.id == responseID }
    gate.open()
    let streamed = await waitUntil { streamedText(in: thread)?.isEmpty == false }
    return started && streamed
  }

  /// A turn with one tool call and then a text answer.
  static let toolTurn: [[FakeEvent]] = [
    [
      .toolCall(
        entryID: toolCallsID, callID: toolCallID, toolName: FakeReadTool.toolName,
        arguments: toolArguments)
    ],
    [.text(entryID: responseID, text: "Done.")],
  ]

  /// The message of an assistant message item, or `nil` for another item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The message.
  static func assistantMessage(_ item: ThreadItem?) -> Message? {
    if case .assistantMessage(let message) = item { message } else { nil }
  }

  /// The record of a tool call item, or `nil` for another item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The record.
  static func toolCall(_ item: ThreadItem?) -> ToolCallRecord? {
    if case .toolCall(let record) = item { record } else { nil }
  }

  /// The kind of an error item, or `nil` for another item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The kind.
  static func errorKind(_ item: ThreadItem?) -> ThreadError.Kind? {
    if case .error(let record) = item { record.kind } else { nil }
  }

  /// The text of the streaming message of the response, after a flush.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The text, or `nil` when the response does not stream.
  static func streamedText(in thread: AgentThread) -> String? {
    thread.streaming[responseID]?.flush()
    return thread.streaming[responseID]?.text
  }
}

@Suite @MainActor struct SessionThreadSourceTests {
  // MARK: - Observation

  @Test func startCopiesTheTranscriptOfTheSession() throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: []), transcript: try TranscriptSamples.fullTranscript())
    let source = SessionThreadSource(session: session)
    defer { source.stop() }

    source.start()

    #expect(source.thread.items.map(\.id) == AgentTranscriptViewHostedTests.rowIDs)
    #expect(source.thread.state == .idle(nil))
  }

  @Test func respondAddsTheUserAndAssistantItemsWithTheTranscriptIDs() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: SourceSamples.responseID, text: "Hello")]]),
      instructions: SourceSamples.instructions)
    let source = SessionThreadSource(session: session)
    defer { source.stop() }
    source.start()

    try await session.respond(to: SourceSamples.prompt)

    let transcriptIDs = session.transcript.map(\.id)
    #expect(await waitUntil { source.thread.items.map(\.id) == transcriptIDs })
    #expect(transcriptIDs.count == 3)
    #expect(transcriptIDs.last == SourceSamples.responseID)
    guard case .userMessage(let prompt) = source.thread.items[1] else {
      Issue.record("The second item is not a message from the user.")
      return
    }
    #expect(prompt.blocks == [ContentBlock(text: SourceSamples.prompt)])
    #expect(
      SourceSamples.assistantMessage(source.thread.item(id: SourceSamples.responseID))?.blocks
        == [ContentBlock(text: "Hello")])
    #expect(await waitUntil { source.thread.state == .idle(nil) })
  }

  @Test func stopEndsTheObservation() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: SourceSamples.responseID, text: "Hello")]]))
    let source = SessionThreadSource(session: session)
    source.start()
    source.stop()

    try await session.respond(to: SourceSamples.prompt)
    await Task.yield()

    #expect(source.thread.items.isEmpty)
  }

  @Test func aToolCallRecordStartsBeforeItEndsAfterTheOutputLands() async throws {
    let clock = TickingClock()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: SourceSamples.toolTurn), tools: [FakeReadTool()])
    let source = SessionThreadSource(session: session, clock: clock.now)
    defer { source.stop() }
    source.start()

    try await session.respond(to: SourceSamples.prompt)

    #expect(await waitUntil { source.thread.item(id: SourceSamples.responseID) != nil })
    let call = try #require(SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID)))
    let startedAt = try #require(call.startedAt)
    let endedAt = try #require(call.endedAt)
    #expect(startedAt <= endedAt)
    #expect(call.status == .completed)
    #expect(call.content == [.block(ContentBlock(text: FakeReadTool.output))])
  }

  // MARK: - Streaming

  @Test func aStreamGrowsTheStreamingMessageAndSetsTheRecordOnClose() async throws {
    let gate = FakeGate()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [SourceSamples.gatedStreamEvents], gate: gate))
    let source = SessionThreadSource(session: session)
    let thread = source.thread
    let run = Task { await source.stream(SourceSamples.prompt) }

    #expect(await SourceSamples.openFirstGateAndWaitForText(session: session, thread: thread, gate: gate))
    let first = try #require(SourceSamples.streamedText(in: thread))
    #expect(thread.state == .running)
    gate.open()
    #expect(await waitUntil { (SourceSamples.streamedText(in: thread)?.count ?? 0) > first.count })
    let second = try #require(SourceSamples.streamedText(in: thread))
    gate.open()
    await run.value

    #expect(SourceSamples.streamedText.hasPrefix(first))
    #expect(SourceSamples.streamedText.hasPrefix(second))
    #expect(thread.streaming.isEmpty)
    #expect(
      SourceSamples.assistantMessage(thread.item(id: SourceSamples.responseID))?.blocks
        == [ContentBlock(text: SourceSamples.streamedText)])
    #expect(thread.items.map(\.id) == session.transcript.map(\.id))
    #expect(thread.state == .idle(nil))
  }

  @Test func aStreamWithAToolCallStampsTheCallAndKeepsTheOrder() async throws {
    let clock = TickingClock()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: SourceSamples.toolTurn), tools: [FakeReadTool()])
    let source = SessionThreadSource(session: session, clock: clock.now)

    await source.stream(SourceSamples.prompt)

    let expected = session.transcript.compactMap { entry -> String? in
      switch entry {
      case .toolCalls: SourceSamples.toolCallID
      case .toolOutput: nil
      default: entry.id
      }
    }
    #expect(source.thread.items.map(\.id) == expected)
    let call = try #require(SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID)))
    let startedAt = try #require(call.startedAt)
    let endedAt = try #require(call.endedAt)
    #expect(startedAt <= endedAt)
  }

  // MARK: - Errors

  @Test func aContextSizeExceededErrorBecomesAnErrorItemWithBothCounts() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [
        [
          .text(entryID: SourceSamples.responseID, text: "Partial"),
          .contextSizeExceeded(
            contextSize: SourceSamples.contextSize, tokenCount: SourceSamples.tokenCount),
        ]
      ]))
    let source = SessionThreadSource(session: session)

    await source.stream(SourceSamples.prompt)

    let errorID = SessionThreadSource.errorIDPrefix + "1"
    #expect(
      SourceSamples.errorKind(source.thread.item(id: errorID))
        == .contextSizeExceeded(
          contextSize: SourceSamples.contextSize, tokenCount: SourceSamples.tokenCount))
    #expect(source.thread.items.map(\.id) == session.transcript.map(\.id) + [errorID])
    #expect(source.thread.streaming.isEmpty)
    #expect(source.thread.state == .idle(nil))
  }

  @Test func aToolCallErrorMarksTheCallFailed() async throws {
    let clock = TickingClock()
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: SourceSamples.toolTurn), tools: [FakeFailingTool()])
    session.transcriptErrorHandlingPolicy = .preserveTranscript
    let source = SessionThreadSource(session: session, clock: clock.now)
    defer { source.stop() }
    source.start()

    do {
      try await session.respond(to: SourceSamples.prompt)
      Issue.record("The session did not throw.")
    } catch {
      #expect(await waitUntil { source.thread.item(id: SourceSamples.toolCallID) != nil })
      source.report(error)
    }

    let call = try #require(SourceSamples.toolCall(source.thread.item(id: SourceSamples.toolCallID)))
    #expect(call.status == .failed)
    let startedAt = try #require(call.startedAt)
    let endedAt = try #require(call.endedAt)
    #expect(startedAt <= endedAt)
    guard case .unknown = SourceSamples.errorKind(source.thread.items.last) else {
      Issue.record("The last item is not an unknown error.")
      return
    }
  }

  // MARK: - Usage

  @Test func usageFillsTheTokenCountsAndTheContextWindowAndKeepsTheCost() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: SourceSamples.responseID, text: "Hello")]]))
    let window = ContextWindow(
      size: { SourceSamples.windowSize },
      tokenCount: { transcript in transcript.count * SourceSamples.tokensPerEntry })
    let source = SessionThreadSource(session: session, contextWindow: window)
    source.thread.apply(.setUsage(ContextUsage(used: 0, size: 0, cost: SourceSamples.cost)))

    await source.stream(SourceSamples.prompt)

    let used = session.transcript.count * SourceSamples.tokensPerEntry
    #expect(await waitUntil { source.thread.usage?.used == used })
    let usage = try #require(source.thread.usage)
    #expect(usage.size == SourceSamples.windowSize)
    #expect(usage.cost == SourceSamples.cost)
    #expect(usage.output?.total == session.usage.output.totalTokenCount)
    #expect(usage.input?.total == session.usage.input.totalTokenCount)
  }

  @Test func usageWithNoContextWindowHasNoFill() async throws {
    let session = LanguageModelSession(
      model: FakeLanguageModel(rounds: [[.text(entryID: SourceSamples.responseID, text: "Hello")]]))
    let source = SessionThreadSource(session: session)

    await source.stream(SourceSamples.prompt)

    let usage = try #require(source.thread.usage)
    #expect(usage.used == 0)
    #expect(usage.size == 0)
    #expect(usage.output?.total == session.usage.output.totalTokenCount)
  }

  @Test func theSystemContextWindowGivesTheContextSizeOfTheModel() async throws {
    let window = ContextWindow.system()

    #expect(try await window.size() == SystemLanguageModel.default.contextSize)
  }
}
