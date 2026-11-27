import AgentViewKitTestSupport
import CoreGraphics
import EditorTestSupport
import EditorTheme
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import os
import SwiftUI
import Testing

@testable import AgentViewKit

/// A text measure that records each part that it measures.
///
/// The height of a part is its count of characters over the width, so that
/// a new text or a new width gives a new height. The measure reports each
/// part as exact, or each part as not exact.
nonisolated final class RecordingTextMeasure: TranscriptTextMeasure {
  /// The scale of the height of a part.
  static let scale: CGFloat = 1000

  /// Whether the measure reports each part as exact.
  let reportsExact: Bool

  /// Makes a measure.
  ///
  /// - Parameter reportsExact: Whether the measure reports each part as
  ///   exact. The default is `true`.
  init(reportsExact: Bool = true) {
    self.reportsExact = reportsExact
  }

  /// The texts of the measured parts, in the order of the calls.
  private let texts = OSAllocatedUnfairLock<[String]>(initialState: [])

  /// The height of a part at a width.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width.
  /// - Returns: The height.
  static func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    CGFloat(part.text.count) * scale / width
  }

  func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    texts.withLock { $0.append(part.text) }
    return Self.height(of: part, width: width)
  }

  func isExact(_ part: TranscriptTextPart) -> Bool {
    reportsExact
  }

  /// The texts of the measured parts, in the order of the calls.
  var measuredTexts: [String] {
    texts.withLock { $0 }
  }

  /// Forgets the measured parts.
  func reset() {
    texts.withLock { $0.removeAll() }
  }
}

/// The cache of the row heights computes off the main thread, computes only
/// the rows that change, and computes the rows in view first after a width
/// change (card ^9h7bm9j).
@MainActor @Suite struct TranscriptRowHeightsTests {
  /// The first width of the tests.
  static let width: CGFloat = 480

  /// The second width of the tests.
  static let newWidth: CGFloat = 320

  /// A content chunk of one text block.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - id: The raw message id.
  /// - Returns: The chunk.
  static func chunk(_ text: String, id: String) -> ContentChunk {
    ContentChunk(content: .text(TextContent(text: text)), messageId: MessageId(rawValue: id))
  }

  /// The height that the chrome rule gives an entry with the recording
  /// measure.
  ///
  /// - Parameters:
  ///   - entry: The entry.
  ///   - width: The width.
  ///   - metrics: The theme metrics.
  /// - Returns: The height.
  static func expectedHeight(of entry: TranscriptEntry, width: CGFloat, metrics: TranscriptRowMetrics) -> CGFloat? {
    TranscriptRowChrome.height(
      of: TranscriptRowContent(entry: entry, isExpanded: false), width: width, metrics: metrics,
      measure: RecordingTextMeasure.height(of:width:))
  }

  /// Waits until the cache holds the height that the rule gives each entry.
  ///
  /// - Parameters:
  ///   - heights: The cache.
  ///   - entries: The entries.
  ///   - width: The width.
  ///   - metrics: The theme metrics.
  static func waitForEachHeight(
    in heights: TranscriptRowHeights, of entries: [TranscriptEntry], width: CGFloat, metrics: TranscriptRowMetrics,
    sourceLocation: SourceLocation = #_sourceLocation
  ) async {
    await ObservationWait.until(sourceLocation: sourceLocation) {
      entries.allSatisfy { entry in
        let expected = expectedHeight(of: entry, width: width, metrics: metrics)
        return expected != nil && heights.height(of: entry.rowKey) == expected
      }
    }
  }

  /// Sends a chunk of the agent message, and waits until the message holds it.
  ///
  /// - Parameters:
  ///   - text: The text of the chunk.
  ///   - session: The session.
  static func stream(_ text: String, to session: ScriptedSession) async throws {
    try await session.send(update: .agentMessageChunk(chunk(text, id: "agent")))
    let model = session.model
    await ObservationWait.until {
      guard case .agentMessage(let message) = model.transcript.last else { return false }
      return TranscriptRowContent.textBlocks(of: message.content)?.joined().hasSuffix(text) == true
    }
  }

