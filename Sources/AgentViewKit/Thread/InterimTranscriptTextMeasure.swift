import AppKit
import EditorTheme

/// An interim text measure: TextKit at the system fonts, with no EditorKit
/// layout. It is exact only for some text parts.
///
/// EditorKit's exact measure, `EditorLayoutMeasure` (EditorKit card
/// ^ep9f55d), is not on EditorKit main yet. Until it is, this measure lets
/// ``TranscriptRowHeights`` run. It lays out prose and labels with TextKit at
/// the system font, and counts the lines of code, output and diffs at the
/// line height of the system monospaced font. Replace it with the EditorKit
/// measure when that measure lands.
///
/// The measure is exact (``isExact(_:)``) only in a theme with the system
/// fonts, and only for these parts: Markdown that is plain prose
/// (``isPlainProse(_:)``), and a label in the font of its row, such as the
/// label of a plan step. Its heights of each other part differ from the
/// heights of the mounted EditorKit views: a code block, a terminal, the
/// output of a command, a diff, the explanation of a notice, and Markdown
/// with markup, such as a heading, a list or inline code.
nonisolated public struct InterimTranscriptTextMeasure: TranscriptTextMeasure {
  /// The characters of inline Markdown markup, and of block markup that can
  /// stand anywhere on a line. Markdown with one of them is not plain prose.
  static let markupCharacters: Set<Character> = ["`", "*", "_", "[", "]", "<", ">", "~", "|", "#", "\\"]

  /// The first characters of a line that start a list item or the
  /// underline of a heading.
  static let blockMarkers: Set<Character> = ["-", "+", "="]

  /// The characters after the number of an ordered list item.
  static let orderedListDelimiters: Set<Character> = [".", ")"]

  /// The count of spaces that starts a line of indented code.
  static let indentedCodeSpaces = 4

  /// The size of the fonts of the measure.
  let fontSize: CGFloat

  /// Whether the fonts of the theme are the fonts that the measure lays
  /// out: the system fonts at the system font size.
  let hasThemeFonts: Bool

  /// Makes the measure.
  ///
  /// - Parameters:
  ///   - fontSize: The size of the fonts of the measure.
  ///   - theme: The theme of the rows, or `nil` for the environment with no
  ///     theme, whose fonts are the system fonts.
  public init(fontSize: CGFloat = NSFont.systemFontSize, theme: (any Theme)? = nil) {
    self.fontSize = fontSize
    let hasSystemFaces = theme.map { $0.uiFace == .system && $0.displayFace == .system } ?? true
    hasThemeFonts = hasSystemFaces && fontSize == NSFont.systemFontSize
  }

  /// Tells if the height of a part is the height of the mounted view of the
  /// part.
  ///
  /// The measure is exact only in a theme with the system fonts at the
  /// system font size, and only for Markdown that is plain prose
  /// (``isPlainProse(_:)``) and for a label in the font of its row.
  ///
  /// - Parameter part: The text part.
  /// - Returns: `true` when ``height(of:width:)`` is exact for the part.
  public func isExact(_ part: TranscriptTextPart) -> Bool {
    guard hasThemeFonts else { return false }
    switch part.style {
    case .markdown: return Self.isPlainProse(part.text)
    case .label(.inherited): return true
    case .label(.ui), .label(.code), .label(.systemCaption), .code, .output, .diff: return false
    }
  }

  /// Tells if a Markdown text is plain prose: it has no markup that changes
  /// a font, adds an indent or adds a view.
  ///
  /// - Parameter text: The Markdown text.
  /// - Returns: `true` when the text has no markup character
  ///   (``markupCharacters``) and no line that starts a block.
  static func isPlainProse(_ text: String) -> Bool {
    guard !text.contains(where: markupCharacters.contains) else { return false }
    return text.split(separator: "\n").allSatisfy(isPlainLine)
  }

  /// Tells if a line of Markdown starts no block: no indented code, no list
  /// item and no heading underline.
  ///
  /// - Parameter line: The line.
  /// - Returns: `true` when the line is a line of a paragraph, or a blank
  ///   line.
  static func isPlainLine(_ line: Substring) -> Bool {
    let indent = line.prefix(while: { $0 == " " }).count
    let body = line.dropFirst(indent)
    guard indent < indentedCodeSpaces, let first = body.first, first != "\t" else { return body.isEmpty }
    guard !blockMarkers.contains(first) else { return false }
    let number = body.prefix(while: \.isNumber)
    guard !number.isEmpty, let delimiter = body.dropFirst(number.count).first else { return true }
    return !orderedListDelimiters.contains(delimiter)
  }

  /// The height of a text part at a width.
  ///
  /// The height of code, output and a diff is the count of its lines at the
  /// line height of the system monospaced font. The height of prose and a
  /// label is the height of the text that wraps at `width`, at the system
  /// font.
  ///
  /// - Parameters:
  ///   - part: The text part.
  ///   - width: The width of the view that shows the text.
  /// - Returns: The height.
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
