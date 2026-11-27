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
/// from top to bottom. A press of the mouse on the still view of a slot in a
/// row that waits at rest makes the row real at once: the turn of the row
/// leaves the queue (``TranscriptRowMountQueue/release(_:)``), so a click
/// does not stay on the static form until the turn of the row. In each other
/// form, the still view has no such gesture.
/// A slot whose editor was never laid out, such as the slot of a row that
/// shows its static form from its first frame, shows the still view at the
/// height of its text. The row then has the exact height of the height
/// cache (``TranscriptStaticRowHeights``), so the row does not move when it
/// changes form.
///
/// The height is not observable, so a new height does not make the slot
/// evaluate its body again. The slot reads it when the form of its row
/// changes.
///
/// A slot of Markdown text names its text (``pictureText``). While the
/// height cache of the thread has a picture of that text, which EditorKit
/// drew off the main thread, the still view of the slot is that picture
/// (``StaticPictureView``), not its SwiftUI `Text`. Thus the list lays out
/// no text on the main thread while it moves (card ^9ync5h3). The picture
/// has the measured height of the text, so the row does not move.
///
/// A slot whose still view cannot show its text, such as a Markdown text
/// with math (card ^hh39bp4), keeps its editor in each form
/// (``keepsEditor``). The row keeps the frame of its static form, at the
/// exact height of the height cache, so the row does not move. Such a
/// slot still takes its turn in the queue of its row, and the turn changes
/// nothing.
struct StaticEditorSlot<Editor: View, Still: View>: View {
  /// The EditorKit editor of the text area.
  let editor: Editor

  /// Makes the still view of the static form. The slot calls it only in the
  /// static form.
  @ViewBuilder let still: () -> Still

  /// Whether the slot shows its editor in each form, because the still view
  /// cannot show its text.
  let keepsEditor: Bool

  /// The Markdown text whose picture the slot shows in place of its still
  /// view, or `nil` for a slot with no picture.
  let pictureText: String?

  @Environment(\.transcriptSlotForm) private var form
  @Environment(\.transcriptRowMount) private var rowMount
  @Environment(\.transcriptRowMounts) private var mounts

  /// The height of the editor at its last layout.
  @State private var laidOutHeight = LaidOutHeight()

  /// The turn of the slot in the queue of the thread.
  @State private var mount = TranscriptSlotMount()

  /// Makes the slot of an editor.
  ///
  /// - Parameters:
  ///   - keepsEditor: Whether the slot shows its editor in each form,
  ///     because the still view cannot show the text. The default is
  ///     `false`.
  ///   - pictureText: The Markdown text whose picture the slot shows in its
  ///     static form, or `nil` (the default) for no picture.
  ///   - editor: The EditorKit editor of the text area.
  ///   - still: Makes the static form of the text.
  init(
    keepsEditor: Bool = false, pictureText: String? = nil, @ViewBuilder editor: () -> Editor,
    @ViewBuilder still: @escaping () -> Still
  ) {
    self.keepsEditor = keepsEditor
    self.pictureText = pictureText
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

  /// Records a press of the mouse on the still view of the slot in a row
  /// that waits at rest: the turn of the row leaves the queue, so each slot
  /// of the row shows its editor at once.
  private func notePress() {
    guard let rowMount, rowMount.waits else { return }
    mounts?.release(rowMount)
  }

  /// The still view or the editor, as the form of the row and the turn of
  /// the slot tell. A slot that keeps its editor shows the editor.
  @ViewBuilder private var slotForm: some View {
    if !keepsEditor, form.showsStill(slotWaits: mount.waits) {
      StaticSlotStill(pictureText: pictureText, still: still)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: laidOutHeight.points, alignment: .top)
        .clipped()
        .simultaneousGesture(
          DragGesture(minimumDistance: 0).onChanged { _ in notePress() }, including: form == .inTurn ? .all : .none)
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
