import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The layout of a status text: a title line, and an explanation below it.
///
/// The title line holds the symbol, the title, a flexible space and the action,
/// with the symbol and the action centered on the title. A title that wraps
/// keeps them centered on its lines. The explanation stands below the title
/// line with its leading edge under the title, and it wraps at the full width
/// of the layout, below the action too. So its length moves neither the symbol
/// nor the action, and with no explanation the layout is only the title line.
///
/// A ``StatusBar`` shows its message with this layout, and so does each view
/// with a symbol, a title and an explanation that a bar cannot hold, such as a
/// card that goes on below its header. The layout has no padding and no edge of
/// its own (`style.md`, rule 10): the view that holds it gives them.
///
/// The title is the one accessibility element of the text. It carries the label
/// of the title and the explanation, and the explanation is hidden, because no
/// one view holds the two: the action stands between them.
public struct StatusTitleLayout<Symbol: View, Action: View>: View {
  /// The title.
  let title: String

  /// The explanation. An empty explanation shows no line.
  let explanation: String

  /// The accessibility label of the text.
  let textLabel: String

  /// The accessibility identifier of the text.
  let identifier: String

  /// The symbol at the start of the title line.
  let symbol: Symbol

  /// The action at the end of the title line.
  let action: Action

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.editorTheme) private var editorTheme

  /// Makes the layout of a status text.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - explanation: The explanation. An empty explanation shows no line.
  ///   - textLabel: The accessibility label of the text.
  ///   - identifier: The accessibility identifier of the text.
  ///   - symbol: The symbol at the start of the title line.
  ///   - action: The action at the end of the title line.
  public init(
    title: String, explanation: String, textLabel: String, identifier: String,
    @ViewBuilder symbol: () -> Symbol, @ViewBuilder action: () -> Action
  ) {
    self.title = title
    self.explanation = explanation
    self.textLabel = textLabel
    self.identifier = identifier
    self.symbol = symbol()
    self.action = action()
  }

  public var body: some View {
    TitleLineStack(symbolGap: editorStyle.spacing.m, lineGap: editorStyle.spacing.xs) {
      // One subview, whatever the builder of the symbol holds.
      HStack(spacing: .zero) { symbol }
      titleLine
      if !explanation.isEmpty {
        explanationText
      }
    }
  }

  /// The title, a flexible space and the action.
  private var titleLine: some View {
    HStack(spacing: editorStyle.spacing.m) {
      Text(title)
        .font(editorTheme.font(for: .ui, style: .headline))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(textLabel)
        .accessibilityIdentifier(identifier)
      Spacer(minLength: editorStyle.spacing.s)
      action
    }
  }

  /// The explanation. The element of the title reads it.
  private var explanationText: some View {
    Text(explanation)
      .font(editorTheme.font(for: .ui, style: .callout))
      .foregroundStyle(.secondary)
      .textSelection(.enabled)
      .accessibilityHidden(true)
  }
}

/// Places a symbol, a title line and an optional explanation: the symbol and
/// the title line on one row, centered on each other, and the explanation below
/// the title line, with the width of the title line.
///
/// A `Grid` does not do this: with a text that wraps in its second row, a grid
/// gives its flexible column less than the proposed width, so the bar shrinks.
private struct TitleLineStack: Layout {
  /// The space between the symbol and the title line.
  let symbolGap: CGFloat

  /// The space between the title line and the explanation.
  let lineGap: CGFloat

  /// The sizes of the subviews in one width.
  private struct Metrics {
    /// The distance of the title line and the explanation from the leading edge.
    let textLeading: CGFloat

    /// The width of the title line and the explanation.
    let textWidth: CGFloat

    /// The height of the row of the symbol and the title line.
    let rowHeight: CGFloat

    /// The height of the explanation, or `nil` for no explanation.
    let explanationHeight: CGFloat?

    /// The width of the whole stack.
    let width: CGFloat

    /// The height of the whole stack.
    func height(lineGap: CGFloat) -> CGFloat {
      explanationHeight.map { rowHeight + lineGap + $0 } ?? rowHeight
    }
  }

