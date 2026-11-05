import EditorSwiftUI
import FoundationModelsACP
import SwiftUI

/// The status symbol of a tool call, in the status color of the EditorKit
/// theme.
///
/// The view shows the symbol of the EditorKit status token of the ACP status
/// (`EditorStatus`) with EditorKit's `EditorSymbolImage`, in the tone of the
/// status. ``ToolCallView`` and ``ActivityTimeline`` show the status of a
/// call with this view, so a change of the symbol or the color reaches both.
/// A caller adds its own symbol effects to the view, such as the live effect
/// of a status that goes on (`EditorStatus.isLive`).
struct ToolStatusImage: View {
  /// The ACP status of the call.
  let status: FoundationModelsACP.ToolCallStatus

  var body: some View {
    let token = EditorStatus(status)
    EditorSymbolImage(systemName: token.systemImage, tone: token.tone)
  }
}

// MARK: - Previews

#Preview("Each status of a tool call") {
  PreviewSymbolSheet(
    title: "Tool call status", values: PreviewFixtures.toolCallStatuses, label: { EditorStatus($0).summary }
  ) { status in
    ToolStatusImage(status: status)
  }
  .padding()
}
