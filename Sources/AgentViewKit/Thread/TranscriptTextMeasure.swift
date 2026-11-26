import CoreGraphics
import SwiftUI

/// One text that EditorKit lays out in a transcript row: the text and the
/// kind of view that shows it.
///
/// A chrome rule (``TranscriptRowChrome``) names each text part of a row,
/// and a ``TranscriptTextMeasure`` gives its height. AgentViewKit adds the
/// chrome around the parts: the padding, the headers and the block frames.
nonisolated public struct TranscriptTextPart: Hashable, Sendable {
  /// The kind of EditorKit view that shows a text part.
  public enum Style: Hashable, Sendable {
    /// Markdown in the rendered form, in the display font role
    /// (`RenderedMarkdownView`).
    case markdown

    /// Code with a line number gutter (`CodeBlockView`). The value is the
    /// language of the code, or `nil`.
    case code(language: String?)

    /// The output of a command or a terminal, in the code font, with no
    /// gutter (`CommandOutputView`, `TerminalView`).
    case output

    /// A unified diff in a `PreviewField` (`DiffView`).
    case diff

    /// A selectable label (`EditorLabel`, `PlacedLabel`) in a font.
    case label(TranscriptLabelFont)
  }

  /// The text.
  public let text: String

  /// The kind of view that shows the text.
  public let style: Style

  /// Makes a text part.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - style: The kind of view that shows the text.
  public init(text: String, style: Style) {
    self.text = text
    self.style = style
  }
}

/// The font of a label text part.
nonisolated public enum TranscriptLabelFont: Hashable, Sendable {
  /// The UI font of the theme in a text style, such as `.callout`.
  case ui(Font.TextStyle)

  /// The code font of the theme.
  case code

  /// The font of the environment of the row.
  case inherited

  /// The system caption font (`Font.caption`).
  case systemCaption
}

/// Gives the height of one text part at a width, with no view.
///
/// ``TranscriptRowHeights`` calls the measure on a background task. A measure
/// must be exact for the cached height to be the height of the mounted row.
/// The exact measure is EditorKit's `EditorLayoutMeasure` (EditorKit card
/// ^ep9f55d). Until it is on EditorKit main, ``InterimTranscriptTextMeasure``
/// is the default.
nonisolated public protocol TranscriptTextMeasure: Sendable {
  /// The height of a text part.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  /// - Returns: The height of the view of the part.
  nonisolated func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat
}
