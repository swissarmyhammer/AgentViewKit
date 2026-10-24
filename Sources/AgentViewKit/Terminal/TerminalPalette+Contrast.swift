import EditorTheme
import SwiftUI

/// The ANSI colors that terminal output paints with, so that the ANSI grays
/// contrast with whatever shows through the block (^4rck1pf).
///
/// A theme that sets a terminal background (`terminal.background`) keeps its
/// palette as it is: the theme chose its ANSI colors for its background. A
/// theme that sets none, such as the default `SystemTheme`, has a clear
/// terminal background (EditorKit ^0apj6a2), so the frame of the block has
/// no fill and the window background shows through. The ANSI grays of the
/// palette then can match that background: the default black is the text
/// background color, which is near-invisible on a light or a dark window.
///
/// For such a palette, ``ANSIText`` remaps the four ANSI grays to colors
/// relative to the system label color. Each one is dynamic, so it follows
/// light mode, dark mode and Increase Contrast. The other twelve ANSI colors
/// are hues, and they stay as the palette gives them.
///
/// | ANSI color | As text (SGR 30-37, 90-97) | As a fill (SGR 40-47, 100-107) |
/// |---|---|---|
/// | black (0) | `Color.primary` | `Color.primary` at ``GrayFill/strong`` |
/// | bright white (15) | `Color.primary` | `Color.primary` at ``GrayFill/strong`` |
/// | bright black (8) | `Color.secondary` | `Color.primary` at ``GrayFill/soft`` |
/// | white (7) | `Color.secondary` | `Color.primary` at ``GrayFill/soft`` |
///
/// - Text: the label color has no polarity, so black and bright white, the
///   two strongest grays of a light and of a dark terminal, are the label
///   color, the strongest ink. Bright black, the dim gray that output uses
///   for less important text, and white, a step below bright white, are the
///   secondary label color.
/// - Fills: a fill is a tint of the label color, strong for black and bright
///   white and soft for the other two. A tint shows on the window
///   background, and text in the label colors stays legible on it. A solid
///   fill in the label color would hide the default text on it, because
///   output often sets only a background color. A fill in the window
///   background color would not show at all.
///
/// The palette that sets the colors 0 to 15 of the 256-color codes
/// (`38;5;n` and `48;5;n`) is the same palette, so these codes get the same
/// colors.
extension TerminalPalette {
  /// The opacities of the label color in the fills of the ANSI grays.
  nonisolated enum GrayFill {
    /// The opacity of the fill of black and bright white.
    static let strong = 0.24
    /// The opacity of the fill of bright black and white.
    static let soft = 0.12
  }

  /// The text colors of the ANSI grays of a palette with no background.
  private nonisolated static let grayText: [Entry: Color] = [
    .black: .primary, .brightWhite: .primary, .brightBlack: .secondary, .white: .secondary,
  ]

  /// The fills of the ANSI grays of a palette with no background.
  private nonisolated static let grayFills: [Entry: Color] = [
    .black: Color.primary.opacity(GrayFill.strong),
    .brightWhite: Color.primary.opacity(GrayFill.strong),
    .brightBlack: Color.primary.opacity(GrayFill.soft),
    .white: Color.primary.opacity(GrayFill.soft),
  ]

  /// Whether the palette sets a terminal background.
  ///
  /// A background that is fully transparent sets none, the same as the
  /// EditorKit importers read a fully transparent `terminal.background`.
  nonisolated var hasBackground: Bool {
    self[.background].resolve(in: EnvironmentValues()).opacity > 0
  }

  /// The palette of the SGR text colors: this palette when it sets a
  /// background, and else this palette with the text colors of the ANSI
  /// grays of the table above.
  nonisolated var textColors: TerminalPalette {
    hasBackground ? self : replacing(Self.grayText)
  }

  /// The palette of the SGR background colors: this palette when it sets a
  /// background, and else this palette with the fills of the ANSI grays of
  /// the table above.
  nonisolated var fillColors: TerminalPalette {
    hasBackground ? self : replacing(Self.grayFills)
  }

  /// This palette with the colors of `replacements` in place of its own.
  ///
  /// - Parameter replacements: The new color of each entry to replace.
  /// - Returns: The palette with the replaced entries.
  private nonisolated func replacing(_ replacements: [Entry: Color]) -> TerminalPalette {
    TerminalPalette { replacements[$0] ?? self[$0] }
  }
}
