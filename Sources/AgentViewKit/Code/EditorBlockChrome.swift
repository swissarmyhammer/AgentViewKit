import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The frame of a block that holds an EditorKit editor: ``CodeBlockView``,
/// ``TerminalView`` and ``CommandOutputView``.
///
/// The frame clips the block to the shape of ``AgentSurface`` with the medium
/// radius of the kit theme, and marks its edge with the separator stroke of
/// ``SwiftUI/View/agentContentEdge(radius:)``. A code block has no fill
/// (D113): the content behind the block shows through it. Only the fill that
/// a block gives, for example the terminal background, fills the block. The
/// frame sets no EditorKit theme, so the editor in the block uses the theme
/// of the environment.
struct EditorBlockFrame: ViewModifier {
  /// The fill of the block, or `nil` for a block with no fill.
  let fill: Color?

  @Environment(\.agentTheme) private var theme

  func body(content: Content) -> some View {
    let shape = AgentSurface.shape(radius: theme.radii.m)
    content
      .clipShape(shape)
      .background(fill ?? .clear, in: shape)
      .agentContentEdge(radius: theme.radii.m)
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
///
/// D113 removes the fills of content cards, but the terminal background stays
/// (the answer to AVK-8aa). The terminal background is terminal data, the same
/// as the editor background of a theme. It is not a custom fill. The palette
/// sets the ANSI colors 0 to 15 for this background, so the output has good
/// contrast only on it. Do not remove this fill. `EditorThemeViewsTests` holds
/// this rule.
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
  /// The frame has no fill (D113). A separator stroke marks its edge.
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
