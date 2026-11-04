import EditorStyle
import SwiftUI

/// The row of the actions of an inspector, under the name of its item
/// (EditorKit `style.md`, "The inspector").
///
/// The row is a plain container with no knowledge of commands. It gives its
/// buttons the look of the inspector: the control spacing between them
/// (`ControlStack`), the `.borderless` button style, and only the symbol of
/// each one (`.labelStyle(.iconOnly)`), in the `.secondary` style. A host
/// `.tint` does not reach them: no control has a tint (`style.md`, "Tint").
///
/// Each button keeps its own title, its `.help`, its identifier and its
/// disabled state. The row has no padding of its own (`style.md`, rule 10).
public struct InspectorActionRow<Content: View>: View {
  /// The buttons of the row.
  let content: Content

  /// Makes the row of `content`.
  ///
  /// - Parameter content: The buttons of the row.
  public init(@ViewBuilder content: () -> Content) {
    self.content = content()
  }

  public var body: some View {
    ControlStack(.horizontal) {
      content
    }
    .labelStyle(.iconOnly)
    .buttonStyle(.borderless)
    .tint(nil)
    .foregroundStyle(.secondary)
  }
}

#Preview("Actions of an inspector, enabled and disabled") {
  InspectorActionRow {
    Button(StylePreviewFixtures.fileName, systemImage: SharedSymbol.edit) {}
    Button(StylePreviewFixtures.fileName, systemImage: SharedSymbol.move) {}
    Button(StylePreviewFixtures.fileName, systemImage: SharedSymbol.delete) {}
      .disabled(true)
  }
  .padding()
}
