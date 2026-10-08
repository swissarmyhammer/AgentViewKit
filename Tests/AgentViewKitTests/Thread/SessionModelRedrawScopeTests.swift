#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The redraw scope of the thread view when many chunks stream into one
  /// agent message of a `SessionModel` (update.md §7 item 2).
  ///
  /// The session model coalesces the chunks at
  /// `SessionModel.defaultCoalescingCadence`. Each row binds directly to its
  /// `TranscriptEntry` object, so a flush evaluates the row of the streamed
  /// entry only. `Benchmarks/` measures the time of the same path.
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionModelRedrawScopeTests {
    /// The longest time that the test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row of the test.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The number of agent messages in the transcript.
    static let rowCount = 10

    /// The position of the agent message that the chunks stream into: the
    /// last row, as in a live turn.
    static let streamedPosition = rowCount - 1

    /// The number of chunks that stream into the agent message.
    static let streamedChunkCount = 100

    /// The `messageId` of the agent message at `position`.
    ///
    /// - Parameter position: The position of the message in the transcript.
    /// - Returns: The `messageId`.
    static func messageID(at position: Int) -> String {
      "scope-m\(position)"
    }

    /// The text of the first chunk of the agent message at `position`.
    ///
    /// - Parameter position: The position of the message in the transcript.
    /// - Returns: The text of the chunk.
    static func firstChunk(at position: Int) -> String {
      "Message \(position)."
    }

    /// The text of the chunk at `index` of the stream.
    ///
    /// - Parameter index: The position of the chunk in the stream.
    /// - Returns: The text of the chunk.
    static func streamedChunk(at index: Int) -> String {
      " Chunk \(index)."
    }

    /// A `session/update` value with one `agent_message_chunk`.
    ///
    /// - Parameters:
    ///   - position: The position of the agent message in the transcript.
    ///   - text: The text of the chunk.
    /// - Returns: The JSON text of the update.
    static func makeChunk(position: Int, text: String) -> String {
      WireBlockJSON.makeChunk(
        "agent_message_chunk", messageID: messageID(at: position), block: WireBlockJSON.makeText(text))
    }

    /// Sets the row count and the content count of each key to zero.
    ///
    /// - Parameter keys: The row keys of the rows.
    static func resetCounts(of keys: [String]) {
      for key in keys {
        BodyEvaluationCounter.reset(ItemRow.counterKey(for: key))
        BodyEvaluationCounter.reset(ItemRow.contentCounterKey(for: key))
      }
    }

    @Test func aStreamOfChunksEvaluatesOnlyTheStreamedRowAndShowsTheEntryText() async throws {
      let session = try await ScriptedSession.open(coalescingCadence: SessionModel.defaultCoalescingCadence)
      defer { session.close() }
      let harness = HostedViewHarness(AgentThreadView(session: session.model), size: Self.tallSize)
      defer { harness.close() }
      let model = session.model
      for position in 0..<Self.rowCount {
        try await session.sendUpdate(Self.makeChunk(position: position, text: Self.firstChunk(at: position)))
      }
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.rowKeys(in: harness).count == Self.rowCount
      }
      let keys = model.transcript.map(\.id.rowKey)
      try #require(keys.count == Self.rowCount)
      Self.resetCounts(of: keys)

      for index in 0..<Self.streamedChunkCount {
        try await session.sendUpdate(Self.makeChunk(position: Self.streamedPosition, text: Self.streamedChunk(at: index)))
      }
      let expected =
        Self.firstChunk(at: Self.streamedPosition)
        + (0..<Self.streamedChunkCount).map(Self.streamedChunk(at:)).joined()
      await harness.pump(until: Self.waitTimeout) {
        SessionTranscriptViewHostedTests.entryText(of: model, at: Self.streamedPosition) == expected
      }
      harness.pump()

      let entryText = try #require(SessionTranscriptViewHostedTests.entryText(of: model, at: Self.streamedPosition))
      #expect(entryText == expected)
      let streamedKey = keys[Self.streamedPosition]
      #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: streamedKey)) >= 1)
      for key in keys where key != streamedKey {
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) == 0, "\(key)")
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: key)) == 0, "\(key)")
      }
      let labels = Set(harness.accessibilityElements().compactMap(\.label))
      let paragraphs = ParagraphSplitter.paragraphs(entryText).map(\.text)
      #expect(!paragraphs.isEmpty)
      #expect(paragraphs.allSatisfy { labels.contains($0) }, "\(paragraphs)")
      Self.resetCounts(of: keys)
    }
  }
#endif
