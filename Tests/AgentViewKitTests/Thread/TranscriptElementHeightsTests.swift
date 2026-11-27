import CoreGraphics
import Foundation
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The height that the virtual stack of a thread gives one row element: the
/// height of its live layout, else the exact height of the cache, else the
/// height of its last layout, else an estimate (card ^kr7cx7b).
@MainActor @Suite struct TranscriptElementHeightsTests {
  /// The width of the rows of the tests.
  static let width: CGFloat = 400

  /// The metrics of the stack of the tests.
  static let metrics = TranscriptElementMetrics(spacing: 10, bottomPadding: 16)

  /// The exact height of the row in the cache of the tests.
  static let exactHeight: CGFloat = 80

  /// The height of a layout of the row in the tests.
  static let measuredHeight: CGFloat = 95

  /// A source of row heights with fixed values.
  struct FixedSource: TranscriptRowHeightSource {
    /// The exact height of the cache, or `nil`.
    var exact: CGFloat?

    /// The height of the last layout of the real row, or `nil`.
    var lastRow: CGFloat?

    /// The estimate of the cache, or `nil`.
    var estimate: CGFloat?

    func exactHeight(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
      exact
    }

    func lastRowHeight(of id: TranscriptEntry.ID, width: CGFloat) -> CGFloat? {
      lastRow
    }

    func estimatedHeight(of id: TranscriptEntry.ID) -> CGFloat? {
      estimate
    }
  }

  /// The shape of one element.
  ///
  /// - Parameters:
  ///   - id: The id of the entry.
  ///   - lineCount: The number of its status lines.
  ///   - isLast: Whether it is the last element.
  /// - Returns: The shape.
  static func shape(_ id: TranscriptEntry.ID, lineCount: Int = 0, isLast: Bool = false) -> TranscriptElementShape {
    TranscriptElementShape(id: id, lineCount: lineCount, isLast: isLast)
  }

  /// The height of `shape` in `heights`.
  ///
  /// - Parameters:
  ///   - heights: The record of the element heights.
  ///   - shape: The shape of the element.
  ///   - source: The source of the row heights.
  /// - Returns: The height.
  static func height(
    _ heights: TranscriptElementHeights, _ shape: TranscriptElementShape, source: FixedSource
  ) -> CGFloat {
    heights.height(of: shape, width: width, source: source, metrics: metrics)
  }

  /// Records a layout of `shape` at the width of the tests.
  ///
  /// - Parameters:
  ///   - heights: The record of the element heights.
  ///   - height: The height of the layout.
  ///   - shape: The shape of the element.
  ///   - source: The source of the row heights.
  static func record(
    _ heights: TranscriptElementHeights, height: CGFloat, for shape: TranscriptElementShape,
    source: FixedSource = FixedSource()
  ) {
    heights.record(height: height, width: width, for: shape, metrics: metrics, source: source)
  }

  /// A production change that fails this test: an element that no source
  /// knows has no height, or a height that changes between two reads.
  @Test func anElementThatNoSourceKnowsTakesTheFixedEstimate() {
    let heights = TranscriptElementHeights()

    let height = Self.height(heights, Self.shape(.local(UUID())), source: FixedSource())

    #expect(height == TranscriptElementHeights.estimatedRowHeight)
  }

  /// A production change that fails this test: the stack takes the last
  /// layout of an element that is not in the list over the exact height of
  /// the cache.
  @Test func theExactHeightOfTheCacheComesBeforeAnOldLayout() {
    let heights = TranscriptElementHeights()
    let id = TranscriptEntry.ID.local(UUID())
    Self.record(heights, height: Self.measuredHeight, for: Self.shape(id))
    heights.noteGone(id)

    let height = Self.height(heights, Self.shape(id), source: FixedSource(exact: Self.exactHeight))

    #expect(height == Self.exactHeight)
  }

  /// A production change that fails this test: the stack takes the exact
  /// height of the cache over the live layout of an element in the list, so
  /// a row that streams overlaps the next row.
  @Test func theLiveLayoutComesBeforeTheExactHeight() {
    let heights = TranscriptElementHeights()
    let id = TranscriptEntry.ID.local(UUID())
    Self.record(heights, height: Self.measuredHeight, for: Self.shape(id))

    let height = Self.height(heights, Self.shape(id), source: FixedSource(exact: Self.exactHeight))

    #expect(height == Self.measuredHeight)
  }

  /// A production change that fails this test: a row with no exact height
  /// takes the estimate and not the height of its last layout.
  @Test func anElementWithNoExactHeightTakesItsLastLayout() {
    let heights = TranscriptElementHeights()
    let id = TranscriptEntry.ID.local(UUID())
    Self.record(heights, height: Self.measuredHeight, for: Self.shape(id))
    heights.noteGone(id)

    let height = Self.height(heights, Self.shape(id), source: FixedSource(estimate: Self.exactHeight))

    #expect(height == Self.measuredHeight)
  }

  /// A production change that fails this test: the last element keeps the
  /// bottom padding in its record, so the element before a new last
  /// element is too tall by the padding.
  @Test func theRecordOfTheLastElementLeavesOutTheBottomPadding() {
    let heights = TranscriptElementHeights()
    let id = TranscriptEntry.ID.local(UUID())
    Self.record(heights, height: Self.measuredHeight + Self.metrics.bottomPadding, for: Self.shape(id, isLast: true))

    let height = Self.height(heights, Self.shape(id), source: FixedSource())

    #expect(height == Self.measuredHeight)
  }

  /// A production change that fails this test: an element with status lines
  /// takes the exact height of the row alone, which leaves out its lines.
  @Test func anElementWithLinesAddsAnEstimateOfEachLine() {
    let heights = TranscriptElementHeights()

    let height = Self.height(
      heights, Self.shape(.local(UUID()), lineCount: 2), source: FixedSource(exact: Self.exactHeight))

    #expect(
      height == Self.exactHeight + 2 * (Self.metrics.spacing + TranscriptElementHeights.estimatedLineHeight))
  }

  /// A production change that fails this test: a record that does not
  /// change the height counts as a change, so each layout of a row makes
  /// the stack compute its geometry again.
  @Test func aRecordOfTheSameHeightIsNoChange() {
    let heights = TranscriptElementHeights()
    let shape = Self.shape(.local(UUID()))
    Self.record(heights, height: Self.measuredHeight, for: shape)
    let revision = heights.revision

    Self.record(heights, height: Self.measuredHeight, for: shape)

    #expect(heights.revision == revision)
  }

  /// A production change that fails this test: the first record of an
  /// element counts as a change also when the layout has the exact height
  /// that the stack used. Then each row that comes into view in a flick
  /// makes the stack compute its geometry again, and the geometry does not
  /// change.
  @Test func aFirstRecordAtTheHeightInUseIsNoChange() {
    let heights = TranscriptElementHeights()
    let source = FixedSource(exact: Self.exactHeight)

    Self.record(heights, height: Self.exactHeight, for: Self.shape(.local(UUID())), source: source)

    #expect(heights.revision == 0)
  }
}
