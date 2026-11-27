import AppKit
import SwiftUI
import Testing

@testable import AgentViewKit

/// The hit test of the rows of a thread in a live motion of the user (card
/// ^9ync5h3).
///
/// While the content moves under a still mouse, SwiftUI hit-tests each
/// hover responder of the rows again on each frame. In a live motion the
/// rows take no hit test, so they have no hover responder to test. A
/// scroll-wheel event still reaches the scroll view of the list.
@MainActor @Suite struct TranscriptRowHitTestTests {
  /// The width of the row, in points.
  static let width: CGFloat = 480

  /// A host of a plain answer whose row is real at rest, in a scroll view
  /// when `isInScrollView` is `true`.
  ///
  /// - Parameter isInScrollView: Whether the row is in a scroll view.
  /// - Returns: The host, with the row at rest.
  static func realRow(isInScrollView: Bool = false) -> StaticRowHost {
    let host = StaticRowHost(TranscriptStaticRowTests.plainAnswer, width: width)
    host.isInScrollView = isInScrollView
    host.showAtRestAndSettle()
    return host
  }

  /// A production change that fails this test: the rows keep their hit
  /// test in a live motion, so each frame of a flick hit-tests the hover
  /// responders and the editors of the rows under the mouse.
  @Test func aRealRowTakesNoHitTestInALiveMotion() throws {
    let host = Self.realRow()
    try #require(host.hitReachesRow, "at rest: \(host.hitAtText)")

    host.show(rowsMove: true)

    #expect(!host.hitReachesRow, "in a live motion: \(host.hitAtText)")
  }

  /// A production change that fails this test: the rows take no hit test
  /// at rest, so the mouse does not reach the text and the controls of a
  /// row.
  @Test func aRealRowTakesTheHitTestAgainAtRest() {
    let host = Self.realRow()
    host.show(rowsMove: true)

    host.show(rowsMove: false)

    #expect(host.hitReachesRow, "\(host.hitAtText)")
  }

  /// A production change that fails this test: the rows in a live motion
  /// take the hit test away from the scroll view too, so the scroll-wheel
  /// and momentum events of the flick reach no view.
  @Test func theScrollViewTakesTheHitTestOfARowInALiveMotion() {
    let host = Self.realRow(isInScrollView: true)

    host.show(rowsMove: true)

    #expect(host.hitReachesScrollView, "\(host.hitAtText)")
  }

  // MARK: - The hover of a row

  /// A production change that fails this test: the mouse that came on a
  /// row at rest holds the row for the whole live motion, after the row
  /// took no more hit test and no more hover callback.
  @Test func aLiveMotionClearsTheHoverOfARow() {
    var hover = TranscriptRowHover()
    hover.note(hovering: true, rowsMove: false)

    hover.noteLiveMotion()

    #expect(!hover.isHovered)
  }

  /// A production change that fails this test: a row that comes under the
  /// mouse while the rows move takes the hover, so it mounts its editors
  /// during the move.
  @Test func aRowThatComesUnderTheMouseWhileTheRowsMoveTakesNoHover() {
    var hover = TranscriptRowHover()

    hover.note(hovering: true, rowsMove: true)

    #expect(!hover.isHovered)
  }

  /// A production change that fails this test: the mouse that comes on a
  /// row at rest does not hold the row.
  @Test func theMouseOnARowAtRestIsTheHoverOfTheRow() {
    var hover = TranscriptRowHover()

    hover.note(hovering: true, rowsMove: false)

    #expect(hover.isHovered)
  }
}
