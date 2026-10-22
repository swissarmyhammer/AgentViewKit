import SwiftUI

/// The decorative symbol before the title of a header.
///
/// The view shows the symbol with the `.secondary` style and the symbol
/// weight of the kit theme, and hides it from accessibility, because the
/// title next to it tells the same thing. The symbol does not use the accent
/// of the EditorKit theme: in content, the accent marks only a link, the
/// selection or the current item (D113 answer 5).
///
/// ``AgentInfoHeader`` and the header of ``ConversationEmptyState`` draw their
/// symbols with this view, so a change of the style, of the weight or of the
/// accessibility trait reaches each of them. The symbol takes the font of the
/// view that contains it.
struct DecorativeSymbolImage: View {
  /// The SF Symbol name. Read it from ``SharedSymbol`` or from the host.
  let name: String

  @Environment(\.agentTheme) private var theme

  var body: some View {
    Image(systemName: name)
      .foregroundStyle(.secondary)
      .fontWeight(theme.symbolWeight)
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
