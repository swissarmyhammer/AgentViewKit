import CoreGraphics
import Testing

@testable import AgentViewKit

/// The report of the rows in view of the virtual stack of a thread, and the
/// anchor row of a height change (card ^dwybk4c).
///
/// The window of the stack mounts the lead row of a live motion in the
/// direction of the last move of the rows in view. The stack keeps a row in
/// view at its place when the heights change.
@Suite struct TranscriptViewportTests {
  /// The spacing between two rows.
  static let spacing: CGFloat = 10

  /// The heights of the rows: a tall row between two short rows, taller
  /// than the part in view.
  static let heights: [CGFloat] = [100, 2_000, 100]

  /// The height of the part of the list in view.
  static let viewportHeight: CGFloat = 600

  /// The offset of the part in view inside the tall row.
  static let offsetInTallRow: CGFloat = 500

  /// The distance of one step of a scroll, in points.
  static let step: CGFloat = 40

  /// The position in the transcript of the first shown row.
  static let firstPosition = 10

  /// The geometry of ``heights``, with ``firstPosition``.
  ///
  /// - Parameter isLaidOut: Whether each row had the height of its own
  ///   layout.
  /// - Returns: The geometry.
  static func geometry(isLaidOut: [Bool] = [true, true, true]) -> TranscriptStackGeometry {
    let rows = TranscriptRowGeometry(
      rowKeys: TranscriptRowGeometryTests.rowKeys(heights.count), heights: heights, spacing: spacing)
    return TranscriptStackGeometry(firstPosition: firstPosition, rows: rows, isLaidOut: isLaidOut)
  }

  /// The report of the rows in view at an offset.
  ///
  /// - Parameter offset: The offset of the top of the part in view.
  /// - Returns: The report.
  static func report(at offset: CGFloat) -> TranscriptViewport {
    TranscriptViewport(
      bounds: CGRect(x: .zero, y: offset, width: 400, height: viewportHeight), insets: .zero,
      geometry: geometry())
  }

  /// A production change that fails this test: the report learns the
  /// direction of a move only when the first or the last row in view
  /// changes. A row taller than the part in view then keeps the same rows
  /// in view for many steps of a flick, and the window mounts no lead row
  /// in those steps, or it mounts the lead row of an old move in the other
  /// direction.
  @Test func aMoveUpInsideOneTallRowGoesUpTheTranscript() {
    let old = Self.report(at: Self.offsetInTallRow)

    let new = Self.report(at: Self.offsetInTallRow - Self.step)

    #expect(new.movesDown(from: old) == false)
  }

  /// A production change that fails this test: the anchor of a height
  /// change is always the first row in view. A row that comes into view
  /// at the top of a scroll up has an estimated height until its first
  /// layout, so its new height moves each row in view below it.
  @Test func theAnchorIsTheFirstRowInViewThatWasLaidOut() {
    let geometry = Self.geometry(isLaidOut: [false, true, true])

    let anchor = geometry.anchorRowKey(visible: Self.firstPosition..<(Self.firstPosition + 2))

    #expect(anchor == "row-1")
  }

  /// A production change that fails this test: the stack has no anchor
  /// when no row in view was laid out, such as after a change of the
  /// width, so the rows in view jump by each height change above them.
  @Test func withNoRowInViewLaidOutTheAnchorIsTheFirstRowInView() {
    let geometry = Self.geometry(isLaidOut: [false, false, true])

    let anchor = geometry.anchorRowKey(visible: Self.firstPosition..<(Self.firstPosition + 2))

    #expect(anchor == "row-0")
  }
}
