import CoreText
import EditorSwiftUI
import EditorText
import EditorTheme
import SwiftUI

/// The static form of a ``RenderedMarkdownView``: the same Markdown in
/// SwiftUI `Text`, in the rows of the rendered form of EditorKit (card
/// ^9ync5h3).
///
/// EditorKit lays the rendered text out in a grid of rows. Each row has the
/// line height of the display font of the theme. Each source line of the
/// Markdown starts a new row, and a blank line is one empty row. A level 1
/// or level 2 heading takes two rows for each of its lines, and its font is
/// two times its relative size (``StaticMarkdownLine/rowScale``). The view
/// shows each source line as one `Text` with that exact line height, so the
/// lines of the text stand at the rows of EditorKit.
///
/// Each line shows its inline Markdown: strong, emphasis, inline code and
/// links. The view conceals the marker of a heading, and shows the marker
/// of a bullet item as a bullet, as EditorKit does. The view sets no color:
/// the text takes the foreground style of its environment.
struct StaticMarkdownText: View {
  /// The Markdown text.
  let markdown: String

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.fontResolutionContext) private var fontContext

  var body: some View {
    let base = editorTheme.displayFont.resolve(in: fontContext).ctFont
    let rowHeight = EditorTextFont(font: base).lineHeight
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(StaticMarkdownLine.lines(in: markdown).enumerated()), id: \.offset) { _, line in
        let font = line.font(base: base)
        Text(line.text)
          .font(Font(font))
          .editorRows(font: font, rowHeight: rowHeight * CGFloat(line.rowScale))
      }
    }
  }
}

/// One source line of Markdown in the static form of the rendered text
/// (``StaticMarkdownText``).
struct StaticMarkdownLine: Equatable {
  /// The number of rows that each wrapped segment of a level 1 or a level 2
  /// heading takes in the rendered form (the `render.rowScale` of the
  /// Markdown queries of EditorKit).
  static let headingRowScale = 2

  /// The deepest heading level that takes ``headingRowScale`` rows.
  static let deepestScaledLevel = 2

  /// The relative font size of each heading level, from level 1 to level 6,
  /// before the row scale (`CaptureTypography.markupRelativeSizes` of
  /// EditorKit).
  static let headingSizes: [CGFloat] = [1, 0.75, 1, 0.9, 0.8, 0.7]

  /// The text that shows in place of the marker of a bullet item: the bullet
  /// of EditorKit, and a tab to the text of the item.
  static let bullet = "•\t"

  /// The heading level of the line, or `nil` for a line that is not a
  /// heading.
  let headingLevel: Int?

  /// The text of the line, with its inline Markdown and with no block
  /// marker.
  let text: AttributedString

  /// The number of rows that each wrapped segment of the line takes.
  var rowScale: Int {
    guard let headingLevel, headingLevel <= Self.deepestScaledLevel else { return 1 }
    return Self.headingRowScale
  }

  /// The font of the line.
  ///
  /// - Parameter base: The display font of the theme.
  /// - Returns: The base font for a line that is not a heading. For a
  ///   heading, the base font in bold at its relative size, and then at its
  ///   row scale. EditorKit makes the font in these two steps, so the scaled
  ///   font keeps the optical size of the relative size.
  func font(base: CTFont) -> CTFont {
    guard let headingLevel else { return base }
    let size = CTFontGetSize(base) * Self.headingSizes[headingLevel - 1]
    let heading =
      CTFontCreateCopyWithSymbolicTraits(base, size, nil, .traitBold, .traitBold)
      ?? CTFontCreateCopyWithAttributes(base, size, nil, nil)
    return CTFontCreateCopyWithAttributes(heading, size * CGFloat(rowScale), nil, nil)
  }

  /// The lines of `markdown`, in order.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: One line for each source line of the text.
  static func lines(in markdown: String) -> [StaticMarkdownLine] {
    markdown.split(separator: "\n", omittingEmptySubsequences: false).map { line(String($0)) }
  }

  /// One source line, with its block marker concealed or replaced.
  ///
  /// - Parameter source: The source line, with no line break.
  /// - Returns: The line.
  static func line(_ source: String) -> StaticMarkdownLine {
    if let heading = source.wholeMatch(of: /\ {0,3}(#{1,6})(?:[ \t]+(.*))?/) {
      return StaticMarkdownLine(
        headingLevel: heading.output.1.count, text: inline(String(heading.output.2 ?? "")))
    }
    if let item = source.wholeMatch(of: /(\s*)[-*+][ \t]+(.*)/) {
      return StaticMarkdownLine(
        headingLevel: nil, text: AttributedString(item.output.1 + bullet) + inline(String(item.output.2)))
    }
    return StaticMarkdownLine(headingLevel: nil, text: inline(source))
  }

  /// The inline Markdown of `source`, or the plain text when it does not
  /// parse. An empty line is one space, so that it takes one row.
  ///
  /// - Parameter source: The text of one line.
  /// - Returns: The attributed text.
  static func inline(_ source: String) -> AttributedString {
    guard !source.isEmpty else { return AttributedString(" ") }
    let options = AttributedString.MarkdownParsingOptions(
      interpretedSyntax: .inlineOnlyPreservingWhitespace, failurePolicy: .returnPartiallyParsedIfPossible)
    return (try? AttributedString(markdown: source, options: options)) ?? AttributedString(source)
  }
}

extension View {
  /// Lays the lines of a `Text` out in the rows of an EditorKit editor.
  ///
  /// Each line takes `rowHeight` exactly. EditorKit puts the space of a row
  /// that the font does not fill above the glyphs of the line, and SwiftUI
  /// puts the space of an exact line height below them. Thus the text moves
  /// down by that space, so each glyph stands where EditorKit draws it.
  ///
  /// - Parameters:
  ///   - font: The font of the text.
  ///   - rowHeight: The height of one row, in points.
  /// - Returns: The text in the rows of the editor.
  func editorRows(font: CTFont, rowHeight: CGFloat) -> some View {
    let natural = CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font)
    return
      self
      .lineHeight(.exact(points: rowHeight))
      .fixedSize(horizontal: false, vertical: true)
      .offset(y: max(rowHeight - natural, 0))
  }
}
