import EditorSwiftUI
import FoundationModelsACP
import SwiftUI

/// The status symbol of a tool call, in the status color of the EditorKit
/// theme.
///
/// The view shows the EditorKit status symbol of the ACP status
/// (`EditorSymbol.Status`) with EditorKit's `EditorSymbolImage`, in the tone
/// of the status. ``ToolCallView`` and ``ActivityTimeline`` show the status of
/// a call with this view, so a change of the symbol or the color reaches
/// both. A caller adds its own symbol effects to the view.
struct ToolStatusImage: View {
  /// The ACP status of the call.
  let status: FoundationModelsACP.ToolCallStatus

  var body: some View {
    EditorSymbolImage(.status(.init(status)))
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
