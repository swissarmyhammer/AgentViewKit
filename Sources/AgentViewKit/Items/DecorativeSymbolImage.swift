import EditorSwiftUI
import SwiftUI

/// A decorative symbol of a header: the symbol before its title.
///
/// The view draws the symbol with EditorKit's `EditorSymbolImage` in the
/// neutral tone, which is `\.placedSecondary` and the symbol weight of the
/// shared style, and hides it from accessibility, because the text next to
/// it tells the same thing. The symbol does not use the accent
/// of the EditorKit theme: the accent is only for the selection and the focus
/// (card ^y2mrfxt).
///
/// ``AgentInfoHeader`` and the header of ``ConversationEmptyState`` draw their
/// symbols with this view, so a change of the style, of the weight or of the
/// accessibility trait reaches each of them. The symbol takes the font of the
/// view that contains it.
struct DecorativeSymbolImage: View {
  /// The SF Symbol name. Read it from ``AgentSymbol``, from EditorKit's
  /// `EditorSymbol` or from the host.
  let name: String

  var body: some View {
    EditorSymbolImage(systemName: name, tone: .neutral)
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
