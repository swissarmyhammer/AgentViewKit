/// The rows that the height cache must still compute, in the order of
/// their computation (card ^9ync5h3).
///
/// The order starts at the rows in view and goes out from them in the two
/// directions, one row above and one row below at each step. The row ahead
/// of the last move of the rows in view comes first at each step: the row
/// below them after a move down the transcript, else the row above them.
/// Thus the rows that a flick reaches first get their heights and their
/// pictures first. When no row in view
/// is known, the order starts at the last row: a thread shows its last rows
/// first (`defaultScrollAnchor(.bottom)`).
///
/// The queue makes the order again only when its rows, its rows in view or
/// its pending rows change, and then only at the next batch. Each step of
/// the order is a set lookup, so a batch costs the main thread no layout
/// and no measure.
nonisolated struct TranscriptRowHeightQueue {
  /// One row of a batch.
  struct Pick: Equatable {
    /// The row key.
    let rowKey: String

    /// The place of the row in the order from the rows in view: zero for
    /// the first row in view.
    let rank: Int
  }

  /// The row keys of the transcript, in the order of the rows.
  private var rowKeys: [String] = []

  /// The position of each row of the transcript, by row key.
  private var positions: [String: Int] = [:]

  /// The positions of the rows in view.
  private var rowsInView: Range<Int> = .zero ..< .zero

  /// Whether the last move of the rows in view went down the transcript,
  /// so the row below the rows in view comes first at each step of the
  /// order.
  private var movesDown = false

  /// The row keys that the cache must still compute.
  private var pending: Set<String> = []

  /// The pending rows in the order of their computation, the first row
  /// last, or `nil` when a change makes the order old.
  private var order: [Pick]?

  /// Whether no row waits for its computation.
  var isEmpty: Bool {
    pending.isEmpty
  }

  /// Gives the queue the rows of the transcript.
  ///
  /// - Parameter keys: The row keys, in the order of the rows.
  mutating func setRows(_ keys: [String]) {
    guard keys != rowKeys else { return }
    rowKeys = keys
    positions = Dictionary(keys.enumerated().map { ($1, $0) }) { first, _ in first }
    order = nil
  }

  /// Gives the queue the positions of the rows in view.
  ///
  /// - Parameter rows: The positions, or an empty range when no row in
  ///   view is known.
  mutating func noteRowsInView(_ rows: Range<Int>) {
    guard rows != rowsInView else { return }
    if !rows.isEmpty, !rowsInView.isEmpty {
      movesDown = rows.lowerBound > rowsInView.lowerBound || rows.upperBound > rowsInView.upperBound
    }
    rowsInView = rows
    order = nil
  }

  /// Adds rows to compute.
  ///
  /// - Parameter keys: The row keys.
  mutating func add(_ keys: some Sequence<String>) {
    let count = pending.count
    pending.formUnion(keys)
    guard pending.count != count else { return }
    order = nil
  }

  /// The distance of a row from the rows in view, in rows: zero for a row
  /// in view, one for the row next to them. When no row in view is known,
  /// the distance is from the last row, where a thread starts.
  ///
  /// - Parameter rowKey: The row key.
  /// - Returns: The distance, or `Int.max` for a row that is not in the
  ///   transcript.
  func distance(ofRow rowKey: String) -> Int {
    guard let position = positions[rowKey] else { return .max }
    let rows = start
    if position < rows.lowerBound {
      return rows.lowerBound - position
    }
    return Swift.max(position - rows.upperBound + 1, .zero)
  }

  /// The row keys of the rows in view and of the rows near them: `reach`
  /// rows above and `reach` rows below them.
  ///
  /// - Parameter reach: The number of rows on each side of the rows in
  ///   view.
  /// - Returns: The row keys, in the order of the rows.
  func rowKeys(near reach: Int) -> ArraySlice<String> {
    let rows = start
    let lower = Swift.max(rows.lowerBound - reach, .zero)
    let upper = Swift.min(rows.upperBound + reach, rowKeys.count)
    return lower < upper ? rowKeys[lower..<upper] : []
  }

  /// The rows from which the order starts: the rows in view, or the last
  /// row when no row in view is known.
  private var start: Range<Int> {
    Self.start(count: rowKeys.count, rowsInView: rowsInView)
  }

  /// The rows from which the order starts.
  ///
  /// - Parameters:
  ///   - count: The number of rows.
  ///   - rowsInView: The positions of the rows in view, or an empty range
  ///     for the last row.
  /// - Returns: The rows in view in the transcript, or the last row.
  private static func start(count: Int, rowsInView: Range<Int>) -> Range<Int> {
    let rows = rowsInView.clamped(to: .zero ..< count)
    return rows.isEmpty ? (Swift.max(count - 1, .zero) ..< count) : rows
  }

  /// Takes the next rows to compute out of the queue.
  ///
  /// A pending row that is not a row of the transcript is dropped.
  ///
  /// - Parameter limit: The most rows of the batch.
  /// - Returns: The rows, the first row to compute first. The list is
  ///   empty when no row waits.
  mutating func next(limit: Int) -> [Pick] {
    var picks = order ?? makeOrder()
    let batch = Array(picks.suffix(limit).reversed())
    picks.removeLast(batch.count)
    pending.subtract(batch.map(\.rowKey))
    order = picks
    return batch
  }

  /// The pending rows in the order of their computation, the first row
  /// last. The pending rows that are not in the transcript leave the
  /// queue.
  ///
  /// - Returns: The order.
  private mutating func makeOrder() -> [Pick] {
    let walk = Self.walk(count: rowKeys.count, rowsInView: rowsInView, belowFirst: movesDown)
    let picks = walk.enumerated().compactMap { rank, position in
      pending.contains(rowKeys[position]) ? Pick(rowKey: rowKeys[position], rank: rank) : nil
    }
    pending = Set(picks.map(\.rowKey))
    return picks.reversed()
  }

  /// The positions of the rows from the rows in view out: each row in
  /// view, then at each step the row above and the row below.
  ///
  /// - Parameters:
  ///   - count: The number of rows.
  ///   - rowsInView: The positions of the rows in view, or an empty range
  ///     for the last row.
  ///   - belowFirst: Whether the row below comes before the row above at
  ///     each step. The default is `false`.
  /// - Returns: Each position from zero to `count` one time.
  static func walk(count: Int, rowsInView: Range<Int>, belowFirst: Bool = false) -> [Int] {
    let start = start(count: count, rowsInView: rowsInView)
    let steps = Swift.max(start.lowerBound, count - start.upperBound)
    let outward = (0 ..< steps).flatMap { step in
      let above = start.lowerBound - 1 - step
      let below = start.upperBound + step
      return (belowFirst ? [below, above] : [above, below]).filter { (0 ..< count).contains($0) }
    }
    return Array(start) + outward
  }
}
