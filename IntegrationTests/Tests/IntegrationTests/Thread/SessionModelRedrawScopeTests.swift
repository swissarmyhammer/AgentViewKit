#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorSwiftUI
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The redraw scope of the thread view when many chunks stream into one
  /// agent message of a `SessionModel` (plan.md §8, §14 R4).
  ///
  /// The session model coalesces the chunks at
  /// `SessionModel.defaultCoalescingCadence`. Each row binds directly to its
  /// `TranscriptEntry` object, so a flush evaluates the row of the streamed
  /// entry only, and changes only the EditorKit model of the text block of
  /// that entry. The models are in a ``CodeBlockModelCache`` of the
  /// environment, so the test reads them.
  ///
  /// The mount makes its body evaluations in the render pass after the model
  /// has each row, before the reset of the counters. Then the test waits for
  /// the whole text of the streamed entry, which the last flush is certain to
  /// give, and makes one render pass before it reads the counts.
  @Suite(.serialized, .hostedSerially) @MainActor struct SessionModelRedrawScopeTests {
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
        "agent_message_chunk", messageID: messageID(at: position),
        block: WireBlockJSON.makeText(text))
    }

    /// The model of the text block of the row `key` in `cache`.
    ///
    /// - Parameters:
    ///   - key: The row key of an agent message with one text block.
    ///   - cache: The cache of the thread.
    /// - Returns: The model, or `nil` when the cache has none.
    static func model(ofRow key: String, in cache: CodeBlockModelCache) -> EditorModel? {
      ResponseTextChecks.model(of: EntryContentView.blockID(entryID: key, index: 0), in: cache)
    }

    /// Sets the row count and the content count of each key to zero.
    ///
    /// - Parameter keys: The row keys of the rows.
    static func resetCounts(of keys: [String]) {
      BodyEvaluationCounter.reset(keys.map(ItemRow.counterKey(for:)))
      BodyEvaluationCounter.reset(keys.map(ItemRow.contentCounterKey(for:)))
    }

    @Test func aStreamOfChunksEvaluatesOnlyTheStreamedRowAndShowsTheEntryText() async throws {
      let session = try await ScriptedSession.open(
        coalescingCadence: SessionModel.defaultCoalescingCadence)
      defer { session.close() }
      let cache = CodeBlockModelCache()
      let harness = HostedViewHarness(
        AgentThreadView(session: session.model).environment(\.codeBlockModelCache, cache),
        size: Self.tallSize)
      defer { harness.close() }
      let model = session.model
      for position in 0..<Self.rowCount {
        try await session.sendUpdate(
          Self.makeChunk(position: position, text: Self.firstChunk(at: position)))
      }
      await harness.renderAfter { model.transcript.count == Self.rowCount }
      let keys = model.transcript.map(\.id.rowKey)
      try #require(keys.count == Self.rowCount)
      #expect(SessionTranscriptViewHostedTests.rowKeys(in: harness) == keys)
      let models = try keys.map { try #require(Self.model(ofRow: $0, in: cache)) }
      let versions = models.map(\.state.version)
      Self.resetCounts(of: keys)

      for index in 0..<Self.streamedChunkCount {
        try await session.sendUpdate(
          Self.makeChunk(position: Self.streamedPosition, text: Self.streamedChunk(at: index)))
      }
      let expected =
        Self.firstChunk(at: Self.streamedPosition)
        + (0..<Self.streamedChunkCount).map(Self.streamedChunk(at:)).joined()
      await harness.renderAfter {
        SessionTranscriptViewHostedTests.entryText(of: model, at: Self.streamedPosition) == expected
      }

      let entryText = try #require(
        SessionTranscriptViewHostedTests.entryText(of: model, at: Self.streamedPosition))
      #expect(entryText == expected)
      let streamedKey = keys[Self.streamedPosition]
      #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: streamedKey)) >= 1)
      for key in keys where key != streamedKey {
        #expect(BodyEvaluationCounter.count(ItemRow.contentCounterKey(for: key)) == 0, "\(key)")
        #expect(BodyEvaluationCounter.count(ItemRow.counterKey(for: key)) == 0, "\(key)")
      }
      for (position, model) in models.enumerated() where position != Self.streamedPosition {
        #expect(model.state.version == versions[position], "\(keys[position])")
      }
      #expect(models[Self.streamedPosition].text == expected)
      #expect(ResponseTextChecks.texts(in: harness).contains(expected))
      Self.resetCounts(of: keys)
    }
  }
#endif