  /// Measures the subviews.
  ///
  /// The texts get what remains of the proposed height, as in a `VStack`, so
  /// the small proposal that asks for the least size of the stack gives a small
  /// size and not the height of a text in no width.
  ///
  /// - Parameters:
  ///   - proposal: The proposed size. A proposal with no width asks for the
  ///     ideal width.
  ///   - subviews: The symbol, the title line and the optional explanation.
  /// - Returns: The sizes, or `nil` with no symbol or no title line.
  private func metrics(in proposal: ProposedViewSize, subviews: Subviews) -> Metrics? {
    guard subviews.count > 1 else { return nil }
    let (symbol, titleLine) = (subviews[0], subviews[1])
    let explanation = subviews.count > 2 ? subviews[2] : nil
    let symbolSize = symbol.sizeThatFits(.unspecified)
    let textLeading = symbolSize.width + symbolGap
    let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth(
      textLeading: textLeading, of: [titleLine, explanation].compactMap(\.self))
    let textWidth = max(width - textLeading, .zero)
    let titleProposal = ProposedViewSize(width: textWidth, height: proposal.height)
    let rowHeight = max(symbolSize.height, titleLine.sizeThatFits(titleProposal).height)
    let remainingHeight = proposal.height.map { max($0 - rowHeight - lineGap, .zero) }
    return Metrics(
      textLeading: textLeading, textWidth: textWidth, rowHeight: rowHeight,
      explanationHeight: explanation?.sizeThatFits(ProposedViewSize(width: textWidth, height: remainingHeight)).height,
      width: width)
  }

  /// The width at which no text wraps.
  ///
  /// - Parameters:
  ///   - textLeading: The distance of the texts from the leading edge.
  ///   - texts: The title line and the optional explanation.
  /// - Returns: The ideal width of the stack.
  private func idealWidth(textLeading: CGFloat, of texts: [LayoutSubview]) -> CGFloat {
    textLeading + (texts.map { $0.sizeThatFits(.unspecified).width }.max() ?? .zero)
  }

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    guard let metrics = metrics(in: proposal, subviews: subviews) else { return .zero }
    // The title line has a flexible space, so the stack takes all the width of
    // a proposal, as an endless one too.
    return CGSize(width: proposal.width ?? metrics.width, height: metrics.height(lineGap: lineGap))
  }

  func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
    guard let metrics = metrics(in: ProposedViewSize(bounds.size), subviews: subviews) else { return }
    let rowCenter = bounds.minY + metrics.rowHeight / 2
    let textEdge = bounds.minX + metrics.textLeading
    subviews[0].place(at: CGPoint(x: bounds.minX, y: rowCenter), anchor: .leading, proposal: .unspecified)
    subviews[1].place(
      at: CGPoint(x: textEdge, y: rowCenter), anchor: .leading,
      proposal: ProposedViewSize(width: metrics.textWidth, height: metrics.rowHeight))
    if let explanationHeight = metrics.explanationHeight {
      subviews[2].place(
        at: CGPoint(x: textEdge, y: bounds.minY + metrics.rowHeight + lineGap), anchor: .topLeading,
        proposal: ProposedViewSize(width: metrics.textWidth, height: explanationHeight))
    }
  }
}

extension StatusTitleLayout where Action == EmptyView {
  /// Makes the layout of a status text with no action.
  ///
  /// - Parameters:
  ///   - title: The title.
  ///   - explanation: The explanation. An empty explanation shows no line.
  ///   - textLabel: The accessibility label of the text.
  ///   - identifier: The accessibility identifier of the text.
  ///   - symbol: The symbol at the start of the title line.
  public init(
    title: String, explanation: String, textLabel: String, identifier: String, @ViewBuilder symbol: () -> Symbol
  ) {
    self.init(
      title: title, explanation: explanation, textLabel: textLabel, identifier: identifier, symbol: symbol,
      action: { EmptyView() })
  }
}
