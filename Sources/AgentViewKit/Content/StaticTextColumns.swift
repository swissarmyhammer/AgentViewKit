import SwiftUI

/// The columns of the SwiftUI `Text` of a static text slot, side by side,
/// with one proposal for each column (card ^9ync5h3).
///
/// SwiftUI keeps the measure of a `Text` for its last proposal. A stack
/// asks each child for more than one size, such as its minimum width and
/// its ideal width, and the stacks around a slot ask it for its spacing.
/// Each such query of a new proposal lays the text out again, and the static
/// rows that come into a moving thread pay for it on the main thread.
///
/// The layout gives each column one proposal for a width: each column
/// before the last takes its ideal size, and the last column takes the
/// width that is left, with no height. The layout places each column at the
/// same proposal, so SwiftUI keeps the measure. The layout gives a spacing
/// of its own, and asks no column for its spacing. The columns stand at
/// the top of the layout.
struct StaticTextColumns: Layout {
  /// The space between two columns, in points.
  let spacing: CGFloat

  /// Makes the columns with a space between two columns.
  ///
  /// - Parameter spacing: The space between two columns, in points. The
  ///   default is none.
  init(spacing: CGFloat = .zero) {
    self.spacing = spacing
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let sizes = columnSizes(width: proposal.width, subviews: subviews)
    let height = sizes.map(\.height).max() ?? .zero
    return CGSize(width: proposal.width ?? naturalWidth(of: sizes), height: height)
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    var x = bounds.minX
    for (subview, column) in zip(subviews, columnProposals(width: bounds.width, subviews: subviews)) {
      let size = subview.sizeThatFits(column)
      subview.place(at: CGPoint(x: x, y: bounds.minY), anchor: .topLeading, proposal: column)
      x += size.width + spacing
    }
  }

  /// The spacing of the layout: the default spacing of a view. The layout
  /// asks no column, as each column query of a `Text` lays the text out.
  func spacing(subviews: Subviews, cache: inout ()) -> ViewSpacing {
    ViewSpacing()
  }

  /// No horizontal guide of its own: the default guides would place the
  /// columns and ask them for their guides.
  func explicitAlignment(
    of guide: HorizontalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// No vertical guide of its own, for the reason of the horizontal guide.
  func explicitAlignment(
    of guide: VerticalAlignment, in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews,
    cache: inout ()
  ) -> CGFloat? {
    nil
  }

  /// The size of each column for a width.
  ///
  /// - Parameters:
  ///   - width: The width of the layout, or `nil` for its ideal width.
  ///   - subviews: The columns.
  /// - Returns: The size of each column at its proposal.
  private func columnSizes(width: CGFloat?, subviews: Subviews) -> [CGSize] {
    zip(subviews, columnProposals(width: width, subviews: subviews)).map { $0.sizeThatFits($1) }
  }

  /// The one proposal of each column for a width: the ideal size for each
  /// column before the last, and the width that is left for the last
  /// column, with no height.
  ///
  /// - Parameters:
  ///   - width: The width of the layout, or `nil` for its ideal width.
  ///   - subviews: The columns.
  /// - Returns: The proposal of each column.
  private func columnProposals(width: CGFloat?, subviews: Subviews) -> [ProposedViewSize] {
    let leading = subviews.dropLast().map { _ in ProposedViewSize.unspecified }
    guard !subviews.isEmpty else { return [] }
    let leadingWidth = naturalWidth(of: zip(subviews, leading).map { $0.sizeThatFits($1) })
    let gap = leading.isEmpty ? .zero : spacing
    let left = width.map { max($0 - leadingWidth - gap, .zero) }
    return leading + [ProposedViewSize(width: left, height: nil)]
  }

  /// The width of columns side by side, with the space between them.
  ///
  /// - Parameter sizes: The sizes of the columns.
  /// - Returns: The width, or zero for no column.
  private func naturalWidth(of sizes: [CGSize]) -> CGFloat {
    let widths = sizes.map(\.width).reduce(.zero, +)
    return widths + spacing * CGFloat(max(sizes.count - 1, .zero))
  }
}
