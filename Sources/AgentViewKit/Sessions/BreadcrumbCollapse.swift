import CoreGraphics

/// The rule that decides how much of the path of the header collapses, from
/// widths and not from the number of sessions.
///
/// The header tries three shapes, in order, and takes the first that fits the
/// available width:
///
/// 1. ``Shape/full``: the agent, and each crumb,
/// 2. ``Shape/collapsed``: the agent, the first crumb, one "..." dropdown with
///    each middle crumb, and the last crumb,
/// 3. ``Shape/truncated``: the collapsed shape, with the text of the crumbs
///    cut to fit.
///
/// The agent segment has the priority: its width is never reduced, so only
/// the crumbs collapse and truncate. A path with no middle crumb has nothing
/// to collapse, and goes from the full shape to the truncated one.
enum BreadcrumbCollapse {
  /// The shape of the row.
  enum Shape: Equatable {
    /// Each crumb shows.
    case full

    /// The middle crumbs are in one dropdown.
    case collapsed

    /// The middle crumbs are in one dropdown, and the text is cut.
    case truncated
  }

  /// The separators of the collapsed row: one before each of the first crumb,
  /// the dropdown and the last crumb.
  static let collapsedSeparatorCount: CGFloat = 3

  /// Chooses the shape of the row.
  ///
  /// - Parameters:
  ///   - agentWidth: The width of the agent segment.
  ///   - crumbWidths: The width of the crumb of each session, from the root.
  ///   - overflowWidth: The width of the "..." dropdown.
  ///   - separatorWidth: The width of one separator, with its spacing.
  ///   - available: The width that the row can use.
  /// - Returns: The first shape that fits.
  static func shape(
    agentWidth: CGFloat, crumbWidths: [CGFloat], overflowWidth: CGFloat, separatorWidth: CGFloat,
    available: CGFloat
  ) -> Shape {
    let fullWidth = agentWidth + crumbWidths.reduce(0, +) + separatorWidth * CGFloat(crumbWidths.count)
    if fullWidth <= available { return .full }
    guard crumbWidths.count >= BreadcrumbSegment.fewestToCollapse else { return .truncated }
    let kept = crumbWidths[0] + crumbWidths[crumbWidths.count - 1]
    // The first crumb, the dropdown and the last crumb, each after a separator.
    let collapsedWidth = agentWidth + kept + overflowWidth + separatorWidth * collapsedSeparatorCount
    return collapsedWidth <= available ? .collapsed : .truncated
  }

  /// The indices of the crumbs that a shape holds in the dropdown.
  ///
  /// - Parameters:
  ///   - shape: The shape of the row.
  ///   - count: The number of crumbs.
  /// - Returns: The middle crumbs for a collapsed or truncated row of a path
  ///   that has a middle, and none otherwise.
  static func collapsedIndices(for shape: Shape, count: Int) -> Range<Int> {
    guard shape != .full, count >= BreadcrumbSegment.fewestToCollapse else { return 0..<0 }
    return 1..<(count - 1)
  }
}
