import EditorStyle
import SwiftUI

/// The symbol of a state, such as a status or a priority, in a color of the
/// EditorKit theme.
///
/// The view shows the symbol with the hierarchical rendering mode of the
/// status views and the symbol weight of the shared style. Each caller keeps
/// its own map from its state to the symbol name and to the color. The
/// ``StatusBar`` and each status symbol of AgentViewKit, such as the status
/// of a tool call, the plan entry, the error card and the notice banner, draw
/// their symbols with this view, so a change of the rendering mode or of the
/// weight reaches each of them. A caller adds its own symbol effects to the
/// view.
public struct StatusSymbolImage: View {
  /// The SF Symbol name. Read it from ``SharedSymbol``, from `ItemStatus` or
  /// `ItemPriority` of EditorStyle, or from the symbol map of the caller.
  let name: String

  /// The color of the symbol: a color of the EditorKit theme, or
  /// `Color.secondary` for a row with no state color.
  let color: Color

  @Environment(\.editorStyle) private var editorStyle

  /// Makes the symbol of a state.
  ///
  /// - Parameters:
  ///   - name: The SF Symbol name.
  ///   - color: The color of the symbol.
  public init(name: String, color: Color) {
    self.name = name
    self.color = color
  }

  public var body: some View {
    Image(systemName: name)
      .symbolRenderingMode(.hierarchical)
      .fontWeight(editorStyle.symbolWeight)
      .foregroundStyle(color)
  }
}

#Preview("Each item status") {
  HStack(spacing: EditorStyle.default.spacing.m) {
    ForEach(StylePreviewFixtures.itemStatuses, id: \.self) { status in
      StatusSymbolImage(name: status.systemImage, color: .secondary)
    }
  }
  .padding()
}
