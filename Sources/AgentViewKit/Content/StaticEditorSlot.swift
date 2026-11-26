import SwiftUI

/// One EditorKit text area of a thread row, with its static form (card
/// ^9ync5h3).
///
/// In the real form of the row, the slot shows the editor, and records its
/// height at each layout. In the static form of the row
/// (``SwiftUI/EnvironmentValues/transcriptSlotForm``), the slot shows the
/// still view in place of the editor: the same text in SwiftUI `Text`, at
/// the height of the last layout of the editor, so no view of the row moves.
///
/// In a thread row, the slot adds its turn (``TranscriptSlotMount``) to the
/// turn of its row (``SwiftUI/EnvironmentValues/transcriptRowMount``). When
/// the row waits at rest in the ``TranscriptRowMountQueue``
/// (``TranscriptSlotForm/inTurn``), the slot shows its still view until its
/// own turn, and its editor after, while the row keeps the frame of its
/// static form (card ^7625j1b). While it shows its still view, the slot
/// gives the queue its top in the row, so the slots of a row become real
/// from top to bottom.
/// A slot whose editor was never laid out, such as the slot of a row that
/// shows its static form from its first frame, shows the still view at the
/// height of its text. The row then has the exact height of the height
/// cache (``TranscriptStaticRowHeights``), so the row does not move when it
/// changes form.
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

  @Environment(\.transcriptSlotForm) private var form
  @Environment(\.transcriptRowMount) private var rowMount

  /// The height of the editor at its last layout.
  @State private var laidOutHeight = LaidOutHeight()

  /// The turn of the slot in the queue of the thread.
  @State private var mount = TranscriptSlotMount()

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
    let mount = mount
    let rowMount = rowMount
    slotForm
      .onAppear { rowMount?.add(mount) }
      .onDisappear { rowMount?.remove(mount) }
  }

  /// The still view or the editor, as the form of the row and the turn of
  /// the slot tell.
  @ViewBuilder private var slotForm: some View {
    if form.showsStill(slotWaits: mount.waits) {
      still()
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: laidOutHeight.points, alignment: .top)
        .clipped()
        .background {
          if rowMount != nil {
            let mount = mount
            Color.clear.onGeometryChange(for: CGFloat.self, of: TranscriptSlotMount.top(of:)) { top in
              mount.top = top
            }
          }
        }
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
