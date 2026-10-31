import EditorStyle
import EditorSwiftUI
import EditorTheme
import SwiftUI

/// The frame of a block that holds an EditorKit editor: ``CodeBlockView``,
/// ``TerminalView`` and ``CommandOutputView``.
///
/// The frame clips the block to the surface shape of EditorKit
/// (`EditorSurface.shape(radius:)`) with the medium radius of `\.editorStyle`,
/// and marks its edge with the separator stroke of `.inlineEdge(radius:)`. A
/// code block has no fill (D113): the content behind the block shows through
/// it. Only the fill that a block gives, for example the terminal background,
/// or the fill that a host opts into with `.inlineFill(_:)`, fills the block.
/// The frame sets no EditorKit theme, so the editor in the block uses the
/// theme of the environment.
struct EditorBlockFrame: ViewModifier {
  /// The fill of the block, or `nil` for a block with no fill.
  let fill: Color?

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    let radius = editorStyle.radii.m
    let shape = EditorSurface.shape(radius: radius)
    content
      .clipShape(shape)
      .background(fill ?? .clear, in: shape)
      .inlineEdge(radius: radius)
  }
}

/// The frame of a block that shows terminal output: ``TerminalView`` and
/// ``CommandOutputView``.
///
/// The frame is an ``EditorBlockFrame`` with the colors of the terminal
/// palette of the EditorKit theme (`Theme.terminalPalette`): the terminal
/// background of a theme that sets one fills the block, and the terminal
/// foreground is the foreground style of the block. The color runs of the
/// output use the same palette, so the text and the fill agree.
///
/// D113 removes the fills of content cards, but the terminal background of a
/// theme stays (the answer to AVK-8aa). The terminal background is terminal
/// data, the same as the editor background of a theme. It is not a custom
/// fill. The palette sets the ANSI colors 0 to 15 for this background, so the
/// output has good contrast only on it. Do not remove this fill.
///
/// A theme that sets no terminal background, such as the default
/// `SystemTheme`, gives a block with no fill: kit views are clear by default
/// (^4rck1pf). The content behind the block shows through it, and
/// ``ANSIText`` remaps the ANSI grays so that they contrast with it
/// (`TerminalPalette+Contrast.swift`). `TerminalContrastHostedTests` holds
/// the contrast.
struct TerminalBlockFrame: ViewModifier {
  @Environment(\.editorTheme) private var editorTheme

  func body(content: Content) -> some View {
    let palette = editorTheme.terminalPalette
    content
      .foregroundStyle(palette[.foreground])
      .modifier(EditorBlockFrame(fill: palette.hasBackground ? palette[.background] : nil))
  }
}

/// The header row of a block that holds an EditorKit editor: the title row
/// of ``CodeBlockView``, ``TerminalView`` and ``CommandOutputView``.
///
/// The header row is content, not a bar (D113). It has no fill, so the fill
/// of the block shows behind it: no fill for a code block, and the terminal
/// background for terminal output. A system `Divider` under the row draws
/// the separator line that marks it.
///
/// The block lays out its header and its body in a ``ContentTileStack``, so
/// the tile gap of `\.editorStyle` is between them. The separator line is in
/// the middle of that gap and takes no space in the layout, so the gap stays
/// the tile gap (card ^ey6v778).
struct EditorBlockHeader: ViewModifier {
  /// The part of the tile gap above the separator line: the line is in the
  /// middle of the gap.
  static let separatorPlacement: CGFloat = 0.5

  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    let drop = editorStyle.tile.gap * Self.separatorPlacement
    content.overlay(alignment: .bottom) {
      Divider()
        .alignmentGuide(.bottom) { line in line[VerticalAlignment.center] - drop }
    }
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

  /// Makes this row the header row of a block that holds an EditorKit
  /// editor.
  ///
  /// The header row is content, not a bar (D113). It has no fill. A
  /// separator line under it marks it.
  ///
  /// - Returns: The row with the separator line under it.
  func editorBlockHeader() -> some View {
    modifier(EditorBlockHeader())
  }
}
