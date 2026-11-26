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

  /// Opens a session with a user message and an agent message.
  static func openSession() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.send(update: .userMessageChunk(chunk("A question about the heights.", id: "user")))
    try await session.send(update: .agentMessageChunk(chunk("The first part of the answer.", id: "agent")))
    let model = session.model
    await ObservationWait.until { model.transcript.count == 2 }
    return session
  }

  @Test func aStreamedChunkMeasuresOnlyTheStreamingRow() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let metrics = TranscriptRowMetrics.probe()
    let measure = RecordingTextMeasure()
    let heights = TranscriptRowHeights(measure: measure, metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
    measure.reset()

    try await Self.stream(" And the rest of it.", to: session)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)

    #expect(!measure.measuredTexts.contains { $0.contains("question") })
  }

  @Test func aStreamedChunkGivesTheStreamingRowItsNewHeight() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let metrics = TranscriptRowMetrics.probe()
    let heights = TranscriptRowHeights(measure: RecordingTextMeasure(), metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
    let agentKey = try #require(model.transcript.last?.rowKey)
    let before = heights.height(of: agentKey)

    try await Self.stream(" And the rest of it.", to: session)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)

    #expect(heights.height(of: agentKey) != before)
  }

  #if DEBUG
    @Test func aStreamedChunkCopiesNoOtherRowOnTheMainThread() async throws {
      let session = try await Self.openSession()
      defer { session.close() }
      let metrics = TranscriptRowMetrics.probe()
      let heights = TranscriptRowHeights(measure: RecordingTextMeasure(), metrics: metrics)
      let model = session.model
      let userKey = try #require(model.transcript.first?.rowKey)
      let counterKey = TranscriptRowHeights.copyCounterKey(for: userKey)
      heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
      await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
      let copies = BodyEvaluationCounter.count(counterKey)

      try await Self.stream(" And the rest of it.", to: session)
      await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
      heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)

      #expect(BodyEvaluationCounter.count(counterKey) == copies)
    }
  #endif

  @Test func anUpdateWithNoChangeMeasuresNothing() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let metrics = TranscriptRowMetrics.probe()
    let measure = RecordingTextMeasure()
    let heights = TranscriptRowHeights(measure: measure, metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
    measure.reset()

    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    try await Self.stream(" More.", to: session)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)

    #expect(measure.measuredTexts.allSatisfy { $0.contains("answer") })
  }

  @Test func aWidthChangeMeasuresTheRowsInViewFirst() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let metrics = TranscriptRowMetrics.probe()
    let measure = RecordingTextMeasure()
    let heights = TranscriptRowHeights(measure: measure, metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: Self.width, rowsInView: 0..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.width, metrics: metrics)
    measure.reset()

    heights.update(entries: model.transcript, width: Self.newWidth, rowsInView: 1..<2)
    await Self.waitForEachHeight(in: heights, of: model.transcript, width: Self.newWidth, metrics: metrics)

    #expect(measure.measuredTexts.first?.contains("answer") == true)
    #expect(measure.measuredTexts.contains { $0.contains("question") })
  }

  // MARK: - Height provider of the static rows

  /// A cache with the heights of the rows of `session` at ``width``.
  ///
  /// - Parameter session: The session.
  /// - Returns: The cache, as the provider of the static rows.
  static func provider(of session: ScriptedSession) async -> any TranscriptRowHeightProvider {
    let metrics = TranscriptRowMetrics.probe()
    let heights = TranscriptRowHeights(measure: RecordingTextMeasure(), metrics: metrics)
    let model = session.model
    heights.update(entries: model.transcript, width: width, rowsInView: 0..<2)
    await waitForEachHeight(in: heights, of: model.transcript, width: width, metrics: metrics)
    return heights
  }

  @Test func theProviderGivesTheCachedHeightAtTheWidthOfTheCache() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let provider = await Self.provider(of: session)
    let entry = try #require(session.model.transcript.last)
    let metrics = TranscriptRowMetrics.probe()

    #expect(
      provider.height(of: entry.id, width: Self.width)
        == Self.expectedHeight(of: entry, width: Self.width, metrics: metrics))
  }

  @Test func theProviderGivesNoHeightAtAnotherWidth() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let provider = await Self.provider(of: session)
    let entry = try #require(session.model.transcript.last)

    #expect(provider.height(of: entry.id, width: Self.newWidth) == nil)
  }

  @Test func theProviderKnowsTheHeightOfACachedRow() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let provider = await Self.provider(of: session)
    let entry = try #require(session.model.transcript.first)

    #expect(provider.knowsHeight(of: entry.id))
  }

  @Test func theProviderKnowsNoHeightOfARowThatNoRuleCovers() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let unknown = try #require(
      SessionModel.preview(
        transcript: [
          .update(.agentMessageChunk(ContentChunk(content: .unknown("x", .null), messageId: MessageId(rawValue: "x"))))
        ]
      ).transcript.first)
    let metrics = TranscriptRowMetrics.probe()
    let heights = TranscriptRowHeights(measure: RecordingTextMeasure(), metrics: metrics)
    let entries = session.model.transcript + [unknown]
    heights.update(entries: entries, width: Self.width, rowsInView: 0..<3)
    await Self.waitForEachHeight(in: heights, of: session.model.transcript, width: Self.width, metrics: metrics)

    #expect(!(heights as any TranscriptRowHeightProvider).knowsHeight(of: unknown.id))
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
      TranscriptStaticRowHeights.makeCache(theme: SystemTheme(), expandedBlocks: nil, hasDefaultLook: true) == nil)
  }

  @Test func aThreadWhoseRowsDoNotHaveTheDefaultLookHasNoCache() {
    let cache = TranscriptStaticRowHeights.makeCache(
      theme: SystemTheme(), expandedBlocks: ExpandedBlocksStore(), hasDefaultLook: false)

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
