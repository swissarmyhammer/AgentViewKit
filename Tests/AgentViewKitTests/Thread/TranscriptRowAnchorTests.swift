import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A row in view of a thread keeps its place when the rows above it get
/// their heights (card ^kr7cx7b).
///
/// The virtual stack of the rows gives a row with no known height an
/// estimate. When the row comes into view at the top, it gets the height of
/// its layout, and the stack moves the offset by the change, so the rows in
/// view below it do not jump. The test shows a
/// ``MovingThread`` of answers of different heights, scrolls it at rest to
/// the middle, and then scrolls it up by ``stepDistance``. The text of a row
/// in view moves by the distance of the scroll and no more.
@MainActor @Suite(.serialized) struct TranscriptRowAnchorTests {
  /// The number of answers in the transcript: many more than the rows in
  /// view.
  static let answerCount = 120

  /// The distance of the scroll up at rest, in points: less than the
  /// height of the list (600), so the last row in view before the scroll
  /// stays in view.
  static let stepDistance: CGFloat = 150

  /// The largest difference, in points, that the test counts as no
  /// difference. A layout rounds to the pixel.
  static let tolerance: CGFloat = 1

  /// The number of different answer heights, in lines.
  static let lineCounts = 5

  /// The text of the answer at `index`: one to ``lineCounts`` paragraphs,
  /// so no two neighbor rows have the estimated height.
  ///
  /// - Parameter index: The index of the answer.
  /// - Returns: The text.
  static func answer(_ index: Int) -> String {
    (0...(index % lineCounts)).map { "Anchor answer \(index), paragraph \($0)." }.joined(separator: "\n\n")
  }

  /// The vertical place of a view in its window.
  ///
  /// - Parameter view: The view.
  /// - Returns: The bottom of the view in window coordinates.
  static func windowY(of view: NSView) -> CGFloat {
    view.convert(view.bounds, to: nil).minY
  }

  /// A production change that fails this test: the stack does not move the
  /// offset when a row above the view gets its height, or it moves the
  /// offset in the wrong unit, so the rows in view jump by the change.
  @Test func aRowInViewMovesOnlyByTheScrollWhenTheRowsAboveGetTheirHeights() async throws {
    let thread = try MovingThread(
      session: .preview(transcript: (0..<Self.answerCount).map { .agent(Self.answer($0)) }))
    thread.settle()
    thread.scrollAtRest(to: thread.scrollView.contentView.bounds.origin.y / 2)
    let lastKeyInView = try #require(thread.anchors.visibleIDs.last)
    let index = try #require(thread.session.transcript.firstIndex { $0.rowKey == lastKeyInView })
    let text = try #require(thread.textViews.first { $0.string == Self.answer(index) })
    let before = Self.windowY(of: text)

    thread.scrollAtRest(to: thread.scrollView.contentView.bounds.origin.y - Self.stepDistance)

    let moved = before - Self.windowY(of: text)
    #expect(abs(moved - Self.stepDistance) <= Self.tolerance, "the row moved by \(moved)")
  }
}
