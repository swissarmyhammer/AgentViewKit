import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The frame of a block that holds an EditorKit editor: ``CodeBlockView``,
/// ``TerminalView`` and ``CommandOutputView``.
///
/// The frame fills the block with the editor background of the EditorKit
/// theme in the environment, rounds its corners with the medium radius of the
/// kit theme, and draws a separator border. The frame sets no EditorKit
/// theme, so the editor in the block uses the theme of the environment too.
struct EditorBlockFrame: ViewModifier {
  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  func body(content: Content) -> some View {
    content
      .background(editorTheme.editorBackground)
      .clipShape(RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
          .strokeBorder(.separator)
      )
  }
}

/// The background of the header row of a block that holds an EditorKit
/// editor: the status bar background of the EditorKit theme in the
/// environment.
struct EditorBlockBar: ViewModifier {
  @Environment(\.editorTheme) private var editorTheme

  func body(content: Content) -> some View {
    content.background(editorTheme.statusBarBackground)
  }
}

extension View {
  /// Puts this block in the frame of a block that holds an EditorKit editor.
  ///
  /// - Returns: The framed block.
  func editorBlockFrame() -> some View {
    modifier(EditorBlockFrame())
  }

  /// Fills this header row with the bar background of the EditorKit theme.
  ///
  /// - Returns: The row with the bar background.
  func editorBlockBar() -> some View {
    modifier(EditorBlockBar())
  }
}
