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
/// A row that waits at rest in the ``TranscriptRowMountQueue``
/// (``TranscriptSlotForm/waiting``) keeps its static form until the user
/// interacts with it (card ^7625j1b). A press of the mouse on the still view
/// of the slot makes the row real at once: the wait of the row
/// (``SwiftUI/EnvironmentValues/transcriptRowMount``) ends
/// (``TranscriptRowMountQueue/release(_:)``). In each other form, the still
/// view has no such gesture. The still view is one accessibility element
/// (``StaticSlotAccessibility``): the press of an assistive app on it, or its
/// focus on it, also makes the row real, so the app reads the text of the
/// editor. A hover does not.
///
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
/// A slot of Markdown text, of code or of an output names its text part
/// (``picturePart``). While the height cache of the thread has a picture of
/// that part, which EditorKit drew off the main thread, the still view of
/// the slot is that picture
/// (``StaticPictureView``), not its SwiftUI `Text`. Thus the list lays out
/// no text on the main thread while it moves (card ^9ync5h3). The picture
/// has the measured height of the text, so the row does not move.
///
/// A slot whose still view cannot show its text, such as a Markdown text
/// with math (card ^hh39bp4), keeps its editor in each form
/// (``keepsEditor``). The row keeps the frame of its static form, at the
/// exact height of the height cache, so the row does not move.
struct StaticEditorSlot<Editor: View, Still: View>: View {
  /// The EditorKit editor of the text area.
  let editor: Editor

  /// Makes the still view of the static form. The slot calls it only in the
  /// static form.
  @ViewBuilder let still: () -> Still

  /// Whether the slot shows its editor in each form, because the still view
  /// cannot show its text.
  let keepsEditor: Bool

  /// The text part whose picture the slot shows in place of its still
  /// view, or `nil` for a slot with no picture.
  let picturePart: TranscriptTextPart?

  @Environment(\.transcriptSlotForm) private var form
  @Environment(\.transcriptRowMount) private var rowMount
  @Environment(\.transcriptRowMounts) private var mounts

  /// The height of the editor at its last layout.
  @State private var laidOutHeight = LaidOutHeight()

  /// Whether an assistive app has its focus on the still view.
  @AccessibilityFocusState private var isAccessibilityFocused: Bool

  /// Makes the slot of an editor.
  ///
  /// - Parameters:
  ///   - keepsEditor: Whether the slot shows its editor in each form,
  ///     because the still view cannot show the text. The default is
  ///     `false`.
  ///   - picturePart: The text part whose picture the slot shows in its
  ///     static form, or `nil` (the default) for no picture.
  ///   - editor: The EditorKit editor of the text area.
  ///   - still: Makes the static form of the text.
  init(
    keepsEditor: Bool = false, picturePart: TranscriptTextPart? = nil, @ViewBuilder editor: () -> Editor,
    @ViewBuilder still: @escaping () -> Still
  ) {
    self.keepsEditor = keepsEditor
    self.picturePart = picturePart
    self.editor = editor()
    self.still = still
  }

  var body: some View {
    if !keepsEditor, form.showsStill {
      StaticSlotStill(picturePart: picturePart, still: still)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .frame(height: laidOutHeight.points, alignment: .top)
        .clipped()
        .simultaneousGesture(
          DragGesture(minimumDistance: 0).onChanged { _ in noteInteraction() },
          including: form == .waiting ? .all : .none)
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier(StaticSlotAccessibility.identifier)
        .accessibilityAction { noteInteraction() }
        .accessibilityFocused($isAccessibilityFocused)
        .onChange(of: isAccessibilityFocused) { _, isFocused in
          noteAccessibilityFocus(isFocused)
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

  /// Records an interaction of the user with the still view of the slot: a
  /// press of the mouse, or a press of an assistive app. In a row that
  /// waits, the wait of the row ends, so each slot of the row shows its
  /// editor at once. While the rows move, the row shows its real form when
  /// they come to rest.
  private func noteInteraction() {
    guard let rowMount, rowMount.waits else { return }
    mounts?.release(rowMount)
  }

  /// Records a new focus of an assistive app on the still view: the focus
  /// that comes on it is an interaction (``noteInteraction()``).
  ///
  /// - Parameter isFocused: Whether the app has its focus on the still view.
  private func noteAccessibilityFocus(_ isFocused: Bool) {
    guard isFocused else { return }
    noteInteraction()
  }
}

/// The accessibility of the still view of a ``StaticEditorSlot`` (card
/// ^7625j1b).
///
/// The still view is one element that holds the text of the slot. Its
/// press, and the focus of an assistive app on it, make the row of the slot
/// real.
enum StaticSlotAccessibility {
  /// The accessibility identifier of the still view of a slot.
  static let identifier = "static-editor-slot-still"
}
