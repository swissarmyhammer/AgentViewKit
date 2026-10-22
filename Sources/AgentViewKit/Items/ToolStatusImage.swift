import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The status symbol of a tool call, in the status color of the EditorKit
/// theme.
///
/// The view shows the symbol of ``ToolStatusSymbol/name(for:)`` in the color
/// of `Theme.statusColor(for:)`, with the shared treatment of
/// ``StatusSymbolImage``. ``ToolCallView`` and ``ActivityTimeline`` show the
/// status of a call with this view, so a change of the symbol or the color
/// reaches both. A caller adds its own symbol effects to the view.
struct ToolStatusImage: View {
  /// The ACP status of the call.
  let status: FoundationModelsACP.ToolCallStatus

  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    StatusSymbolImage(
      name: ToolStatusSymbol.name(for: status),
      color: editorTheme.statusColor(for: status))
  }
}

// MARK: - Previews

#Preview("Each status of a tool call") {
  PreviewSymbolSheet(
    title: "Tool call status", values: PreviewFixtures.toolCallStatuses, label: ToolStatusSymbol.label(for:)
  ) { status in
    ToolStatusImage(status: status)
  }
  .padding()
}
