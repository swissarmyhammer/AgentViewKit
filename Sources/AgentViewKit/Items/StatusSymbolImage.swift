import SwiftUI

/// The symbol of a state, such as a status or a priority, in a color of the
/// EditorKit theme.
///
/// The view shows the symbol with the hierarchical rendering mode of the
/// status views and the symbol weight of the kit theme. Each caller keeps its
/// own map from its state to the symbol name and to the color.
/// ``ToolStatusImage``, the plan entry of ``TaskListView``, `StatusBar`, the
/// header of ``CompactionEntryView``, the card of ``ErrorView``, the banner of
/// ``SessionNoticeBanner`` and the rows of ``ActivityTimeline`` draw their
/// symbols with this view, so a change of the rendering mode or of the weight
/// reaches each of them. A caller adds its own symbol effects to
/// the view.
struct StatusSymbolImage: View {
  /// The SF Symbol name. Read it from ``SharedSymbol`` or from the symbol map
  /// of the caller.
  let name: String

  /// The color of the symbol: a color of the EditorKit theme, or
  /// `Color.secondary` for a row with no state color.
  let color: Color

  @Environment(\.agentTheme) private var theme

  var body: some View {
    Image(systemName: name)
      .symbolRenderingMode(.hierarchical)
      .fontWeight(theme.symbolWeight)
      .foregroundStyle(color)
  }
}
