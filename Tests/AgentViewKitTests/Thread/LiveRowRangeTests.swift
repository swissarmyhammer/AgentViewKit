import Testing

@testable import AgentViewKit

/// The rows of a thread that keep their EditorKit models (task ^t9416x5).
@MainActor @Suite struct LiveRowRangeTests {
  /// A position far below the rows in view of each test.
  static let farPosition = 1_000

  /// The first row in view of the scroll of one row at a time.
  static let scrollStart = 100

  /// The last row in view of the scroll of one row at a time.
  static let scrollEnd = 300

  /// The largest number of rows whose liveness one move of the range can
  /// change: five rows that leave the range at one end, and five rows that
  /// enter it at the other end.
  static let largestChangeOfOneMove = 10

  /// A production change that fails this test: a range with no report makes
  /// a row a placeholder before the list reported any row.
  @Test func eachRowIsLiveBeforeTheFirstReport() {
    #expect(LiveRowRange().isLive(Self.farPosition))
  }

  /// A production change that fails this test: the range keeps each row
  /// live, so each row of a long transcript keeps its model.
  @Test func aRowFarFromTheRowsInViewIsNotLive() {
    let rows = LiveRowRange()

    rows.noteVisible(positions: [0, 1])

    #expect(!rows.isLive(Self.farPosition))
  }

  /// A production change that fails this test: the range keeps only the
  /// rows in view, so a row next to them has no model when it scrolls in.
  @Test func aRowInTheMarginIsLive() {
    let rows = LiveRowRange()

    rows.noteVisible(positions: [Self.farPosition])

    #expect(rows.isLive(Self.farPosition + LiveRowRange.margin))
  }

  /// A production change that fails this test: the range moves at each
  /// report, so each scroll of one row makes all the rows evaluate again.
  @Test func aScrollInTheSlackKeepsTheRange() {
    let rows = LiveRowRange()
    let start = Self.farPosition

    rows.noteVisible(positions: [start])
    rows.noteVisible(positions: [start + LiveRowRange.slack])

    #expect(rows.isLive(start - LiveRowRange.margin))
  }

  /// A production change that fails this test: the range does not move
  /// after a scroll past its slack.
  @Test func aScrollPastTheSlackMovesTheRange() {
    let rows = LiveRowRange()
    let start = Self.farPosition

    rows.noteVisible(positions: [start])
    rows.noteVisible(positions: [start + LiveRowRange.slack + 1])

    #expect(!rows.isLive(start - LiveRowRange.margin))
  }

  /// A production change that fails this test: the range moves in large
  /// steps, so one move makes many rows drop or make their editors at once,
  /// and the scroll stutters.
  @Test func aScrollOfOneRowAtATimeChangesTheLivenessOfFewRowsAtEachMove() {
    let rows = LiveRowRange()
    let span = 0..<Self.farPosition
    rows.noteVisible(positions: [Self.scrollStart])
    let start = span.map { rows.isLive($0) }

    let liveness = ((Self.scrollStart + 1)...Self.scrollEnd).map { first in
      rows.noteVisible(positions: [first])
      return span.map { rows.isLive($0) }
    }

    let steps = zip([start] + liveness, liveness)
    let changes = steps.map { before, after in zip(before, after).count { $0 != $1 } }
    #expect(changes.max() ?? 0 <= Self.largestChangeOfOneMove)
  }

  /// A production change that fails this test: a report with no row, such
  /// as a layout pass past the end of the content, makes each row live.
  @Test func aReportWithNoRowKeepsTheRange() {
    let rows = LiveRowRange()

    rows.noteVisible(positions: [0])
    rows.noteVisible(positions: [])

    #expect(!rows.isLive(Self.farPosition))
  }
}
