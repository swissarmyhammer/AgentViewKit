import EditorStyle
import EditorSwiftUI
import EditorText
import EditorTheme
import SwiftUI

/// The static form of a read-only EditorKit editor of code or of output: the
/// same text in SwiftUI `Text`, in the code font of the theme and in the
/// rows of the editor (card ^9ync5h3).
///
/// Each row has the line height of the code font, as in the editor. A code
/// block shows its line numbers in a column before the text, with the
/// gutter gap of the style. The text loses its syntax colors, and keeps the
/// colors of its runs, such as the ANSI colors of a terminal.
struct StaticCodeText: View {
  /// The text, with its color runs.
  let text: AttributedString

  /// Whether the view shows a line number before each line.
  let showsLineNumbers: Bool

  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.editorStyle) private var editorStyle
  @Environment(\.themeSecondary) private var themeSecondary
  @Environment(\.fontResolutionContext) private var fontContext

  /// Makes the static form of plain text.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - showsLineNumbers: Whether the view shows a line number before each
  ///     line.
  init(_ text: String, showsLineNumbers: Bool = false) {
    self.init(AttributedString(text), showsLineNumbers: showsLineNumbers)
  }

  /// Makes the static form of text with color runs.
  ///
  /// - Parameters:
  ///   - text: The text, with its color runs.
  ///   - showsLineNumbers: Whether the view shows a line number before each
  ///     line.
  init(_ text: AttributedString, showsLineNumbers: Bool = false) {
    self.text = text
    self.showsLineNumbers = showsLineNumbers
  }

  var body: some View {
    let font = EditorTextFont(font: editorTheme.codeFont.resolve(in: fontContext).ctFont)
    HStack(alignment: .top, spacing: editorStyle.gutterGap) {
      if showsLineNumbers {
        Text(verbatim: Self.lineNumbers(of: String(text.characters)))
          .multilineTextAlignment(.trailing)
          .foregroundStyle(themeSecondary)
          .editorRows(font: font.font, rowHeight: font.lineHeight)
      }
      Text(text)
        .editorRows(font: font.font, rowHeight: font.lineHeight)
    }
    .font(Font(font.font))
  }

  /// The line numbers of `text`, one on each line.
  ///
  /// - Parameter text: The text.
  /// - Returns: The numbers from 1 to the line count, split by line breaks.
  static func lineNumbers(of text: String) -> String {
    let count = text.split(separator: "\n", omittingEmptySubsequences: false).count
    return (1...max(count, 1)).map(String.init).joined(separator: "\n")
  }

  /// `text` with the foreground color of each color run.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - runs: The color runs of the text, in UTF-8 offsets.
  /// - Returns: The attributed text.
  static func colored(_ text: String, runs: [EditorColorRun]) -> AttributedString {
    var attributed = AttributedString(text)
    let utf8 = text.utf8
    for run in runs {
      guard let foreground = run.foreground,
        let lower = utf8.index(utf8.startIndex, offsetBy: run.range.lowerBound, limitedBy: utf8.endIndex),
        let upper = utf8.index(utf8.startIndex, offsetBy: run.range.upperBound, limitedBy: utf8.endIndex),
        let range = Range(lower..<upper, in: attributed)
      else { continue }
      attributed[range].foregroundColor = foreground
    }
    return attributed
  }
}
