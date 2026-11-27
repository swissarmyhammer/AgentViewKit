import CoreGraphics
import Testing

@testable import AgentViewKit

/// The geometry of the virtual stack of the rows of a thread: the prefix
/// sums of the heights, the rows in a band, the rows that the stack mounts,
/// the offsets of the scrolls, and the anchor of a height correction (card
/// ^kr7cx7b).
@Suite struct TranscriptRowGeometryTests {
  /// The spacing between two rows.
  static let spacing: CGFloat = 10

  /// The heights of the rows of most tests.
  static let heights: [CGFloat] = [100, 50, 200, 30, 120]

  /// The height of the part of the list in view.
  static let viewportHeight: CGFloat = 100

  /// The row keys of `count` rows.
  ///
  /// - Parameter count: The number of rows.
  /// - Returns: `row-0`, `row-1`, and so on.
  static func rowKeys(_ count: Int) -> [String] {
    (0..<count).map { "row-\($0)" }
  }

  /// The geometry of ``heights``.
  ///
  /// - Parameter heights: The heights of the rows.
  /// - Returns: The geometry, with ``spacing``.
  static func geometry(_ heights: [CGFloat] = heights) -> TranscriptRowGeometry {
    TranscriptRowGeometry(rowKeys: rowKeys(heights.count), heights: heights, spacing: spacing)
  }

  /// A production change that fails this test: the total height adds a
  /// spacing after the last row, or it leaves out the spacing.
  @Test func theTotalHeightIsTheSumOfTheHeightsAndTheSpacings() {
    let geometry = Self.geometry()

    #expect(geometry.totalHeight == 500 + 4 * Self.spacing)
  }

  /// A production change that fails this test: the stack with no row has a
  /// height.
  @Test func aStackWithNoRowHasNoHeight() {
    #expect(Self.geometry([]).totalHeight == 0)
  }

  /// A production change that fails this test: the top of a row leaves out
  /// the spacing of the rows before it.
  @Test func theTopOfARowIsThePrefixSumOfTheRowsBeforeIt() {
    let geometry = Self.geometry()

    #expect(geometry.top(ofRow: 3) == 100 + 50 + 200 + 3 * Self.spacing)
  }

  /// A production change that fails this test: the band takes a row whose
  /// bottom is at the top of the band, or it leaves out the row that the
  /// bottom of the band cuts.
  @Test func theRowsInViewAreTheRowsThatMeetTheBand() {
    let geometry = Self.geometry()

    // Row 1 is from 110 to 160, row 2 from 170 to 370.
    #expect(geometry.visibleRows(offset: 160, viewportHeight: Self.viewportHeight) == 2..<3)
  }

  /// A production change that fails this test: the band at the top of the
  /// stack starts at a row after the first row.
  @Test func theRowsInViewAtTheTopStartAtTheFirstRow() {
    let geometry = Self.geometry()

    #expect(geometry.visibleRows(offset: 0, viewportHeight: Self.viewportHeight) == 0..<1)
  }

  /// A production change that fails this test: a band below the last row
  /// gives a row that is not in view.
  @Test func aBandBelowTheLastRowHasNoRow() {
    let geometry = Self.geometry()

    #expect(geometry.visibleRows(offset: 1_000, viewportHeight: Self.viewportHeight).isEmpty)
  }

