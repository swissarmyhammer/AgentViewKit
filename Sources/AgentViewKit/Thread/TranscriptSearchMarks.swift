import EditorCore
import EditorDecorations
import EditorStyle
import EditorSwiftUI
import EditorText
import EditorTheme
import Foundation
import SwiftUI

/// The mark of one entry that has a search hit (TestudoApp D207 (f)).
nonisolated struct TranscriptSearchMark: Hashable {
  /// The matched words of the hit, or an empty list for a hit that only the
  /// cosine search found.
  let terms: [String]

  /// Whether the hit is the current hit.
  let isCurrent: Bool

  /// Whether the mark is on the whole entry: `true` when the hit has no
  /// terms, and `false` when the hit marks only the matches of its terms.
  var marksWholeEntry: Bool { terms.isEmpty }

  /// The find highlight of the mark in a SwiftUI view, such as the title of
  /// a tool call or the background of a whole entry.
  ///
  /// The color comes from EditorKit (`HighlightStyle`), which also paints the
  /// find marks in an editor, so all the search marks agree (D110 (e)). The
  /// current hit uses `SearchDecorations.currentMatchStyle` and gets the
  /// stronger color. Each other hit uses `SearchDecorations.matchStyle`.
  ///
  /// - Parameter theme: The EditorKit theme of the view.
  /// - Returns: The background of the search style of the hit, or `.clear`
  ///   when EditorKit gives no background for the style.
  func highlight(in theme: any Theme) -> Color {
    let style = isCurrent ? SearchDecorations.currentMatchStyle : SearchDecorations.matchStyle
    return HighlightStyle.resolvedAttributes(for: style, theme: theme).backgroundColor ?? .clear
  }
}

