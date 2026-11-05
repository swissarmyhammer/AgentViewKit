import EditorSwiftUI

extension EditorView {
  /// This editor at the size of its content, as a block of more than one line
  /// of the kit shows it (EditorKit `style.md`, "A multiline field fits its
  /// content").
  ///
  /// The editor takes the height of its rows (`.editorSizingMode(.intrinsic)`)
  /// and grows and shrinks as its text changes. It wraps a long line to its
  /// width (`.editorWrapMode(.viewportWidth)`), so it has no scroll of its
  /// own, up and down or sideways: the host scrolls it. ``CodeBlockView``,
  /// ``TerminalView`` and ``CommandOutputView`` show their text in it, and
  /// ``EditorKitPromptEditor`` takes the prompt in it.
  ///
  /// - Returns: The same editor, sized to its content.
  func sizedToContent() -> Self {
    editorSizingMode(.intrinsic)
      .editorWrapMode(.viewportWidth)
  }
}
