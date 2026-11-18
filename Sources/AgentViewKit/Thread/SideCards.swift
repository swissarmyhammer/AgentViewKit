import EditorStyle
import SwiftUI

/// The layout of the side cards of a thread (D205): a vertical stack at the
/// trailing edge, in the order of the host, the first card at the top.
///
/// Each card has the card width, at the trailing edge of the stack. When the
/// stack is narrower than the narrow width, each card has the full width of
/// the stack. The stack is as tall as its cards and the spacing between
/// them.
struct SideCardLayout: Layout {
  /// The width of a card at the default theme font, in points.
  static let defaultCardWidth: CGFloat = 320

  /// The width of a thread under which each card has the full width, at the
  /// default theme font, in points.
  static let defaultNarrowWidth: CGFloat = 640

  /// The width of each card in a wide stack.
  let cardWidth: CGFloat

  /// The width under which each card has the full width of the stack.
  let narrowWidth: CGFloat

  /// The space between two cards.
  let spacing: CGFloat

  /// The width of each card in a stack of a width.
  ///
  /// - Parameter available: The width of the stack.
  /// - Returns: `available` in a narrow stack, else the card width, at most
  ///   `available`.
  func width(in available: CGFloat) -> CGFloat {
    available < narrowWidth ? available : min(cardWidth, available)
  }

  /// The height of a stack of cards.
  ///
  /// - Parameter heights: The height of each card, in order.
  /// - Returns: The sum of the heights and of the spacing between the cards.
  func height(of heights: [CGFloat]) -> CGFloat {
    heights.reduce(0, +) + spacing * CGFloat(max(heights.count - 1, 0))
  }

  /// The frame of each card in `bounds`, from the top, each at the trailing
  /// edge.
  ///
  /// - Parameters:
  ///   - heights: The height of each card, in the order of the host.
  ///   - bounds: The bounds of the stack.
  /// - Returns: The frames, in the order of `heights`.
  func frames(heights: [CGFloat], in bounds: CGRect) -> [CGRect] {
    let width = width(in: bounds.width)
    let tops = heights.indices.map { position in
      bounds.minY + heights[..<position].reduce(0, +) + spacing * CGFloat(position)
    }
    return zip(tops, heights).map { top, height in
      CGRect(x: bounds.maxX - width, y: top, width: width, height: height)
    }
  }

  /// The size of the stack: the proposed width, or the card width with no
  /// proposal, and the height of the cards and the spacing between them.
  ///
  /// - Parameters:
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The cards, newest first.
  ///   - cache: The cache of the layout. The layout keeps no cache.
  /// - Returns: The size of the stack.
  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let available = proposal.width ?? cardWidth
    let heights = heights(of: subviews, width: width(in: available))
    return CGSize(width: available, height: height(of: heights))
  }

  /// Puts each card at its frame in `bounds`, newest at the top.
  ///
  /// - Parameters:
  ///   - bounds: The bounds of the stack.
  ///   - proposal: The size that the parent proposes.
  ///   - subviews: The cards, newest first.
  ///   - cache: The cache of the layout. The layout keeps no cache.
  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let heights = heights(of: subviews, width: width(in: bounds.width))
    for (subview, frame) in zip(subviews, frames(heights: heights, in: bounds)) {
      subview.place(at: frame.origin, anchor: .topLeading, proposal: ProposedViewSize(frame.size))
    }
  }

  /// The height of each card at a width.
  ///
  /// - Parameters:
  ///   - subviews: The cards.
  ///   - width: The width of each card.
  /// - Returns: The heights, in order.
  private func heights(of subviews: Subviews, width: CGFloat) -> [CGFloat] {
    subviews.map { $0.sizeThatFits(ProposedViewSize(width: width, height: nil)).height }
  }
}

/// The stack of the side cards of a thread, in the ``SideCardLayout`` of the
/// theme font.
///
/// The card width and the narrow width scale with the UI font of the theme
/// (`ThemeFontScale`), and the spacing is the small spacing of the style.
struct SideCardStack: View {
  /// The cards, in the order of the host, newest first.
  let cards: AnyView

  /// The style of the editor, for the spacing between the cards.
  @Environment(\.editorStyle) private var editorStyle

  /// The scale of the UI font of the theme, for the widths of the layout.
  @ThemeFontScale(.ui) private var fontScale

  /// The cards in the side card layout.
  var body: some View {
    SideCardLayout(
      cardWidth: SideCardLayout.defaultCardWidth * fontScale,
      narrowWidth: SideCardLayout.defaultNarrowWidth * fontScale, spacing: editorStyle.spacing.s
    ) {
      cards
    }
  }
}

/// The environment value that carries the side cards of a thread.
extension EnvironmentValues {
  /// The side cards that the nearest ``AgentThreadView`` shows above its
  /// composer, or `nil`. Set it with ``AgentThreadView/sideCards(_:)``.
  @Entry var sideCards: AnyView? = nil
}

/// The side card slot of the thread view.
extension AgentThreadView {
  /// Shows side cards, such as ``SideQuestionCard`` views, next to the chat
  /// (D205).
  ///
  /// The cards stand in a vertical stack at the trailing edge of the thread,
  /// above the composer, in the order that the host gives: give the newest
  /// card first, so it is at the top. In a narrow thread, the stack goes
  /// above the composer at the full width. The stack floats over the
  /// conversation with the floating controls, as the scroll-to-bottom pill
  /// does: it takes no space in the bottom bar, so it does not change the
  /// transcript, the bottom inset of the list or the scroll position. The
  /// cards are in the agent command scope of the thread, so Send to Chat of a
  /// card reaches the composer of the thread.
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .sideCards {
  ///     ForEach(newestFirst) { side in
  ///       SideQuestionCard(
  ///         question: side.question, session: side.fork,
  ///         onOpen: { host.open(side) }, onClose: { host.remove(side) })
  ///     }
  ///   }
  /// ```
  ///
  /// - Parameter cards: The cards, newest first.
  /// - Returns: The thread view with the cards.
  public func sideCards<Cards: View>(@ViewBuilder _ cards: () -> Cards) -> some View {
    environment(\.sideCards, AnyView(cards()))
  }
}
