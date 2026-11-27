import CoreGraphics
import EditorSwiftUI
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

  /// A text part, ready to measure at many widths.
  ///
  /// ``TranscriptRowHeights`` prepares each text part one time, and keeps
  /// the prepared value. A new width then measures the prepared value
  /// again, so a resize of the thread does not do the work again that does
  /// not depend on the width. Each measurement of the prepared value at a
  /// width is equal to ``measurement(of:width:)`` at that width. The
  /// default measures the part with ``measurement(of:width:)`` at each
  /// width.
  ///
  /// - Parameter part: The text part.
  /// - Returns: The prepared part.
  nonisolated func prepared(_ part: TranscriptTextPart) -> any PreparedTranscriptTextPart

  /// A picture of a text part at a width, drawn with no view, for the
  /// static form of its row (card ^9ync5h3).
  ///
  /// ``TranscriptRowHeights`` calls this function on its background worker
  /// for each text part, at the width of its measure. A static row then
  /// shows the picture in place of the SwiftUI `Text` of the part, so the
  /// list lays out no text on the main thread while it moves. The height of
  /// the picture is the height of the measure at the width. The default
  /// draws no picture.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  ///   - appearance: The color scheme and the scale of the picture.
  /// - Returns: The picture, or `nil` when the measure draws no picture of
  ///   the part.
  nonisolated func picture(
    of part: TranscriptTextPart, width: CGFloat, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering?
}

/// The appearance of the pictures of the static text of a thread
/// (``TranscriptTextMeasure/picture(of:width:appearance:)``): the color
/// scheme that the colors of the theme resolve in, and the pixels in one
/// point.
nonisolated public struct TranscriptTextAppearance: Hashable, Sendable {
  /// The color scheme of the rows.
  public let colorScheme: ColorScheme

  /// The pixels in one point: the display scale of the window of the rows.
  public let scale: CGFloat

  /// Makes an appearance.
  ///
  /// - Parameters:
  ///   - colorScheme: The color scheme of the rows.
  ///   - scale: The pixels in one point.
  public init(colorScheme: ColorScheme, scale: CGFloat) {
    self.colorScheme = colorScheme
    self.scale = scale
  }
}

/// A text part that a ``TranscriptTextMeasure`` prepared, to measure it at
/// many widths (``TranscriptTextMeasure/prepared(_:)``).
///
/// A measure can keep the work of the last width in the value, so the
/// measure is `mutating`.
nonisolated public protocol PreparedTranscriptTextPart: Sendable {
  /// The height of the part at a width, and whether it is exact.
  ///
  /// - Parameter width: The width that the view of the part gets.
  /// - Returns: The height and the exact state, equal to
  ///   ``TranscriptTextMeasure/measurement(of:width:)`` at the width.
  nonisolated mutating func measurement(width: CGFloat) -> TranscriptTextMeasurement
}

/// A text part that a measure measures again in full at each width: the
/// default prepared part of a ``TranscriptTextMeasure``.
nonisolated struct UnpreparedTranscriptTextPart: PreparedTranscriptTextPart {
  /// The measure of the part.
  let measure: any TranscriptTextMeasure

  /// The text part.
  let part: TranscriptTextPart

  func measurement(width: CGFloat) -> TranscriptTextMeasurement {
    measure.measurement(of: part, width: width)
  }
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

  /// The part, measured with ``measurement(of:width:)`` at each width.
  ///
  /// - Parameter part: The text part.
  /// - Returns: The prepared part.
  public nonisolated func prepared(_ part: TranscriptTextPart) -> any PreparedTranscriptTextPart {
    UnpreparedTranscriptTextPart(measure: self, part: part)
  }

  /// No picture: a measure that draws no picture keeps the SwiftUI `Text`
  /// of each static row.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width that the view of the part gets.
  ///   - appearance: The color scheme and the scale of the picture.
  /// - Returns: `nil`.
  public nonisolated func picture(
    of part: TranscriptTextPart, width: CGFloat, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering? {
    nil
  }
}
