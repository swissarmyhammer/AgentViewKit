import EditorSwiftUI
import EditorTheme
import FoundationModelsACPClient
import SwiftUI

/// A status of the kit in a row: EditorKit's `EditorStatusLabel` in the
/// caption font of the theme, with an accessibility identifier.
///
/// The send state of ``UserMessageView``, the exit label of
/// ``CommandOutputView`` and ``TerminalView``, and the status of an MCP
/// server in ``ConnectionRow`` and in a ``ToolCallView`` that waits for the
/// server show this view, so a change of the font reaches each of them. The
/// label stays one accessibility element: its label is the label of the
/// status, and its value and its help tag are the detail.
struct StatusCaption: View {
  /// The status to show.
  let status: EditorStatus

  /// The accessibility identifier of the label.
  let identifier: String

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    EditorStatusLabel(status)
      .font(editorTheme.font(for: .ui, style: .caption))
      .accessibilityIdentifier(identifier)
  }
}

#Preview("A pending, a sent and a failed message") {
  VStack(alignment: .leading) {
    ForEach([SendState.pending, .sent, .failed], id: \.self) { state in
      StatusCaption(status: EditorStatus(state), identifier: "preview-send-state")
    }
  }
  .padding()
}
