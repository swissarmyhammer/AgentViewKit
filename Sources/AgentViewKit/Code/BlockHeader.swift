import EditorStyle
import EditorTheme
import SwiftUI

/// The header of a block: a title, buttons and a line (user decision,
/// 2026-11-21). ``CodeBlockView`` and each block of ``AttachmentInspector``
/// show their header with this view, so the two headers have the same
/// spacing and the same look.
///
/// When the title and the buttons fit on one line, the title is at the
/// leading edge, the buttons are at the trailing edge, and the line is under
/// the row. When they do not fit, the title is at the top, the line is under
/// it, and the buttons are under the line. ``BlockHeaderLayout`` makes this
/// decision.
///
/// The title takes the caption style of the `ui` font role of the theme and
/// the secondary color of the theme, on one line with middle truncation. The
/// space between the title and the buttons is the small spacing of
/// `\.editorStyle`. The line is in the middle of a tile gap: under the row on
/// one line, and between the title and the buttons in a column. The header is
/// content, not a bar (D113), so it has no fill.
struct BlockHeader<Title: View, Actions: View>: View {
  /// The title of the block, such as a file name.
  let title: Title

  /// The buttons of the block.
  let actions: Actions

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.themeSecondary) private var themeSecondary

  /// Makes the header of a block.
  ///
  /// - Parameters:
  ///   - title: The title of the block.
  ///   - actions: The buttons of the block.
  init(@ViewBuilder title: () -> Title, @ViewBuilder actions: () -> Actions) {
    self.title = title()
    self.actions = actions()
  }

  var body: some View {
    // Each part is in a stack of its own, so the layout always gets three
    // subviews: also for a title of several views, and for buttons that show
    // no view. The vertical stack of the line makes the `Divider` a
    // horizontal line also when the host is a horizontal stack, such as a
    // row of a form.
    BlockHeaderLayout(spacing: editorStyle.spacing.s, gap: editorStyle.tile.gap) {
      HStack(spacing: editorStyle.spacing.s) {
        title
      }
      .font(editorTheme.font(for: .ui, style: .caption))
      .foregroundStyle(themeSecondary)
      .lineLimit(1)
      .truncationMode(.middle)
      VStack(spacing: 0) {
        Divider()
      }
      HStack(spacing: editorStyle.spacing.s) {
        actions
      }
    }
  }
}

/// The layout of a ``BlockHeader``: the title, the line and the buttons, in
/// that order of subviews.
///
/// When the title and the buttons fit on one line
/// (``fitsOnOneLine(titleWidth:actionsWidth:spacing:available:)``), the
/// title is at the leading edge and the buttons are at the trailing edge,
/// with the same vertical center. The line is in the middle of the tile gap
/// under the row, and takes no space in the layout, as the line of
/// ``EditorBlockHeader`` does: the host puts the tile gap under the header.
/// When they do not fit, the title is at the top, the line is in the middle
/// of a tile gap under the title, and the buttons are under the gap, at the
/// leading edge. A header with no buttons stays on one line, and its title
/// truncates.
struct BlockHeaderLayout: Layout {
  /// The frames of the parts of a header.
  struct Frames {
    /// The frame of the title.
    let title: CGRect

    /// The frame of the line.
    let line: CGRect

    /// The frame of the buttons.
    let actions: CGRect
  }

  /// The space between the title and the buttons on one line.
  let spacing: CGFloat

  /// The tile gap, with the line in its middle.
  let gap: CGFloat

  /// The fraction of a length at its middle. A part that is centered on a
  /// position has this fraction of its length on each side of the position.
  nonisolated static let middle: CGFloat = 0.5

  /// Whether the title and the buttons fit on one line.
  ///
  /// - Parameters:
  ///   - titleWidth: The width of the title.
  ///   - actionsWidth: The width of the buttons.
  ///   - spacing: The space between the title and the buttons.
  ///   - available: The width of the header.
  /// - Returns: `true` when the title, the spacing and the buttons are not
  ///   wider than `available`.
  static func fitsOnOneLine(
    titleWidth: CGFloat, actionsWidth: CGFloat, spacing: CGFloat, available: CGFloat
  )
    -> Bool
  {
    titleWidth + spacing + actionsWidth <= available
  }

