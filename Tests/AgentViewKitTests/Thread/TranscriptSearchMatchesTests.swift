import EditorCore
import EditorSwiftUI
import EditorText
import SwiftUI
import Testing

@testable import AgentViewKit

/// The ranges of the matched words of a search hit in a text, and the find
/// marks that EditorKit draws on them (D207 (f)).
@MainActor @Suite struct TranscriptSearchMatchesTests {
  /// A production change that fails this test: the match compares the case,
  /// so "Parser" and "PARSER" get no mark.
  @Test func aTermMatchesWithNoCase() {
    let ranges = TranscriptSearchMatches.ranges(of: ["parser"], in: "Parser parser PARSER")

    #expect(ranges == [0..<6, 7..<13, 14..<20])
  }

  /// A production change that fails this test: the match compares the
  /// diacritics, so "cafe" does not find "café".
  @Test func aTermMatchesWithNoDiacritics() {
    let ranges = TranscriptSearchMatches.ranges(of: ["cafe"], in: "Le café")

    // "é" has two UTF-8 bytes, so the range of "café" is five bytes long.
    #expect(ranges == [3..<8])
  }

  /// A production change that fails this test: the match compares the
  /// diacritics of the term, so "café" does not find "cafe".
  @Test func aTermWithADiacriticMatchesAPlainWord() {
    let ranges = TranscriptSearchMatches.ranges(of: ["café"], in: "cafe")

    #expect(ranges == [0..<4])
  }

  /// A production change that fails this test: the match finds a term in
  /// the middle of a word, so "decafe" gets a mark.
  @Test func aTermMatchesOnlyAtTheStartOfAWord() {
    let ranges = TranscriptSearchMatches.ranges(of: ["cafe"], in: "decafe cafeteria")

    #expect(ranges == [7..<11])
  }

  /// A production change that fails this test: the matches of two terms
  /// overlap, and EditorKit gets two marks on the same text.
  @Test func theMatchesOfTwoTermsMergeWhereTheyOverlap() {
    let ranges = TranscriptSearchMatches.ranges(of: ["pars", "parser"], in: "a parser")

    #expect(ranges == [2..<8])
  }

  /// A production change that fails this test: an empty term matches at
  /// the start of each word.
  @Test func anEmptyTermMatchesNothing() {
    #expect(TranscriptSearchMatches.ranges(of: [""], in: "a parser").isEmpty)
  }

  /// A production change that fails this test: the marks of the current
  /// hit have no current match, so they look like the marks of each other
  /// hit.
  @Test func theMarksOfTheCurrentHitHaveTheCurrentStyle() {
    let context = EditorContext(EditorModel.makeReadOnly("Parser parser").state)
    let mark = TranscriptSearchMark(terms: ["parser"], isCurrent: true)

    let styles = TranscriptSearchMatches.decorations(of: mark, in: context).decorations.map(\.style)

    #expect(
      styles.sorted()
        == [SearchDecorations.currentMatchStyle, SearchDecorations.matchStyle].sorted())
  }

  /// A production change that fails this test: a hit that is not current
  /// gets the current style.
  @Test func theMarksOfAnotherHitHaveTheMatchStyle() {
    let context = EditorContext(EditorModel.makeReadOnly("Parser parser").state)
    let mark = TranscriptSearchMark(terms: ["parser"], isCurrent: false)

    let styles = TranscriptSearchMatches.decorations(of: mark, in: context).decorations.map(\.style)

    #expect(styles == [SearchDecorations.matchStyle, SearchDecorations.matchStyle])
  }

  /// A production change that fails this test: a hit with no terms gets no
  /// mark on its entry.
  @Test func aHitWithNoTermsMarksTheWholeEntry() {
    let mark = TranscriptSearchMark(terms: [], isCurrent: false)

    #expect(mark.wholeEntryOpacity == TranscriptSearchMark.wholeEntryOpacity)
  }

  /// A production change that fails this test: the current hit with no
  /// terms has the same mark as each other hit.
  @Test func theCurrentHitWithNoTermsHasTheStrongerMark() {
    let mark = TranscriptSearchMark(terms: [], isCurrent: true)

    #expect(mark.wholeEntryOpacity == TranscriptSearchMark.currentWholeEntryOpacity)
  }

  /// A production change that fails this test: a hit with terms also marks
  /// its whole entry.
  @Test func aHitWithTermsDoesNotMarkTheWholeEntry() {
    let mark = TranscriptSearchMark(terms: ["parser"], isCurrent: true)

    #expect(mark.wholeEntryOpacity == nil)
  }

  // MARK: - Plain text

  /// A production change that fails this test: a match in a plain text, such
  /// as the title of a tool call, gets no find highlight.
  @Test func aMatchInAPlainTextHasTheHighlight() {
    let text = TranscriptSearchMatches.highlighted(
      "Run the Parser", terms: ["parser"], highlight: .red)

    let marked: [String] = text.runs.filter { run in run.backgroundColor == Color.red }.map { run in
      String(text[run.range].characters)
    }

    #expect(marked == ["Parser"])
  }

  /// A production change that fails this test: the text out of the matches
  /// gets the highlight too.
  @Test func theTextOutOfTheMatchesHasNoHighlight() {
    let text = TranscriptSearchMatches.highlighted(
      "Run the Parser", terms: ["parser"], highlight: .red)

    let plain: [String] = text.runs.filter { run in run.backgroundColor == nil }.map { run in
      String(text[run.range].characters)
    }

    #expect(plain == ["Run the "])
  }
}
