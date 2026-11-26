import SwiftUI

/// One EditorKit text area of a thread row, with its static form (card
/// ^9ync5h3).
///
/// In the real form of the row, the slot shows the editor, and records its
/// height at each layout. In the static form of the row
/// (``SwiftUI/EnvironmentValues/transcriptRowIsStatic``), the slot shows the
/// still view in place of the editor: the same text in SwiftUI `Text`, at
/// the height of the last layout of the editor, so no view of the row moves.
/// A slot whose editor was never laid out shows its editor in each form.
///
/// The height is not observable, so a new height does not make the slot
/// evaluate its body again. The slot reads it when the form of its row
/// changes.
struct StaticEditorSlot<Editor: View, Still: View>: View {
  /// The EditorKit editor of the text area.
  let editor: Editor

  /// Makes the still view of the static form. The slot calls it only in the
  /// static form.
  @ViewBuilder let still: () -> Still

  @Environment(\.transcriptRowIsStatic) private var isStatic

  /// The height of the editor at its last layout.
  @State private var laidOutHeight = LaidOutHeight()

  /// Makes the slot of an editor.
  ///
  /// - Parameters:
  ///   - editor: The EditorKit editor of the text area.
  ///   - still: Makes the static form of the text.
  init(@ViewBuilder editor: () -> Editor, @ViewBuilder still: @escaping () -> Still) {
    self.editor = editor()
    self.still = still
  }

  var body: some View {
    if isStatic, let height = laidOutHeight.points {
      still()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: height, alignment: .top)
        .clipped()
    } else {
      let laidOutHeight = laidOutHeight
      editor
        .onGeometryChange(for: CGFloat.self) {
          $0.size.height
        } action: {
          laidOutHeight.points = $0
        }
    }
  }
}
