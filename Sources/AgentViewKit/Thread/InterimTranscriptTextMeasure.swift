import AppKit

/// An interim text measure that is NOT exact: TextKit at the system fonts,
/// with no EditorKit layout.
///
/// EditorKit's exact measure, `EditorLayoutMeasure` (EditorKit card
/// ^ep9f55d), is not on EditorKit main yet. Until it is, this measure lets
/// ``TranscriptRowHeights`` run. It lays out prose and labels with TextKit at
/// the system font, and counts the lines of code, output and diffs at the
/// line height of the system monospaced font. Its heights differ from the
/// heights of the mounted EditorKit views. Replace it with the EditorKit
/// measure when that measure lands.
nonisolated public struct InterimTranscriptTextMeasure: TranscriptTextMeasure {
  /// The size of the fonts of the measure.
  let fontSize: CGFloat

  /// Makes the measure.
  ///
  /// - Parameter fontSize: The size of the fonts of the measure.
  public init(fontSize: CGFloat = NSFont.systemFontSize) {
    self.fontSize = fontSize
  }

  public func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    switch part.style {
    case .code, .output, .diff:
      lineHeight(of: NSFont.monospacedSystemFont(ofSize: fontSize, weight: .regular))
        * CGFloat(part.text.split(separator: "\n", omittingEmptySubsequences: false).count)
    case .markdown, .label:
      wrappedHeight(of: part.text, width: width)
    }
  }

  /// The height of a text that wraps at a width, at the system font.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - width: The width.
  /// - Returns: The height, rounded up to a whole point.
  private func wrappedHeight(of text: String, width: CGFloat) -> CGFloat {
    let string = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: fontSize)])
    let bounds = string.boundingRect(
      with: CGSize(width: max(width, .zero), height: .greatestFiniteMagnitude),
      options: [.usesLineFragmentOrigin, .usesFontLeading])
    return bounds.height.rounded(.up)
  }

  /// The line height of a font.
  ///
  /// - Parameter font: The font.
  /// - Returns: The ascender, the descender and the leading.
  private func lineHeight(of font: NSFont) -> CGFloat {
    font.ascender - font.descender + font.leading
  }
}
