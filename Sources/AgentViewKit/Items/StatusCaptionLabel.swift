import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// A caption that tells a state: the symbol of the state in its color, and a
/// title in a readable style (^sbx2q4h).
///
/// The color of the state is on the symbol only. The title has no style of its
/// own, so it draws in the root foreground, because the secondary color is
/// 3.9:1 on the light window background, below the 4.5:1 of caption text, and a
/// status color, such as the succeeded green, is too light. The symbol draws
/// with EditorKit's `EditorSymbolImage`. The send state of ``UserMessageView`` and the
/// exit label of ``CommandOutputView`` and ``TerminalView`` show this view, so
/// a change of the font reaches each of them.
struct StatusCaptionLabel: View {
  /// The title of the state.
  let title: String

  /// The SF Symbol name of the state.
  let symbolName: String

  /// The tone of the theme the symbol draws in: a status token, or the
  /// neutral tone for a state with no color.
  let tone: EditorSymbol.Tone

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Label {
      Text(title)
    } icon: {
      EditorSymbolImage(systemName: symbolName, tone: tone)
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