/// The matches of the words of a search hit in a text, and the find marks of
/// EditorKit on them (TestudoApp D207 (f)).
nonisolated enum TranscriptSearchMatches {
  /// The UTF-8 ranges of the matches of `terms` in `text`.
  ///
  /// A match has no case and no diacritics, and starts at the start of a
  /// word: the character before it is not a letter or a number. The match
  /// can end in the word, so "pars" matches the start of "parser". The
  /// matches of two terms that overlap become one range.
  ///
  /// - Parameters:
  ///   - terms: The matched words of the hit. An empty term matches nothing.
  ///   - text: The text to scan.
  /// - Returns: The ranges, in text order, with no overlap.
  static func ranges(of terms: [String], in text: String) -> [Range<Int>] {
    wordRanges(of: terms, in: text).map { utf8Range(of: $0, in: text) }
  }

  /// A plain text, such as the title of a tool call, with the find highlight
  /// as the background of each match of `terms` (``ranges(of:in:)``).
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - terms: The matched words of the hit.
  ///   - highlight: The find highlight of the theme.
  /// - Returns: The text, with the highlight on each match.
  static func highlighted(_ text: String, terms: [String], highlight: Color) -> AttributedString {
    wordRanges(of: terms, in: text).reduce(into: AttributedString(text)) { attributed, range in
      guard let marked = Range(range, in: attributed) else { return }
      attributed[marked].backgroundColor = highlight
    }
  }

  /// The find marks of a hit over the text of an editor: the decorations of
  /// EditorKit's find session (`SearchDecorations`) for the matches of the
  /// terms of the hit. When the hit is current, its first match is the
  /// current match of the session.
  ///
  /// - Parameters:
  ///   - mark: The mark of the hit.
  ///   - context: The context of the editor.
  /// - Returns: The marks.
  static func decorations(of mark: TranscriptSearchMark, in context: EditorContext) -> DecorationSet
  {
    let document = context.state.document
    let matches = ranges(of: mark.terms, in: document.string).map { range in
      EditorRange(
        document.position(utf8Offset: range.lowerBound),
        document.position(utf8Offset: range.upperBound))
    }
    let session = SearchState(
      query: mark.terms.joined(separator: " "), matches: matches,
      currentMatchIndex: mark.isCurrent && !matches.isEmpty ? 0 : nil)
    return DecorationSet(SearchDecorations.decorations(for: session))
  }

  /// The find marks of a hit over the text of an EditorKit label
  /// (`EditorLabel.editorMarks(_:)`): one mark for each match of the terms
  /// of the hit (``ranges(of:in:)``). When the hit is current, its first
  /// match has `SearchDecorations.currentMatchStyle`, as in an editor
  /// (``decorations(of:in:)``). Each other match has
  /// `SearchDecorations.matchStyle`.
  ///
  /// The function is on the main actor, as the initializer of
  /// `EditorLabelMark` is.
  ///
  /// - Parameters:
  ///   - mark: The search mark of the row, or `nil` when the entry of the
  ///     row has no hit.
  ///   - text: The text of the label.
  /// - Returns: The marks, or an empty list when there is no mark or the
  ///   hit has no terms.
  @MainActor static func labelMarks(
    of mark: TranscriptSearchMark?, in text: String
  ) -> [EditorLabelMark] {
    guard let mark else { return [] }
    return ranges(of: mark.terms, in: text).enumerated().map { index, range in
      let isCurrentMatch = mark.isCurrent && index == 0
      return EditorLabelMark(
        utf8Range: range,
        style: isCurrentMatch ? SearchDecorations.currentMatchStyle : SearchDecorations.matchStyle)
    }
  }

  /// The mark provider of an EditorKit editor (`.editorMarks(_:)`) for a
  /// hit: it gives the find marks of the hit (``decorations(of:in:)``) over
  /// the text of each editor that it marks.
  ///
  /// - Parameter mark: The search mark of the row, or `nil` when the entry
  ///   of the row has no hit.
  /// - Returns: The provider, or `nil` when there is no mark or the hit has
  ///   no terms, so that the editor gets no provider.
  static func decorationProvider(
    of mark: TranscriptSearchMark?
  ) -> ((EditorContext) -> DecorationSet)? {
    guard let mark, !mark.terms.isEmpty else { return nil }
    return { context in decorations(of: mark, in: context) }
  }

  /// The view `view` with the find marks of `mark`, or `view` with no change
  /// when there is no mark with terms (``decorationProvider(of:)``).
  ///
  /// Each view type of EditorKit that takes mark decorations calls this
  /// function with its own `editorMarks(_:)` slot.
  ///
  /// - Parameters:
  ///   - view: The view value that gets the marks.
  ///   - mark: The search mark of the row, or `nil`.
  ///   - addMarks: Adds a mark provider to a view value.
  /// - Returns: The view value, with the marks when there are terms.
  static func marking<Marked>(
    _ view: Marked,
    with mark: TranscriptSearchMark?,
    _ addMarks: (Marked, @escaping (EditorContext) -> DecorationSet) -> Marked
  ) -> Marked {
    guard let provider = decorationProvider(of: mark) else { return view }
    return addMarks(view, provider)
  }

  /// The ranges of the matches of `terms` in `text`, with each overlap of
  /// two matches made one range (``ranges(of:in:)``).
  ///
  /// - Parameters:
  ///   - terms: The matched words of the hit. An empty term matches nothing.
  ///   - text: The text to scan.
  /// - Returns: The ranges, in text order, with no overlap.
  private static func wordRanges(of terms: [String], in text: String) -> [Range<String.Index>] {
    merged(terms.filter { !$0.isEmpty }.flatMap { matches(of: $0, in: text) })
  }

  /// The ranges of the matches of one term at the start of a word.
  ///
  /// The scan goes on one character after a match that is not at the start
  /// of a word, so such a match does not hide a match at a word start in
  /// its range.
  ///
  /// - Parameters:
  ///   - term: The term, not empty.
  ///   - text: The text to scan.
  /// - Returns: The ranges, in text order.
  private static func matches(of term: String, in text: String) -> [Range<String.Index>] {
    let candidates = sequence(state: text.startIndex) {
      start -> (range: Range<String.Index>, isWordStart: Bool)? in
      guard
        let range = text.range(
          of: term, options: [.caseInsensitive, .diacriticInsensitive], range: start..<text.endIndex
        )
      else { return nil }
      let isWordStart = isWordStart(range.lowerBound, in: text)
      start = isWordStart ? range.upperBound : text.index(after: range.lowerBound)
      return (range, isWordStart)
    }
    return candidates.filter(\.isWordStart).map(\.range)
  }

  /// Whether a word starts at an index.
  ///
  /// - Parameters:
  ///   - index: An index of `text`.
  ///   - text: The text.
  /// - Returns: `true` at the start of the text, or after a character that
  ///   is not a letter or a number.
  private static func isWordStart(_ index: String.Index, in text: String) -> Bool {
    guard index > text.startIndex else { return true }
    let before = text[text.index(before: index)]
    return !(before.isLetter || before.isNumber)
  }

  /// The UTF-8 range of a range of a text.
  ///
  /// - Parameters:
  ///   - range: The range of `text`.
  ///   - text: The text.
  /// - Returns: The UTF-8 offsets of the range.
  private static func utf8Range(of range: Range<String.Index>, in text: String) -> Range<Int> {
    let utf8 = text.utf8
    return utf8.distance(
      from: utf8.startIndex, to: range.lowerBound)..<utf8.distance(
        from: utf8.startIndex, to: range.upperBound)
  }

  /// The ranges with each overlap of two ranges made one range.
  ///
  /// - Parameter ranges: The ranges, in any order.
  /// - Returns: The ranges in order, with no overlap.
  private static func merged(_ ranges: [Range<String.Index>]) -> [Range<String.Index>] {
    ranges.sorted { $0.lowerBound < $1.lowerBound }.reduce(into: []) { result, range in
      if let last = result.last, range.lowerBound < last.upperBound {
        result[result.count - 1] = last.lowerBound..<max(last.upperBound, range.upperBound)
      } else {
        result.append(range)
      }
    }
  }
}

