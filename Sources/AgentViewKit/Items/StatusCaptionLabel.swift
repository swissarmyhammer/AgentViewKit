import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// A caption that tells a state: the symbol of the state in its color, and a
/// title in a readable style (^sbx2q4h).
///
/// The color of the state is on the symbol only. A status color, such as the
/// succeeded green, is too light for caption text on the light window
/// background, so the title takes ``titleStyle``. The symbol draws with
/// ``StatusSymbolImage``. The send state of ``UserMessageView`` and the exit
/// label of ``CommandOutputView`` and ``TerminalView`` show this view, so a
/// change of the font or of the title style reaches each of them.
struct StatusCaptionLabel: View {
  /// The style of the title: the primary label color.
  ///
  /// The secondary label color is 3.9:1 on the light window background,
  /// below the 4.5:1 that caption text needs, so the title takes the primary
  /// one (`StatusLabelColorHostedTests`).
  static let titleStyle = HierarchicalShapeStyle.primary

  /// The title of the state.
  let title: String

  /// The SF Symbol name of the state.
  let symbolName: String

  /// The color of the symbol: a color of the EditorKit theme, or
  /// `Color.secondary` for a state with no color.
  let color: Color

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Label {
      Text(title).foregroundStyle(Self.titleStyle)
    } icon: {
      StatusSymbolImage(name: symbolName, color: color)
    }
    .font(editorTheme.font(for: .ui, style: .caption))
  }
}

#Preview("A pending, a sent and a failed message") {
  VStack(alignment: .leading) {
    UserMessageView.SendStateLabel(state: .pending)
    UserMessageView.SendStateLabel(state: .sent)
    UserMessageView.SendStateLabel(state: .failed)
  }
  .padding()
}