  /// Sends a chunk of the agent message, and waits until the cache holds the
  /// height that the rule gives each entry of the session at ``width``.
  ///
  /// - Parameters:
  ///   - text: The text of the chunk.
  ///   - session: The session.
  ///   - cache: The cache of the rows of the session.
  static func streamAndSettle(_ text: String, in session: ScriptedSession, cache: SettledHeights) async throws {
    try await stream(text, to: session)
    await waitForEachHeight(in: cache.heights, of: session.model.transcript, width: width, metrics: cache.metrics)
  }

  /// Opens a session with a user message and an agent message.
  static func openSession() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.send(update: .userMessageChunk(chunk("A question about the heights.", id: "user")))
    try await session.send(update: .agentMessageChunk(chunk("The first part of the answer.", id: "agent")))
    let model = session.model
    await ObservationWait.until { model.transcript.count == 2 }
    return session
  }

  /// A cache of the row heights with a recording measure, after the cache
  /// holds the height of each entry that a rule covers.
  struct SettledHeights {
    /// The cache.
    let heights: TranscriptRowHeights

    /// The theme metrics of the cache.
    let metrics: TranscriptRowMetrics

    /// The measure of the cache.
    let measure: RecordingTextMeasure

    /// The cache, as the height provider of the static rows.
    var provider: any TranscriptRowHeightProvider {
      heights
    }
  }

  /// Makes a cache with a recording measure, gives it each entry at
  /// ``width`` with each row in view, and waits until the cache holds the
  /// height that the rule gives each entry that a rule covers.
  ///
  /// - Parameter entries: The entries.
  /// - Returns: The cache.
  static func settledHeights(of entries: [TranscriptEntry]) async -> SettledHeights {
    let metrics = TranscriptRowMetrics.probe()
    let measure = RecordingTextMeasure()
    let heights = TranscriptRowHeights(measure: measure, metrics: metrics)
    heights.update(entries: entries, width: width, rowsInView: entries.indices)
    let covered = entries.filter { expectedHeight(of: $0, width: width, metrics: metrics) != nil }
    await waitForEachHeight(in: heights, of: covered, width: width, metrics: metrics)
    return SettledHeights(heights: heights, metrics: metrics, measure: measure)
  }

  /// Opens a session with ``openSession()``, runs `body`, and closes the
  /// session.
  ///
  /// - Parameter body: The test body.
  static func withSession(_ body: (ScriptedSession) async throws -> Void) async throws {
    let session = try await openSession()
    defer { session.close() }
    try await body(session)
  }

  /// Opens a session with ``openSession()``, makes a settled cache of its
  /// rows, runs `body`, and closes the session.
  ///
  /// - Parameter body: The test body.
  static func withSettledSession(_ body: (ScriptedSession, SettledHeights) async throws -> Void) async throws {
    try await withSession { session in
      try await body(session, await settledHeights(of: session.model.transcript))
    }
  }

  @Test func aStreamedChunkMeasuresOnlyTheStreamingRow() async throws {
    try await Self.withSettledSession { session, cache in
      cache.measure.reset()

      try await Self.streamAndSettle(" And the rest of it.", in: session, cache: cache)

      #expect(!cache.measure.measuredTexts.contains { $0.contains("question") })
    }
  }

  @Test func aStreamedChunkGivesTheStreamingRowItsNewHeight() async throws {
    try await Self.withSettledSession { session, cache in
      let agentKey = try #require(session.model.transcript.last?.rowKey)
      let before = cache.heights.height(of: agentKey)

      try await Self.streamAndSettle(" And the rest of it.", in: session, cache: cache)

      #expect(cache.heights.height(of: agentKey) != before)
    }
  }

  #if DEBUG
    @Test func aStreamedChunkCopiesNoOtherRowOnTheMainThread() async throws {
      try await Self.withSettledSession { session, cache in
        let userKey = try #require(session.model.transcript.first?.rowKey)
        let counterKey = TranscriptRowHeights.copyCounterKey(for: userKey)
        let copies = BodyEvaluationCounter.count(counterKey)

        try await Self.streamAndSettle(" And the rest of it.", in: session, cache: cache)
        let entries = session.model.transcript
        cache.heights.update(entries: entries, width: Self.width, rowsInView: entries.indices)

        #expect(BodyEvaluationCounter.count(counterKey) == copies)
      }
    }
  #endif

  @Test func anUpdateWithNoChangeMeasuresNothing() async throws {
    try await Self.withSettledSession { session, cache in
      cache.measure.reset()

      let entries = session.model.transcript
      cache.heights.update(entries: entries, width: Self.width, rowsInView: entries.indices)
      try await Self.streamAndSettle(" More.", in: session, cache: cache)

      #expect(cache.measure.measuredTexts.allSatisfy { $0.contains("answer") })
    }
  }

  @Test func aWidthChangeMeasuresTheRowsInViewFirst() async throws {
    try await Self.withSettledSession { session, cache in
      cache.measure.reset()
      let entries = session.model.transcript

      cache.heights.update(entries: entries, width: Self.newWidth, rowsInView: entries.indices.suffix(1))
      await Self.waitForEachHeight(in: cache.heights, of: entries, width: Self.newWidth, metrics: cache.metrics)

      #expect(cache.measure.measuredTexts.first?.contains("answer") == true)
      #expect(cache.measure.measuredTexts.contains { $0.contains("question") })
    }
  }

  // MARK: - Height provider of the static rows

  @Test func theProviderGivesTheCachedHeightAtTheWidthOfTheCache() async throws {
    try await Self.withSettledSession { session, cache in
      let entry = try #require(session.model.transcript.last)

      #expect(
        cache.provider.height(of: entry.id, width: Self.width)
          == Self.expectedHeight(of: entry, width: Self.width, metrics: cache.metrics))
    }
  }

  @Test func theProviderGivesNoHeightAtAnotherWidth() async throws {
    try await Self.withSettledSession { session, cache in
      let entry = try #require(session.model.transcript.last)

      #expect(cache.provider.height(of: entry.id, width: Self.newWidth) == nil)
    }
  }

  @Test func theProviderKnowsTheHeightOfACachedRow() async throws {
    try await Self.withSettledSession { session, cache in
      let entry = try #require(session.model.transcript.first)

      #expect(cache.provider.knowsHeight(of: entry.id))
    }
  }

  @Test func theProviderKnowsNoHeightOfARowThatNoRuleCovers() async throws {
    try await Self.withSession { session in
      let unknown = try TranscriptRowHeightBed.entry([
        .update(.agentMessageChunk(ContentChunk(content: .unknown("x", .null), messageId: MessageId(rawValue: "x"))))
      ])
      let cache = await Self.settledHeights(of: session.model.transcript + [unknown])

      #expect(!cache.provider.knowsHeight(of: unknown.id))
    }
  }

  @Test func theProviderKnowsNoHeightOfARowWithAPartThatIsNotExact() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let metrics = TranscriptRowMetrics.probe()
    let heights = TranscriptRowHeights(measure: RecordingTextMeasure(reportsExact: false), metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
    let entry = try #require(model.transcript.last)

    #expect(!(heights as any TranscriptRowHeightProvider).knowsHeight(of: entry.id))
  }

  // MARK: - The heights of the static rows of a thread

  /// The heights of the static rows of `session`, with a cache of the
  /// recording measure, at ``width``.
  ///
  /// - Parameter session: The session.
  /// - Returns: The heights and their cache.
  static func staticRowHeights(of session: ScriptedSession) -> (TranscriptStaticRowHeights, TranscriptRowHeights) {
    let cache = TranscriptRowHeights(measure: RecordingTextMeasure(), metrics: TranscriptRowMetrics.probe())
    let heights = TranscriptStaticRowHeights()
    heights.attach(cache: cache, session: session.model)
    heights.noteRowWidth(width)
    return (heights, cache)
  }

  /// Sends a new user message, and waits until the transcript holds it.
  ///
  /// - Parameter session: The session.
  static func appendUserMessage(to session: ScriptedSession) async throws {
    try await session.send(update: .userMessageChunk(chunk("A second question.", id: "user-2")))
    let model = session.model
    await ObservationWait.until { model.transcript.count == 3 }
  }

  @Test func theStaticRowsTakeTheCacheHeightOfAnEntryThatTheTranscriptAppends() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let (heights, cache) = Self.staticRowHeights(of: session)
    let metrics = TranscriptRowMetrics.probe()

    try await Self.appendUserMessage(to: session)
    let model = session.model
    await Self.waitForEachHeight(in: cache, of: model.transcript, width: Self.width, metrics: metrics)
    let entry = try #require(model.transcript.last)

    #expect(heights.knowsHeight(of: entry.id))
  }

  @Test func theStaticRowsGiveTheRecordedHeightOfARowThatTheCacheDoesNotKnow() {
    let heights = TranscriptStaticRowHeights()
    let id = TranscriptEntry.ID.local(UUID())
    heights.record(CGSize(width: Self.width, height: Self.newWidth), for: id)

    #expect(heights.height(of: id, width: Self.width) == Self.newWidth)
  }

  @Test func aThreadWithNoStoreOfTheExpandedBlocksHasNoCache() {
    #expect(
      TranscriptStaticRowHeights.makeCache(
        theme: SystemTheme(), expandedBlocks: nil, hasDefaultLook: true, imageFolder: nil) == nil)
  }

  @Test func aThreadWhoseRowsDoNotHaveTheDefaultLookHasNoCache() {
    let cache = TranscriptStaticRowHeights.makeCache(
      theme: SystemTheme(), expandedBlocks: ExpandedBlocksStore(), hasDefaultLook: false, imageFolder: nil)

    #expect(cache == nil)
  }

  @Test func theRowsHaveTheDefaultLookInAnEnvironmentWithNoOverride() {
    #expect(EnvironmentValues().transcriptRowsHaveDefaultLook)
  }

  @Test func anItemViewOverrideEndsTheDefaultLook() {
    var environment = EnvironmentValues()
    environment.planViewOverride = { _ in AnyView(EmptyView()) }

    #expect(!environment.transcriptRowsHaveDefaultLook)
  }

  @Test func theTimeOfTheEntriesEndsTheDefaultLook() {
    var environment = EnvironmentValues()
    environment.showsTranscriptTiming = true

    #expect(!environment.transcriptRowsHaveDefaultLook)
  }

  @Test func aRegisteredToolCallViewEndsTheDefaultLook() {
    var environment = EnvironmentValues()
    environment.toolCallRegistry.register("read") { _ in AnyView(EmptyView()) }

    #expect(!environment.transcriptRowsHaveDefaultLook)
  }

  #if DEBUG
    @Test func anAppendedEntryCopiesNoUnchangedRowOnTheMainThread() async throws {
      let session = try await Self.openSession()
      defer { session.close() }
      let (heights, cache) = Self.staticRowHeights(of: session)
      defer { withExtendedLifetime(heights) {} }
      let model = session.model
      let metrics = TranscriptRowMetrics.probe()
      await Self.waitForEachHeight(in: cache, of: model.transcript, width: Self.width, metrics: metrics)
      let counterKey = TranscriptRowHeights.copyCounterKey(for: try #require(model.transcript.first?.rowKey))
      let copies = BodyEvaluationCounter.count(counterKey)

      try await Self.appendUserMessage(to: session)
      await Self.waitForEachHeight(in: cache, of: model.transcript, width: Self.width, metrics: metrics)

      #expect(BodyEvaluationCounter.count(counterKey) == copies)
    }
  #endif
}
