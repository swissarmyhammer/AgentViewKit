import EditorStyle
import SwiftUI

/// A decorative symbol of a header: the symbol before its title, or the
/// chevron between two segments of its breadcrumb.
///
/// The view shows the symbol with `\.placedSecondary` and the symbol
/// weight of the shared style, and hides it from accessibility, because the
/// text next to it tells the same thing. The symbol does not use the accent
/// of the EditorKit theme: the accent is only for the selection and the focus
/// (card ^y2mrfxt).
///
/// ``AgentInfoHeader`` and the header of ``ConversationEmptyState`` draw their
/// symbols with this view, so a change of the style, of the weight or of the
/// accessibility trait reaches each of them. The symbol takes the font of the
/// view that contains it.
struct DecorativeSymbolImage: View {
  /// The SF Symbol name. Read it from ``SharedSymbol`` or from the host.
  let name: String

  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.placedSecondary) private var placedSecondary

  var body: some View {
    Image(systemName: name)
      .foregroundStyle(placedSecondary)
      .fontWeight(editorStyle.symbolWeight)
      .accessibilityHidden(true)
  }
}

// MARK: - Previews

#Preview("Each decorative header symbol") {
  PreviewSymbolSheet(title: "Header symbol", values: PreviewFixtures.headerSymbols, label: \.header) { symbol in
    DecorativeSymbolImage(name: symbol.name)
  }
  .padding()
}
