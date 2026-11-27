import CoreGraphics
import EditorDiff
import EditorSwiftUI
import EditorText

/// The layout of the EditorKit diff view of a patch, for the height measure
/// of a diff (``EditorLayoutTranscriptTextMeasure``, card ^9ync5h3).
///
/// The `PreviewField` of a ``DiffView`` shows the EditorKit `DiffView` of
/// the patch: one read-only editor over the inline document of the patch
/// (`DiffDocument(inline:contextLines:)`), in the code font role, with the
/// wrap to the width of the view. Its leading lane has three gutter
/// columns, and the gutter gap of the style stands between the lane and the
/// text:
///
/// - the expand column (`DiffExpandGutter`), of a fixed width,
/// - the column of the line numbers (`DiffLineNumbers`), as wide as the
///   digits of the largest line number of the document,
/// - the marker column (`DiffMarkerGutter`), of a fixed width.
///
/// The view also has the strip of the change bars (`DiffChangeBars`) on the
/// trailing side, in the scrollbar lane of the editor. The editor wraps its
/// lines in the width that the strip and the leading lane leave.
///
/// The editor colors the text with the tree-sitter grammar of the files of
/// the patch, when the files have one language hint with a bundled grammar.
///
/// The layout is not made for a patch that EditorKit cannot read, and for a
/// document with context to fold: the editor folds that context, and a fold
/// hides rows that the measure of code shows.
nonisolated struct TranscriptDiffLayout {
  /// The number of the first line in the line number column: the column
  /// shows the 0-based line of a row plus one.
  static let firstLineNumber = 1

  /// The width of the strip of the change bars: the smallest width of a
  /// scrollbar strip of an EditorKit editor
  /// (`LaneHostView.defaultScrollbarLaneWidth`, which EditorKit does not
  /// make public). The change bars take the width that the strip gives
  /// them. The parity tests of the diff rows (`TranscriptRowMeasureTests`)
  /// fail when EditorKit gives the strip another width.
  static let changeBarStripWidth: CGFloat = 12

  /// The inline document of the patch.
  let document: DiffDocument

  /// The grammar of the editor of the document.
  let grammar: EditorLayoutMeasure.CodeGrammar

  /// The largest number of the line number column.
  let largestLineNumber: Int

  /// Makes the layout of a patch.
  ///
  /// - Parameter patch: The patch text.
  /// - Returns: The layout, or `nil` when EditorKit cannot read the patch or
  ///   the document has context to fold.
  init?(patch: String) {
    guard let parsed = try? UnifiedDiff.parse(patch) else { return nil }
    let document = DiffDocument(inline: parsed, contextLines: LineDiff.defaultContext)
    guard document.foldableContext.isEmpty else { return nil }
    self.document = document
    grammar = Self.grammar(of: parsed)
    largestLineNumber =
      document.rows.compactMap { $0.newLine ?? $0.oldLine }.max().map { $0 + Self.firstLineNumber }
      ?? Self.firstLineNumber
  }

  /// The width that the leading lane, the gutter gap and the strip of the
  /// change bars take of the width of the view.
  ///
  /// The digits of the line number column have the advance of the code
  /// font, as the line number gutter of a code block has: the width of a
  /// line number gutter with no gap for a document of ``largestLineNumber``
  /// lines.
  ///
  /// - Parameters:
  ///   - style: The style of the code of the view.
  ///   - fixedColumns: The width of the expand column and the marker column.
  ///   - gap: The gutter gap of the style.
  /// - Returns: The width, in points.
  func chromeWidth(style: EditorLayoutMeasure.Style, fixedColumns: CGFloat, gap: CGFloat) -> CGFloat {
    let digits = EditorLayoutMeasure.CodeGutter.lineNumbers(gap: .zero)
      .chromeWidth(lineCount: largestLineNumber, style: style)
    return LaneChrome.width(leadingLaneWidth: fixedColumns + digits, trailingLaneWidth: .zero, gap: gap)
      + Self.changeBarStripWidth
  }

  /// The grammar of the editor of a patch: the bundled tree-sitter grammar
  /// of the language hint of its files, when each file has the same hint.
  ///
  /// - Parameter patch: The parsed patch.
  /// - Returns: The grammar, or plain text.
  static func grammar(of patch: UnifiedDiff) -> EditorLayoutMeasure.CodeGrammar {
    guard let first = patch.files.first, patch.files.allSatisfy({ $0.languageHint == first.languageHint }),
      let hint = first.languageHint, let grammar = GrammarRegistry.grammar(for: LanguageID(hint))
    else { return .plainText }
    return .treeSitter(grammar.id)
  }
}
