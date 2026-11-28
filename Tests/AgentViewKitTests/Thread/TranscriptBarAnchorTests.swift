import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The rows in view of a thread with bars keep their place when the rows
/// under the top bar get their heights (card ^6fax5yx).
///
/// The virtual stack mounts the rows under the bars, and a row that gets
/// its height there moves the offset of the list, so the rows in view do
/// not jump. The scroll view gives the heights of the bars as its content
/// insets. The test shows a ``MovingThread`` of answers of different
/// heights with clear bars of ``TranscriptBarBandTests/barHeight``.
@MainActor @Suite(.serialized) struct TranscriptBarAnchorTests {
  /// The number of answers in the transcript: many more than the rows in
  /// view.
  static let answerCount = 120

  /// The position of the answer of the jump: far from the bottom, so the
  /// rows near it have no known height before the jump.
  static let jumpIndex = 30

  /// The distance of the scroll up at rest, in points: less than the
  /// height of the part between the bars (300), so the last row in view
  /// before the scroll stays in view.
  static let stepDistance: CGFloat = 100

  /// The largest difference, in points, that the test counts as no
  /// difference. A layout rounds to the pixel.
  static let tolerance: CGFloat = 1

  /// The largest distance, in points, from the bottom of the top bar to
  /// the top of the text of the row of a jump: the padding of the row
  /// above its text.
  static let rowTextInset: CGFloat = 40

  /// The list of answers with the bars, at the bottom.
  ///
  /// - Returns: The list.
  static func thread() throws -> MovingThread {
    let thread = try MovingThread(
      session: .preview(transcript: (0..<answerCount).map { .agent(TranscriptRowAnchorTests.answer($0)) }),
      frames: TranscriptDisplayLinkFrames(), barHeight: TranscriptBarBandTests.barHeight)
    thread.settle()
    return thread
  }

  /// The text view of the answer at an index.
  ///
  /// - Parameters:
  ///   - index: The index of the answer.
  ///   - thread: The list.
  /// - Returns: The text view.
  static func text(ofAnswer index: Int, in thread: MovingThread) throws -> NSTextView {
    try #require(thread.textViews.first { $0.string == TranscriptRowAnchorTests.answer(index) })
  }

  /// A production change that fails this test: the stack moves the offset
  /// in the coordinates of the content offset, and not in the coordinates
  /// of the scroll position, which start below the top content inset, so
  /// the rows in view jump by the height of the top bar.
  @Test func aRowInViewMovesOnlyByTheScrollWhenTheRowsUnderTheBarGetTheirHeights() throws {
    let thread = try Self.thread()
    thread.scrollAtRest(to: thread.scrollView.contentView.bounds.origin.y / 2)
    let lastKeyInView = try #require(thread.anchors.visibleIDs.last)
    let index = try #require(thread.session.transcript.firstIndex { $0.rowKey == lastKeyInView })
    let text = try Self.text(ofAnswer: index, in: thread)
    let before = TranscriptRowAnchorTests.windowY(of: text)

    thread.scrollAtRest(to: thread.scrollView.contentView.bounds.origin.y - Self.stepDistance)

    let moved = before - TranscriptRowAnchorTests.windowY(of: text)
    #expect(abs(moved - Self.stepDistance) <= Self.tolerance, "the row moved by \(moved)")
  }

  /// A production change that fails this test: each move of the offset
  /// after a jump lands above its target by the height of the top bar, the
  /// move brings new rows under the bar, and their heights move the offset
  /// again, so the list goes up to the top of the transcript.
  @Test func aJumpToAnItemStaysOnTheItemWhenTheRowsUnderTheBarGetTheirHeights() async throws {
    let thread = try Self.thread()
    let key = thread.session.transcript[Self.jumpIndex].rowKey

    await thread.jumpAtRest(to: key)

    let text = try Self.text(ofAnswer: Self.jumpIndex, in: thread)
    let textTop = text.convert(text.bounds, to: nil).maxY
    let barBottom = thread.window.frame.height - TranscriptBarBandTests.barHeight
    #expect(barBottom - Self.rowTextInset...barBottom ~= textTop, "the text of the item is at \(textTop)")
  }
}
