import EditorCore
import EditorDiff
import EditorSwiftUI
import EditorText
import Testing

@testable import AgentViewKit

/// The find marks of a search hit on the text of a diff (D207 (f)).
///
/// The EditorKit diff view gives the mark provider of AVK the context of each
/// of its editors: one inline document, or one document for each column of
/// the side-by-side layout. The tests run the provider on the same documents
/// of EditorKit (`DiffDocument`), with no window.
@MainActor @Suite struct DiffSearchMarksTests {
  /// A patch of one file whose new line adds the word "strict".
  static let patch = """
    --- a/Sources/A.swift
    +++ b/Sources/A.swift
    @@ -1 +1 @@
    -let value = Value()
    +let value = Value(strict: true)
    """

  /// A hit on the word "strict" of ``patch``.
  static let strictHit = TranscriptSearchMark(terms: ["strict"], isCurrent: false)

  /// The text that each mark of the provider of `mark` covers in `text`.
  ///
  /// - Parameters:
  ///   - mark: The search mark of the row.
  ///   - text: The text of one editor of the diff.
  /// - Returns: The marked text of each mark, in order.
  static func markedText(of mark: TranscriptSearchMark, in text: String) throws -> [String] {
    let provider = try #require(TranscriptSearchMatches.decorationProvider(of: mark))
    let context = EditorContext(EditorModel.makeReadOnly(text).state)
    let ranges = provider(context).decorations.map(\.byteRange)
    return AgentViewKitTests.markedText(of: ranges, in: text)
  }

  /// The parsed ``patch``.
  ///
  /// - Returns: The diff of the patch.
  static func parsedPatch() throws -> UnifiedDiff {
    try UnifiedDiff.parse(patch)
  }

  /// A production change that fails this test: the inline diff gets no mark
  /// on a match of a term of the hit.
  @Test func aMatchInTheInlineDiffHasAMark() throws {
    let document = DiffDocument(
      inline: try Self.parsedPatch(), contextLines: LineDiff.defaultContext)

    #expect(try Self.markedText(of: Self.strictHit, in: document.text) == ["strict"])
  }

  /// A production change that fails this test: the new column of the
  /// side-by-side diff gets no mark on a match of a term of the hit.
  @Test func aMatchInTheNewColumnHasAMark() throws {
    let columns = DiffDocument.sideBySide(
      try Self.parsedPatch(), contextLines: LineDiff.defaultContext)

    #expect(try Self.markedText(of: Self.strictHit, in: columns.new.text) == ["strict"])
  }

  /// A production change that fails this test: the old column of the
  /// side-by-side diff gets a mark, although its text has no match.
  @Test func theOldColumnWithNoMatchHasNoMark() throws {
    let columns = DiffDocument.sideBySide(
      try Self.parsedPatch(), contextLines: LineDiff.defaultContext)

    #expect(try Self.markedText(of: Self.strictHit, in: columns.old.text).isEmpty)
  }

  /// A production change that fails this test: a diff in a row with no hit
  /// gets a mark provider, so its editors change.
  @Test func aDiffWithNoHitHasNoMarkProvider() {
    #expect(TranscriptSearchMatches.decorationProvider(of: nil) == nil)
  }

  /// A production change that fails this test: a hit with no terms gives a
  /// mark provider to the diff, although the whole row has the mark.
  @Test func aHitWithNoTermsHasNoMarkProvider() {
    #expect(
      TranscriptSearchMatches.decorationProvider(
        of: TranscriptSearchMark(terms: [], isCurrent: true)) == nil)
  }
}
