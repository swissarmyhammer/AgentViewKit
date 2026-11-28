import CoreGraphics

/// The rule of the rows that the window of the virtual stack of a thread
/// mounts for a report of the rows in view (``TranscriptRowWindow``, card
/// ^kr7cx7b).
///
/// The plan is a value, so the body of the window and the geometry of the
/// window, which SwiftUI reads off the main actor, use the same rule: the
/// body mounts the rows, and the geometry tells which rows a new report
/// needs that the body did not mount.
nonisolated struct TranscriptMountPlan: Sendable {
  /// The geometry of the shown rows.
  let geometry: TranscriptStackGeometry

  /// The position in the transcript of the item of a scroll to an item
  /// that did not end, or `nil`.
  let itemPosition: Int?

  /// Whether a scroll to the bottom did not end: the window mounts the
  /// rows at the bottom.
  let keepsBottom: Bool

  /// Whether the user moves the rows: the window mounts the lead row of
  /// the motion (``leadPosition(report:movesDown:)``).
  let leadsMotion: Bool

  /// The height of the part in view before the first report, in points.
  static let fallbackViewportHeight: CGFloat = 1_000

  /// The positions in the transcript of the rows that the window mounts.
  ///
  /// The rows of the report always mount
  /// (``rows(for:kept:)``). The lead row of a live motion mounts when the
  /// window mounted it before, or when no other row is new, so a body makes
  /// at most one row that is not in view.
  ///
  /// - Parameters:
  ///   - report: The latest report of the rows in view, or `nil` before
  ///     the first one.
  ///   - movesDown: Whether the last move of the rows in view went down the
  ///     transcript, or `nil` before the first move.
  ///   - kept: The positions of the rows that the window mounted before.
  /// - Returns: The positions, in order.
  func positions(report: TranscriptViewport?, movesDown: Bool?, kept: [Int]) -> [Int] {
    let positions = rows(for: report, kept: kept)
    guard let lead = leadPosition(report: report, movesDown: movesDown), !positions.contains(lead),
      kept.contains(lead) || Set(positions).isSubset(of: kept)
    else { return positions }
    return (positions + [lead]).sorted()
  }

  /// The positions of the rows that a report needs and that the window did
  /// not mount: the rows of the report and the lead row of a live motion.
  ///
  /// - Parameters:
  ///   - report: The report of the rows in view, or `nil`.
  ///   - movesDown: Whether the last move of the rows in view went down the
  ///     transcript, or `nil` before the first move.
  ///   - mounted: The positions of the rows that the window mounted.
  /// - Returns: The positions, in order, empty when the window mounted
  ///   each row that the report needs.
  func rowsToMount(report: TranscriptViewport?, movesDown: Bool?, mounted: [Int]) -> [Int] {
    let lead = leadPosition(report: report, movesDown: movesDown)
    let needed = rows(for: report, kept: []) + [lead].compactMap { $0 }
    let mountedRows = Set(mounted)
    return needed.filter { !mountedRows.contains($0) }
  }

  /// The position of the lead row of a live motion: one row past the shown
  /// rows in the direction of the last move of the rows in view
  /// (``TranscriptViewport/leadPosition(movesDown:in:)``).
  ///
  /// While the user moves the rows, the window mounts this one row before
  /// it comes into view, so the first frame of a new row (its make, its
  /// layout and its draw) is a frame in which the row is not in view. A full
  /// screen of rows around the view cost about 50 % more in a flick
  /// (``TranscriptRowGeometry/keptRowMargin``); one row in the direction of
  /// the motion costs one row.
  ///
  /// - Parameters:
  ///   - report: The latest report of the rows in view, or `nil`.
  ///   - movesDown: Whether the last move of the rows in view went down the
  ///     transcript, or `nil` before the first move.
  /// - Returns: The position, or `nil` when the rows do not move live, or
  ///   when no direction of the motion is known.
  func leadPosition(report: TranscriptViewport?, movesDown: Bool?) -> Int? {
    guard leadsMotion, let report, let movesDown else { return nil }
    let positions = geometry.firstPosition..<(geometry.firstPosition + geometry.rows.count)
    return report.leadPosition(movesDown: movesDown, in: positions)
  }

  /// The positions in the transcript of the rows that the window mounts for
  /// a report of the rows in view
  /// (``TranscriptRowGeometry/mountedRows(visible:shown:viewportHeight:itemRow:keepsBottom:kept:)``).
  ///
  /// - Parameters:
  ///   - report: The report of the rows in view, or `nil` before the first
  ///     one.
  ///   - kept: The positions of the rows that the window mounted before.
  /// - Returns: The positions, in order.
  func rows(for report: TranscriptViewport?, kept: [Int]) -> [Int] {
    let visible = report.map {
      geometry.index(ofPosition: $0.visible.lowerBound)..<geometry.index(ofPosition: $0.visible.upperBound)
    }
    let shown = report.map {
      geometry.index(ofPosition: $0.shown.lowerBound)..<geometry.index(ofPosition: $0.shown.upperBound)
    }
    let rows = geometry.rows.mountedRows(
      visible: visible, shown: shown, viewportHeight: report?.height ?? Self.fallbackViewportHeight,
      itemRow: itemPosition.map(geometry.index(ofPosition:)), keepsBottom: keepsBottom,
      kept: kept.map(geometry.index(ofPosition:)))
    return rows.map { $0 + geometry.firstPosition }
  }
}