  /// A production change that fails this test: the stack mounts only the
  /// rows in view, with no screen of rows above and below them.
  @Test func theMountedRowsAreTheRowsInViewAndOneScreenAboveAndBelow() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50])

    // Rows 3 and 4 are in view, from 180 to 290. One screen of 100 above
    // and below takes the rows from 80 to 390.
    let rows = geometry.mountedRows(visible: 3..<5, viewportHeight: Self.viewportHeight)

    #expect(rows == [1, 2, 3, 4, 5, 6])
  }

  /// A production change that fails this test: the stack mounts no row
  /// before the first report of the rows in view, so the first layout shows
  /// no row.
  @Test func withNoReportTheStackMountsTheRowsAtTheBottom() {
    let geometry = Self.geometry()

    // The bottom band is from 440 to 540: row 4. One screen above it takes
    // rows 2 and 3.
    let rows = geometry.mountedRows(visible: nil, viewportHeight: Self.viewportHeight)

    #expect(rows == [2, 3, 4])
  }

  /// A production change that fails this test: a scroll to an item far
  /// from the rows in view does not mount the row of the item, so the
  /// scroll finds no view of that id.
  @Test func theMountedRowsHoldTheRowsAtTheOffsetOfAnItemScroll() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50, 50, 50])

    let rows = geometry.mountedRows(visible: 8..<10, viewportHeight: Self.viewportHeight, itemRow: 1)

    #expect(Set([1, 2]).isSubset(of: rows))
  }

  /// A production change that fails this test: a scroll to the bottom does
  /// not mount the rows at the bottom until the next report.
  @Test func theMountedRowsHoldTheRowsAtTheBottomOfABottomScroll() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50, 50, 50])

    let rows = geometry.mountedRows(visible: 0..<2, viewportHeight: Self.viewportHeight, keepsBottom: true)

    #expect(Set([8, 9]).isSubset(of: rows))
  }

  /// A production change that fails this test: a mounted row at the edge of
  /// the screen above the view leaves the stack when a height correction
  /// moves that edge, and it mounts again in the next pass.
  @Test func aMountedRowInTheMarginStaysMounted() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50, 50, 50])

    // Rows 6 and 7 are in view, from 360 to 470. The screen above them
    // starts at 260, at row 4, so row 3 is one row above that screen.
    let rows = geometry.mountedRows(visible: 6..<8, viewportHeight: Self.viewportHeight, kept: [3])

    #expect(rows.contains(3))
  }

  /// A production change that fails this test: the stack mounts a row of the
  /// margin that it did not mount before.
  @Test func aRowInTheMarginThatWasNotMountedStaysOut() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50, 50, 50])

    let rows = geometry.mountedRows(visible: 6..<8, viewportHeight: Self.viewportHeight, kept: [])

    #expect(!rows.contains(3))
  }

  /// A production change that fails this test: the stack keeps each row that
  /// it mounted, so a long scroll keeps the rows far from the view.
  @Test func aMountedRowPastTheMarginLeaves() {
    let geometry = Self.geometry([50, 50, 50, 50, 50, 50, 50, 50, 50, 50])

    let rows = geometry.mountedRows(visible: 6..<8, viewportHeight: Self.viewportHeight, kept: [0])

    #expect(!rows.contains(0))
  }

  /// A production change that fails this test: the scroll to an item does
  /// not put the top of the row at the top of the view.
  @Test func theOffsetOfAnItemScrollIsTheTopOfItsRow() {
    let geometry = Self.geometry()

    #expect(geometry.scrollOffset(toShowRow: 2, viewportHeight: Self.viewportHeight) == 170)
  }

  /// A production change that fails this test: the scroll to an item near
  /// the end goes past the end of the content.
  @Test func theOffsetOfAnItemScrollStopsAtTheBottom() {
    let geometry = Self.geometry([100, 50, 200, 30, 20])

    #expect(
      geometry.scrollOffset(toShowRow: 4, viewportHeight: Self.viewportHeight)
        == geometry.bottomOffset(viewportHeight: Self.viewportHeight))
  }

  /// A production change that fails this test: the offset of the bottom is
  /// not the end of the content less the height in view.
  @Test func theOffsetOfTheBottomIsTheEndLessTheHeightInView() {
    let geometry = Self.geometry()

    #expect(geometry.bottomOffset(viewportHeight: Self.viewportHeight) == 540 - Self.viewportHeight)
  }

  /// A production change that fails this test: a list whose content fits
  /// in view has a bottom offset below zero.
  @Test func theOffsetOfTheBottomOfAShortListIsZero() {
    let geometry = Self.geometry([20])

    #expect(geometry.bottomOffset(viewportHeight: Self.viewportHeight) == 0)
  }

  /// A production change that fails this test: a row above the anchor gets
  /// a new height, and the offset does not move by the change, so the rows
  /// in view jump.
  @Test func aCorrectionAboveTheAnchorMovesTheOffsetByTheChange() {
    let old = Self.geometry()
    let new = Self.geometry([100, 80, 200, 30, 120])

    #expect(new.anchoredOffset(200, anchorRowKey: "row-2", from: old) == 230)
  }

  /// A production change that fails this test: a row below the anchor gets
  /// a new height, and the offset moves, so the rows in view jump.
  @Test func aCorrectionBelowTheAnchorKeepsTheOffset() {
    let old = Self.geometry()
    let new = Self.geometry([100, 50, 200, 90, 120])

    #expect(new.anchoredOffset(200, anchorRowKey: "row-2", from: old) == 200)
  }

  /// A production change that fails this test: the anchor is the index of
  /// the row and not its key, so a new first row moves the rows in view.
  @Test func theAnchorFollowsTheKeyOfItsRow() {
    let old = Self.geometry()
    let new = TranscriptRowGeometry(
      rowKeys: ["row-new"] + Self.rowKeys(Self.heights.count), heights: [40] + Self.heights, spacing: Self.spacing)

    #expect(new.anchoredOffset(200, anchorRowKey: "row-2", from: old) == 200 + 40 + Self.spacing)
  }
}