  /// The size of a header.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - actions: The size of the buttons.
  ///   - width: The proposed width, or `nil` for the width of the parts on
  ///     one line.
  /// - Returns: The size of the header.
  func size(title: CGSize, actions: CGSize, width: CGFloat?) -> CGSize {
    let available = width ?? oneLineWidth(title: title, actions: actions)
    guard isOneLine(title: title, actions: actions, available: available) else {
      return CGSize(width: available, height: title.height + gap + actions.height)
    }
    return CGSize(width: available, height: max(title.height, actions.height))
  }

  /// The frames of the parts of a header in `bounds`.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - lineHeight: The height of the line.
  ///   - actions: The size of the buttons.
  ///   - bounds: The bounds of the header.
  /// - Returns: The frames of the title, the line and the buttons.
  func frames(title: CGSize, lineHeight: CGFloat, actions: CGSize, in bounds: CGRect) -> Frames {
    guard isOneLine(title: title, actions: actions, available: bounds.width) else {
      return columnFrames(title: title, lineHeight: lineHeight, actions: actions, in: bounds)
    }
    return rowFrames(title: title, lineHeight: lineHeight, actions: actions, in: bounds)
  }

  /// The size of the header.
  ///
  /// - Parameters:
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The title, the line and the buttons.
  ///   - cache: The cache of the layout. The layout keeps no cache.
  /// - Returns: The size of the header.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let parts = Parts(subviews)
    return size(title: parts.titleSize, actions: parts.actionsSize, width: proposal.width)
  }

  /// Puts the title, the line and the buttons at their frames in `bounds`.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the header.
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The title, the line and the buttons.
  ///   - cache: The cache of the layout. The layout keeps no cache.
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let parts = Parts(subviews)
    let lineHeight =
      parts.line?.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height ?? 0
    let frames = frames(
      title: parts.titleSize, lineHeight: lineHeight, actions: parts.actionsSize, in: bounds)
    for (subview, frame) in zip(
      [parts.title, parts.line, parts.actions], [frames.title, frames.line, frames.actions])
    {
      subview?.place(at: frame.origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }
  }

  /// The width of a header with the title and the buttons on one line.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - actions: The size of the buttons.
  /// - Returns: The width of the title, the spacing and the buttons.
  private func oneLineWidth(title: CGSize, actions: CGSize) -> CGFloat {
    title.width + spacing(before: actions) + actions.width
  }

  /// The space between the title and `actions`: none when there are no
  /// buttons.
  ///
  /// - Parameter actions: The size of the buttons.
  /// - Returns: The spacing.
  private func spacing(before actions: CGSize) -> CGFloat {
    actions.width > 0 ? spacing : 0
  }

  /// Whether the header shows its parts on one line: when they fit, and
  /// always when there are no buttons.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - actions: The size of the buttons.
  ///   - available: The width of the header.
  /// - Returns: `true` for one line.
  private func isOneLine(title: CGSize, actions: CGSize, available: CGFloat) -> Bool {
    actions.width <= 0
      || Self.fitsOnOneLine(
        titleWidth: title.width, actionsWidth: actions.width, spacing: spacing, available: available
      )
  }

  /// The frames on one line: the title at the leading edge and the buttons
  /// at the trailing edge, centered on the row, and the line in the middle
  /// of the tile gap under the row.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - lineHeight: The height of the line.
  ///   - actions: The size of the buttons.
  ///   - bounds: The bounds of the header.
  /// - Returns: The frames.
  private func rowFrames(title: CGSize, lineHeight: CGFloat, actions: CGSize, in bounds: CGRect)
    -> Frames
  {
    let rowHeight = max(title.height, actions.height)
    let titleWidth = min(title.width, bounds.width - spacing(before: actions) - actions.width)
    return Frames(
      title: CGRect(
        x: bounds.minX, y: bounds.minY + centeringOffset(of: title.height, in: rowHeight),
        width: titleWidth, height: title.height),
      line: lineFrame(centeredAt: bounds.minY + rowHeight, height: lineHeight, in: bounds),
      actions: CGRect(
        x: bounds.maxX - actions.width,
        y: bounds.minY + centeringOffset(of: actions.height, in: rowHeight),
        width: actions.width, height: actions.height))
  }

  /// The offset that centers a length in a longer extent.
  ///
  /// - Parameters:
  ///   - length: The length of the part, such as the height of the title.
  ///   - extent: The length that holds the part, such as the height of the row.
  /// - Returns: The space before the part, so that the part is in the middle
  ///   of `extent`.
  private func centeringOffset(of length: CGFloat, in extent: CGFloat) -> CGFloat {
    (extent - length) * Self.middle
  }

  /// The frames in a column: the title at the top, the line in the middle
  /// of the tile gap under it, and the buttons under the gap, each at the
  /// leading edge.
  ///
  /// - Parameters:
  ///   - title: The size of the title.
  ///   - lineHeight: The height of the line.
  ///   - actions: The size of the buttons.
  ///   - bounds: The bounds of the header.
  /// - Returns: The frames.
  private func columnFrames(title: CGSize, lineHeight: CGFloat, actions: CGSize, in bounds: CGRect)
    -> Frames
  {
    let titleBottom = bounds.minY + title.height
    return Frames(
      title: CGRect(
        x: bounds.minX, y: bounds.minY, width: min(title.width, bounds.width), height: title.height),
      line: lineFrame(centeredAt: titleBottom, height: lineHeight, in: bounds),
      actions: CGRect(
        x: bounds.minX, y: titleBottom + gap, width: min(actions.width, bounds.width),
        height: actions.height))
  }

  /// The frame of the line in the middle of the tile gap under `top`, at
  /// the full width of the header.
  ///
  /// - Parameters:
  ///   - top: The top of the tile gap.
  ///   - height: The height of the line.
  ///   - bounds: The bounds of the header.
  /// - Returns: The frame of the line.
  private func lineFrame(centeredAt top: CGFloat, height: CGFloat, in bounds: CGRect) -> CGRect {
    let center = top + gap * EditorBlockHeader.separatorPlacement
    return CGRect(
      x: bounds.minX, y: center - height * Self.middle, width: bounds.width, height: height)
  }
}

