import Testing

@testable import AgentViewKit

/// The order of the rows of the queue of the height cache when the rows in
/// view move (card ^9ync5h3).
@Suite struct TranscriptRowHeightQueueTests {
  /// The number of rows of the transcript.
  static let rowCount = 10

  /// The rows in view before the move.
  static let rowsBefore = 4..<6

  /// The rows in view after a move down the transcript.
  static let rowsBelow = 6..<8

  /// The number of rows of the batch: the rows in view and one row on each
  /// side of them.
  static let batchSize = 4

  /// The row key of a position.
  ///
  /// - Parameter position: The position.
  /// - Returns: The key.
  static func key(_ position: Int) -> String {
    "row-\(position)"
  }

  /// A production change that fails this test: the queue takes the row
  /// above the rows in view before the row below them also when the rows
  /// in view move down, so the row that the motion brings into view next
  /// waits for a row that has just left the view.
  @Test func aMoveDownTakesTheRowBelowBeforeTheRowAbove() {
    var queue = TranscriptRowHeightQueue()
    let keys = (0..<Self.rowCount).map(Self.key)
    queue.setRows(keys)
    queue.add(keys)
    queue.noteRowsInView(Self.rowsBefore)
    queue.noteRowsInView(Self.rowsBelow)

    let batch = queue.next(limit: Self.batchSize).map(\.rowKey)

    #expect(batch == [6, 7, 8, 5].map(Self.key))
  }
}
