import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The frame of a block that holds an EditorKit editor: ``CodeBlockView``,
/// ``TerminalView`` and ``CommandOutputView``.
///
/// The frame fills the block, rounds its corners with the medium radius of
/// the kit theme, and draws a separator border. The fill is the editor
/// background of the EditorKit theme in the environment, or the fill that the
/// block gives. The frame sets no EditorKit theme, so the editor in the block
/// uses the theme of the environment too.
struct EditorBlockFrame: ViewModifier {
  /// The fill of the block, or `nil` for the editor background of the
  /// EditorKit theme.
  let fill: Color?

  @Environment(\.agentTheme) private var theme
  @Environment(\.editorTheme) private var editorTheme

  func body(content: Content) -> some View {
    content
      .background(fill ?? editorTheme.editorBackground)
      .clipShape(RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: theme.radii.m, style: .continuous)
          .strokeBorder(.separator)
      )
  }
}

/// The frame of a block that shows terminal output: ``TerminalView`` and
/// ``CommandOutputView``.
///
/// The frame is an ``EditorBlockFrame`` with the colors of the terminal
/// palette of the EditorKit theme (`Theme.terminalPalette`): the terminal
/// background fills the block, and the terminal foreground is the
/// foreground style of the block. The color runs of the output use the same
/// palette, so the text and the fill agree.
struct TerminalBlockFrame: ViewModifier {
  @Environment(\.editorTheme) private var editorTheme

  func body(content: Content) -> some View {
    let palette = editorTheme.terminalPalette
    content
      .foregroundStyle(palette[.foreground])
      .modifier(EditorBlockFrame(fill: palette[.background]))
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
    modifier(EditorBlockFrame(fill: nil))
  }

  /// Puts this block in the frame of a block that shows terminal output,
  /// with the colors of the terminal palette.
  ///
  /// - Returns: The framed block.
  func terminalBlockFrame() -> some View {
    modifier(TerminalBlockFrame())
  }

  /// Fills this header row with the bar background of the EditorKit theme.
  ///
  /// - Returns: The row with the bar background.
  func editorBlockBar() -> some View {
    modifier(EditorBlockBar())
  }
}