extension BlockHeaderLayout {
  /// The subviews of a header, with the ideal size of the title and of the
  /// buttons.
  private struct Parts {
    /// The position of each part in the subviews of a header. The raw value
    /// is the index of the subview.
    enum Position: Int {
      /// The title, the first subview.
      case title

      /// The line, the second subview.
      case line

      /// The buttons, the third subview.
      case actions
    }

    /// The title, or `nil` when the header has no subview.
    let title: LayoutSubview?

    /// The line, or `nil` when the header has fewer than two subviews.
    let line: LayoutSubview?

    /// The buttons, or `nil` when the header has fewer than three subviews.
    let actions: LayoutSubview?

    /// Reads the parts of a header.
    ///
    /// - Parameter subviews: The title, the line and the buttons.
    init(_ subviews: LayoutSubviews) {
      let parts = Array(subviews)
      title = Self.subview(at: .title, of: parts)
      line = Self.subview(at: .line, of: parts)
      actions = Self.subview(at: .actions, of: parts)
    }

    /// The subview at a position.
    ///
    /// - Parameters:
    ///   - position: The position of the part.
    ///   - parts: The subviews of the header.
    /// - Returns: The subview, or `nil` when the header has no subview at
    ///   `position`.
    private static func subview(at position: Position, of parts: [LayoutSubview]) -> LayoutSubview?
    {
      parts.indices.contains(position.rawValue) ? parts[position.rawValue] : nil
    }

    /// The ideal size of the title, or zero with no title.
    var titleSize: CGSize { title?.sizeThatFits(.unspecified) ?? .zero }

    /// The ideal size of the buttons, or zero with no buttons.
    var actionsSize: CGSize { actions?.sizeThatFits(.unspecified) ?? .zero }
  }
}

#Preview("A block header on one line and in a column") {
  VStack(alignment: .leading, spacing: EditorStyle.default.tile.margin) {
    ForEach(PreviewFixtures.blockHeaderWidths, id: \.self) { width in
      BlockHeader {
        Text(PreviewFixtures.codeSampleFilename)
      } actions: {
        Button(String(localized: "Copy code", bundle: .module), systemImage: AgentSymbol.copy) {}
          .labelStyle(.iconOnly)
      }
      .frame(width: width)
    }
  }
  .padding()
}
