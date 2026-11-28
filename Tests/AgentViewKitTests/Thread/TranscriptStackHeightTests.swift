import AppKit
import EditorStyle
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The virtual stack of a thread has the exact height of its rows, and each
/// row in view draws in its own slot (card ^kr7cx7b).
///
/// The test shows a ``MovingThread`` with the height cache of a thread and
/// rows of each kind: Markdown, a code block, a tool call, a diff and a
/// thought. The height of the list is the sum of the exact heights of the
/// rows in the cache (``TranscriptRowHeights``), the spacing between the
/// rows, the top inset of the list and the bottom padding of the last row.
/// A row in view at rest has its real layout, and that layout fills its slot:
/// its top is at the prefix sum of the rows before it, and its height is its
/// exact height. Thus no row is cut, and no row overlaps the next row.
@MainActor @Suite(.serialized) struct TranscriptStackHeightTests {
  /// The row kinds of the transcript, in the order of one round.
  nonisolated static let kinds: [TranscriptRowFixtures.Row] = [.agentProse, .agentFenced, .toolCall, .diff, .thought]

  /// The number of rounds of the row kinds: more rows than the list shows
  /// at one time, so most rows are out of view and have no layout.
  static let roundCount = 4

  /// The round whose row of a kind the test shows in view: a round in the
  /// middle of the transcript, with rows above and below it.
  static let shownRound = 2

  /// The largest difference, in points, that the test counts as no
  /// difference. A layout rounds to the pixel.
  static let tolerance: CGFloat = 1

  /// The transcript: ``roundCount`` rounds of the row kinds.
  static var transcript: [PreviewTranscriptItem] {
    (0..<roundCount).flatMap { _ in kinds.map(\.item) }
  }

  /// The style of the list, which gives its spacing and its insets.
  static let style = EditorStyle.default

  /// The exact height of each row of a list, in the order of the rows, from
  /// the height cache of the list.
  ///
  /// - Parameter thread: The list.
  /// - Returns: The heights.
  static func exactHeights(of thread: MovingThread) throws -> [CGFloat] {
    let cache = try #require(thread.heights.cache, "the list has no height cache")
    return try thread.session.transcript.map { entry in
      try #require(cache.height(of: entry.id, width: cache.width), "the cache has no height of \(entry.rowKey)")
    }
  }

  /// The top of each row in the content of a list, from the exact heights:
  /// the top inset of the list, and the prefix sums of the heights and the
  /// spacings of the rows before the row.
  ///
  /// - Parameter heights: The exact height of each row.
  /// - Returns: The tops.
  static func slotTops(of heights: [CGFloat]) -> [CGFloat] {
    heights.indices.map { row in
      style.rowPadding + heights[..<row].reduce(.zero, +) + CGFloat(row) * style.tile.margin
    }
  }

  /// The height of the content of a list from the exact heights: the top
  /// inset, the rows, the spacings between them and the bottom padding of
  /// the last row.
  ///
  /// - Parameter heights: The exact height of each row.
  /// - Returns: The height.
  static func contentHeight(of heights: [CGFloat]) -> CGFloat {
    style.rowPadding + heights.reduce(.zero, +) + CGFloat(heights.count - 1) * style.tile.margin + style.rowPadding
  }

  /// A production change that fails this test: the stack gives a row out of
  /// view an estimate in place of its exact height, or it leaves out the
  /// spacing between two rows, so the list is too short or too tall, and a
  /// scroll to an offset shows other rows.
  @Test func theHeightOfTheListIsTheSumOfTheExactRowHeights() async throws {
    let thread = try await MovingThread.makeCached(session: .preview(transcript: Self.transcript), frames: ManualFrames())
    let expected = Self.contentHeight(of: try Self.exactHeights(of: thread))

    let height = try #require(thread.scrollView.documentView).frame.height

    #expect(abs(height - expected) <= Self.tolerance, "list \(height), rows \(expected)")
  }

  /// A production change that fails this test: the real layout of a row
  /// has another height than its exact height, so the row is cut by the
  /// row after it, or it leaves a gap, and the list changes its height and
  /// moves the rows in view when the row becomes real.
  ///
  /// The stack places each row at the prefix sum of the heights before it,
  /// and a real row in view gives its layout height to the geometry. Thus
  /// the list keeps the height of the exact rows only when each real row in
  /// view fills its slot.
  @Test(arguments: kinds)
  func aRealRowInViewFillsItsExactSlot(kind: TranscriptRowFixtures.Row) async throws {
    let thread = try await MovingThread.makeCached(session: .preview(transcript: Self.transcript), frames: ManualFrames())
    let heights = try Self.exactHeights(of: thread)
    let kindIndex = try #require(Self.kinds.firstIndex(of: kind))
    let row = Self.shownRound * Self.kinds.count + kindIndex
    thread.scrollAtRest(to: Self.slotTops(of: heights)[row] - thread.scrollView.contentInsets.top)
    try #require(thread.rowKeysInView.contains(thread.session.transcript[row].rowKey), "the row is not in view")
    try #require(!thread.textViewsInView.isEmpty, "no row in view is real")

    let height = try #require(thread.scrollView.documentView).frame.height

    let expected = Self.contentHeight(of: heights)
    #expect(abs(height - expected) <= Self.tolerance, "list \(height), rows \(expected)")
  }
}
