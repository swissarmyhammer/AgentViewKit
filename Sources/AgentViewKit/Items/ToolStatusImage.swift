import EditorSwiftUI
import EditorTheme
import FoundationModelsACP
import SwiftUI

/// The status symbol of a tool call, in the status color of the EditorKit
/// theme.
///
/// The view shows the symbol of ``ToolStatusSymbol/name(for:)`` with the
/// hierarchical rendering mode of the other status views, the symbol weight
/// of the kit theme and the color of
/// `Theme.statusColor(for:)`. ``ToolCallView`` and ``ActivityTimeline`` show
/// the status of a call with this view, so a change of the symbol, the weight
/// or the color reaches both. A caller adds its own symbol effects to the
/// view.
struct ToolStatusImage: View {
  /// The ACP status of the call.
  let status: FoundationModelsACP.ToolCallStatus

  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  var body: some View {
    Image(systemName: ToolStatusSymbol.name(for: status))
      .symbolRenderingMode(.hierarchical)
      .fontWeight(theme.symbolWeight)
      .foregroundStyle(editorTheme.statusColor(for: status))
  }
}