extension EnvironmentValues {
  /// The search mark of the row around this view, or `nil` when the entry of
  /// the row has no search hit.
  @Entry var transcriptSearchMark: TranscriptSearchMark? = nil
}

extension EditorSlotComposing {
  /// Draws the find marks of the matched words of a search hit on the text
  /// of this editor, or adds nothing when there is no mark with terms.
  ///
  /// The marks are EditorKit mark decorations (`.editorMarks(_:)`). The
  /// editor asks for them on each refresh, so an editor that is made again,
  /// such as the editor of a row that comes back near the rows in view
  /// (``LiveRowRange``), draws them again.
  ///
  /// - Parameter mark: The search mark of the row, or `nil`.
  /// - Returns: The same view value, with the marks when there are terms.
  func transcriptSearchMarks(_ mark: TranscriptSearchMark?) -> Self {
    TranscriptSearchMatches.marking(self, with: mark) { $0.editorMarks($1) }
  }
}

extension PreviewField {
  /// Draws the find marks of the matched words of a search hit on the text
  /// of the editors of this preview, or adds nothing when there is no mark
  /// with terms.
  ///
  /// The marks are EditorKit mark decorations (`PreviewField.editorMarks(_:)`).
  /// For a diff, EditorKit gives the provider the text of each editor: the
  /// inline document, or each column of the side-by-side layout.
  ///
  /// - Parameter mark: The search mark of the row, or `nil`.
  /// - Returns: The same field, with the marks when there are terms.
  func transcriptSearchMarks(_ mark: TranscriptSearchMark?) -> PreviewField {
    TranscriptSearchMatches.marking(self, with: mark) { $0.editorMarks($1) }
  }
}

/// The search mark of one row of a thread: the mark of the row in the
/// environment of the row, and the find highlight of the theme on the whole
/// row when the hit has no terms (TestudoApp D207 (f)).
///
/// The highlight is the find color of the theme with no added opacity. The
/// find colors of EditorKit are weak tints that keep a contrast of at least
/// 4.5:1 with the text, so the text of the row stays legible on them.
///
/// A row with no hit gets no environment value and no background, so its
/// look and its accessibility do not change.
struct TranscriptSearchRowMark: ViewModifier {
  /// The row key of the entry of the row.
  let rowKey: String

  @Environment(\.transcriptSearch) private var search
  @Environment(\.editorTheme) private var editorTheme
  @Environment(\.editorStyle) private var editorStyle

  func body(content: Content) -> some View {
    let mark = search?.mark(forRowKey: rowKey)
    content
      .environment(\.transcriptSearchMark, mark)
      .background {
        if let mark, mark.marksWholeEntry {
          EditorSurface.shape(radius: SurfaceCorners.card.radius(in: editorStyle))
            .fill(mark.highlight(in: editorTheme))
            .accessibilityHidden(true)
        }
      }
  }
}
