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

/// The height of one text part at a width, and whether that height is exact.
nonisolated public struct TranscriptTextMeasurement: Hashable, Sendable {
  /// The height of the view of the part.
  public let height: CGFloat

  /// Whether the height is the height of the mounted view of the part
  /// (``TranscriptTextMeasure/isExact(_:)``).
  public let isExact: Bool

  /// Makes a measurement.
  ///
  /// - Parameters:
  ///   - height: The height of the view of the part.
  ///   - isExact: Whether the height is exact.
  public init(height: CGFloat, isExact: Bool) {
    self.height = height
    self.isExact = isExact
  }
}

/// Gives the height of one text part at a width, with no view.
///
/// ``TranscriptRowHeights`` calls the measure on a background task. A measure
/// must be exact for the cached height to be the height of the mounted row.
/// The default is ``EditorLayoutTranscriptTextMeasure``, which uses
/// EditorKit's `EditorLayoutMeasure`.
nonisolated public protocol TranscriptTextMeasure: Sendable {
  /// The height of a text part.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  /// - Returns: The height of the view of the part.
  nonisolated func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat

  /// Tells if the height of a part is the height of the mounted view of the
  /// part, within 0.5 pt at each width.
  ///
  /// The static form of a row takes the height of the cache only when each
  /// text part of the row is exact (``TranscriptStaticRowHeights``). A part
  /// that is not exact can give a wrong height, and the row then jumps when
  /// it changes from its static form to its real form.
  ///
  /// - Parameter part: The text part.
  /// - Returns: `true` when ``height(of:width:)`` is exact for the part.
  nonisolated func isExact(_ part: TranscriptTextPart) -> Bool

  /// The height of a text part, and whether it is exact.
  ///
  /// ``TranscriptRowHeights`` calls this function for each text part. A
  /// measure that gets the height and the exact state from one layout
  /// gives both from that layout. The default calls ``height(of:width:)``
  /// and ``isExact(_:)``.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  /// - Returns: The height and the exact state.
  nonisolated func measurement(of part: TranscriptTextPart, width: CGFloat) -> TranscriptTextMeasurement
}

extension TranscriptTextMeasure {
  /// The height of a text part from ``height(of:width:)``, and its exact
  /// state from ``isExact(_:)``.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  /// - Returns: The height and the exact state.
  public nonisolated func measurement(of part: TranscriptTextPart, width: CGFloat) -> TranscriptTextMeasurement {
    TranscriptTextMeasurement(height: height(of: part, width: width), isExact: isExact(part))
  }
}
