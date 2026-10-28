import EditorStyle
import SwiftUI

/// A layout that puts its views in rows, and starts a new row when a view
/// does not fit.
///
/// Each view gets its ideal size, at most the width of a row, so a chip
/// wider than the row truncates its own text. The location chips of a tool
/// call (``ToolCallLocationChips``) and the file chips of a diff
/// (``DiffFileChip``) use it.
public struct ChipFlowLayout: Layout {
  /// The space between two views, and between two rows.
  let spacing: CGFloat

  /// Makes the layout.
  ///
  /// - Parameter spacing: The space between two views, and between two rows.
  public init(spacing: CGFloat) {
    self.spacing = spacing
  }

  /// The size of the rows of `subviews` in the width of `proposal`.
  ///
  /// - Parameters:
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The views to arrange.
  ///   - cache: No cache.
  /// - Returns: The width of the widest row, and the height of all rows.
  public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let frames = arrange(subviews, width: proposal.width ?? .infinity)
    let width = frames.map(\.maxX).max() ?? 0
    let height = frames.map(\.maxY).max() ?? 0
    return CGSize(width: width, height: height)
  }

  /// Places each view of `subviews` in its row.
  ///
  /// - Parameters:
  ///   - bounds: The frame of the layout.
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The views to place.
  ///   - cache: No cache.
  public func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let frames = arrange(subviews, width: bounds.width)
    for (subview, frame) in zip(subviews, frames) {
      subview.place(
        at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY),
        proposal: ProposedViewSize(frame.size))
    }
  }

  /// The frame of each view, from the top left corner of the layout.
  ///
  /// - Parameters:
  ///   - subviews: The views to arrange.
  ///   - width: The width of a row.
  /// - Returns: One frame for each view, in order.
  private func arrange(_ subviews: Subviews, width: CGFloat) -> [CGRect] {
    var frames: [CGRect] = []
    var origin = CGPoint.zero
    var rowHeight: CGFloat = 0
    for subview in subviews {
      var size = subview.sizeThatFits(.unspecified)
      size.width = min(size.width, width)
      if origin.x > 0, origin.x + size.width > width {
        origin.x = 0
        origin.y += rowHeight + spacing
        rowHeight = 0
      }
      frames.append(CGRect(origin: origin, size: size))
      origin.x += size.width + spacing
      rowHeight = max(rowHeight, size.height)
    }
    return frames
  }
}

#Preview("Chips in rows that wrap") {
  ChipFlowLayout(spacing: EditorStyle.default.spacing.xs) {
    ForEach(StylePreviewFixtures.chipTitles, id: \.self) { title in
      Text(title)
    }
  }
  .frame(width: StylePreviewFixtures.narrowWidth)
  .padding()
}
