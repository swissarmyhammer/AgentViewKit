import CoreGraphics

/// The known geometry of the rows of the virtual stack of a thread
/// (``TranscriptRowStack``, card ^kr7cx7b): the height and the top of each
/// row, and the exact height of all the rows.
///
/// The top of each row is the prefix sum of the heights and the spacings of
/// the rows before it. Thus the stack knows its total height without a
/// layout of each row, and a scroll to a row or to the bottom goes to an
/// exact offset. The offsets are in the coordinates of the stack: the top of
/// the first row is zero.
nonisolated struct TranscriptRowGeometry: Equatable, Sendable {
  /// The number of rows above and below the screen of mounted rows in which
  /// a mounted row stays mounted
  /// (``mountedRows(visible:viewportHeight:itemRow:keepsBottom:kept:)``).
  ///
  /// The stack mounts no overscan around the rows in view: each mounted row
  /// costs SwiftUI work on each scroll step, an overscan makes the rows of a
  /// flick in batches, and it keeps the real rows of a rest mounted at the
  /// start of a flick. With an overscan of one screen, a flick of the unit
  /// host cost about 50 % more than the lazy stack of main; with none, it
  /// cost the same (card ^kr7cx7b).
  static let keptRowMargin = 1

  /// The row key of each row, in the order of the rows.
  let rowKeys: [String]

  /// The height of each row.
  let heights: [CGFloat]

  /// The spacing between two rows.
  let spacing: CGFloat

  /// The top of each row.
  let tops: [CGFloat]

  /// The height of all the rows and the spacings between them.
  let totalHeight: CGFloat

  /// Makes the geometry of rows.
  ///
  /// - Parameters:
  ///   - rowKeys: The row key of each row.
  ///   - heights: The height of each row, in the order of `rowKeys`.
  ///   - spacing: The spacing between two rows.
  init(rowKeys: [String], heights: [CGFloat], spacing: CGFloat) {
    precondition(rowKeys.count == heights.count, "each row has one key and one height")
    self.rowKeys = rowKeys
    self.heights = heights
    self.spacing = spacing
    let ends = heights.reduce(into: [CGFloat]()) { ends, height in
      ends.append((ends.last.map { $0 + spacing } ?? .zero) + height)
    }
    tops = zip(ends, heights).map { end, height in end - height }
    totalHeight = ends.last ?? .zero
  }

  /// The number of rows.
  var count: Int {
    heights.count
  }

  /// The top of a row.
  ///
  /// - Parameter row: The index of the row.
  /// - Returns: The offset of the top of the row.
  func top(ofRow row: Int) -> CGFloat {
    tops[row]
  }

  /// The bottom of a row.
  ///
  /// - Parameter row: The index of the row.
  /// - Returns: The offset of the bottom of the row.
  func bottom(ofRow row: Int) -> CGFloat {
    tops[row] + heights[row]
  }

  /// The rows that meet a band: each row whose bottom is below the top of
  /// the band, and whose top is above the bottom of the band.
  ///
  /// - Parameters:
  ///   - minY: The top of the band.
  ///   - maxY: The bottom of the band.
  /// - Returns: The indices of the rows, empty when no row meets the band.
  func rows(from minY: CGFloat, to maxY: CGFloat) -> Range<Int> {
    let first = firstRow { bottom(ofRow: $0) > minY }
    let end = firstRow { top(ofRow: $0) >= maxY }
    return first..<max(first, end)
  }

  /// The rows in view at a scroll offset.
  ///
  /// - Parameters:
  ///   - offset: The offset of the top of the part in view.
  ///   - viewportHeight: The height of the part in view.
  /// - Returns: The indices of the rows in view.
  func visibleRows(offset: CGFloat, viewportHeight: CGFloat) -> Range<Int> {
    rows(from: offset, to: offset + viewportHeight)
  }

  /// The offset of the scroll to the bottom: the end of the content less
  /// the height in view, and zero when the content fits in view.
  ///
  /// - Parameter viewportHeight: The height of the part in view.
  /// - Returns: The offset.
  func bottomOffset(viewportHeight: CGFloat) -> CGFloat {
    max(totalHeight - viewportHeight, .zero)
  }

  /// The offset of a scroll to a row: the top of the row at the top of the
  /// part in view. A scroll does not go past the end of the content, so the
  /// offset is at most the offset of the bottom.
  ///
  /// - Parameters:
  ///   - row: The index of the row.
  ///   - viewportHeight: The height of the part in view.
  /// - Returns: The offset.
  func scrollOffset(toShowRow row: Int, viewportHeight: CGFloat) -> CGFloat {
    min(top(ofRow: row), bottomOffset(viewportHeight: viewportHeight))
  }

  /// The rows that the stack mounts: the rows in view, and the rows in view
  /// at the end of a scroll that the list makes now.
  ///
  /// A row that the stack mounted before stays mounted while it is in
  /// ``keptRowMargin`` rows above or below the rows in view. A height
  /// correction moves the edge of the view by a row, and without this
  /// margin, a row at that edge leaves the stack and mounts again in the
  /// next pass. The margin holds only the rows of this geometry: a kept row
  /// past the last row, such as the last row before a reset or a rollback
  /// made the transcript shorter, leaves.
  ///
  /// - Parameters:
  ///   - visible: The rows in view at the last report, or `nil` before the
  ///     first report. With no report, the rows in view are the rows at the
  ///     bottom, where the list starts.
  ///   - viewportHeight: The height of the part in view.
  ///   - itemRow: The row of a scroll to an item that did not end, or `nil`.
  ///   - keepsBottom: Whether a scroll to the bottom did not end.
  ///   - kept: The rows that the stack mounted before.
  /// - Returns: The indices of the rows, in order, each one time.
  func mountedRows(
    visible: Range<Int>?, viewportHeight: CGFloat, itemRow: Int? = nil, keepsBottom: Bool = false,
    kept: [Int] = []
  ) -> [Int] {
    let bottom = visibleRows(offset: bottomOffset(viewportHeight: viewportHeight), viewportHeight: viewportHeight)
    let screen = nonEmpty(visible.map { $0.clamped(to: 0..<count) } ?? bottom)
    let margin = max(screen.lowerBound - Self.keptRowMargin, 0)..<min(screen.upperBound + Self.keptRowMargin, count)
    var bands = [Array(screen), kept.filter(margin.contains)]
    if let itemRow, heights.indices.contains(itemRow) {
      let offset = scrollOffset(toShowRow: itemRow, viewportHeight: viewportHeight)
      bands.append(Array(nonEmpty(visibleRows(offset: offset, viewportHeight: viewportHeight))))
    }
    if keepsBottom {
      bands.append(Array(nonEmpty(bottom)))
    }
    return Set(bands.joined()).sorted()
  }

  /// The offset that keeps a row at its place in view after a change of the
  /// heights: the old offset moved by the move of the top of the row.
  ///
  /// A change of a row above the anchor row moves the offset, so the rows
  /// in view do not jump. A change of the anchor row or of a row below it
  /// does not move the offset. The anchor is the row key of the row, so a
  /// new row before it, such as a row of an earlier page, also keeps it at
  /// its place.
  ///
  /// - Parameters:
  ///   - offset: The scroll offset in the old geometry.
  ///   - anchorRowKey: The row key of the anchor row, such as the first row
  ///     in view.
  ///   - old: The geometry before the change.
  /// - Returns: The offset in this geometry. It is `offset` when one of the
  ///   two geometries has no row of the anchor key.
  func anchoredOffset(_ offset: CGFloat, anchorRowKey: String, from old: TranscriptRowGeometry) -> CGFloat {
    guard let oldRow = old.rowKeys.firstIndex(of: anchorRowKey), let row = rowKeys.firstIndex(of: anchorRowKey)
    else { return offset }
    return offset + top(ofRow: row) - old.top(ofRow: oldRow)
  }

  /// The rows of a band of rows, with one row at least.
  ///
  /// An empty band, such as the band of a part in view below the last row,
  /// takes the row at its place, so the stack always mounts the rows near
  /// the part in view.
  ///
  /// - Parameter band: The rows of the band.
  /// - Returns: The rows, empty only when the stack has no row.
  private func nonEmpty(_ band: Range<Int>) -> Range<Int> {
    guard count > 0 else { return 0..<0 }
    let first = min(band.lowerBound, count - 1)
    let last = min(max(band.upperBound - 1, first), count - 1)
    return first..<(last + 1)
  }

  /// The first row for which `isPast` is true, with a binary search. The
  /// rows must be in order for `isPast`: false for each row before the
  /// answer, and true for each row after it.
  ///
  /// - Parameter isPast: The test of a row.
  /// - Returns: The index of the row, or ``count`` when no row passes.
  private func firstRow(where isPast: (Int) -> Bool) -> Int {
    var low = 0
    var high = count
    while low < high {
      let middle = (low + high) / 2
      if isPast(middle) {
        high = middle
      } else {
        low = middle + 1
      }
    }
    return low
  }
}
