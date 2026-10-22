import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The sheet of the states of an icon view, for the `#Preview` of the view.
///
/// The sheet is a grid with a title and one row for each state: the icon of
/// the state, then the name of the state. No view of the kit sets a font on
/// its icons, so the kit draws each icon at the prose font of the EditorKit
/// theme, the body font of its row. The sheet draws the icons and the names
/// at that font.
struct PreviewSymbolSheet<Value: Hashable, Icon: View>: View {
  /// The title of the sheet, such as the name of the type of the states.
  let title: String

  /// The states, in the order of the rows.
  let values: [Value]

  /// The function that gives the name of a state.
  let label: (Value) -> String

  /// The function that makes the icon of a state.
  @ViewBuilder let icon: (Value) -> Icon

  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      Text(title)
        .font(.headline)
      Grid(alignment: .leading, horizontalSpacing: theme.spacing.m, verticalSpacing: theme.spacing.s) {
        ForEach(values, id: \.self) { value in
          GridRow {
            icon(value)
            Text(label(value))
          }
        }
      }
      .font(editorTheme.proseFont)
    }
  }
}
