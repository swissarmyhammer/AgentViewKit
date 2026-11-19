import EditorSwiftUI
import EditorText
import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The find marks of a search hit on the text of a plan entry of
/// ``TaskListView`` (D207 (f)). The marks are EditorKit label marks
/// (`EditorLabel.editorMarks(_:)`), so the tests read them with no window.
@Suite struct TaskListViewSearchMarksTests {
  /// A plan entry whose text has two matches of the term "parser".
  static let entry = PlanEntry(
    content: "Change the parser, then test the Parser", priority: .medium, status: .inProgress)

  /// The text of each mark of `marks` in the text of ``entry``.
  ///
  /// - Parameter marks: The marks of the entry.
  /// - Returns: The marked text of each mark, in order.
  static func markedText(of marks: [EditorLabelMark]) -> [String] {
    let utf8 = Array(entry.content.utf8)
    return marks.map { String(decoding: utf8[$0.utf8Range], as: UTF8.self) }
  }

  /// A production change that fails this test: the marks of a plan entry
  /// are not on the matches of the terms of the hit.
  @Test func eachMatchOfATermInAPlanEntryHasAMark() {
    let marks = TaskListView.entryMarks(
      Self.entry, mark: TranscriptSearchMark(terms: ["parser"], isCurrent: false))

    #expect(Self.markedText(of: marks) == ["parser", "Parser"])
  }

  /// A production change that fails this test: the first match of the
  /// current hit does not get the stronger mark, or each other match gets it.
  @Test func theFirstMatchOfTheCurrentHitHasTheCurrentStyle() {
    let marks = TaskListView.entryMarks(
      Self.entry, mark: TranscriptSearchMark(terms: ["parser"], isCurrent: true))

    #expect(
      marks.map(\.style) == [SearchDecorations.currentMatchStyle, SearchDecorations.matchStyle])
  }

  /// A production change that fails this test: a hit that is not current
  /// gets the current style on a plan entry.
  @Test func theMatchesOfAnotherHitHaveTheMatchStyle() {
    let marks = TaskListView.entryMarks(
      Self.entry, mark: TranscriptSearchMark(terms: ["parser"], isCurrent: false))

    #expect(marks.map(\.style) == [SearchDecorations.matchStyle, SearchDecorations.matchStyle])
  }

  /// A production change that fails this test: a plan entry in a row with
  /// no hit gets marks, so its look changes.
  @Test func aPlanEntryWithNoHitHasNoMarks() {
    #expect(TaskListView.entryMarks(Self.entry, mark: nil).isEmpty)
  }

  /// A production change that fails this test: a hit with no terms marks
  /// words of a plan entry, although the whole row has the mark.
  @Test func aHitWithNoTermsPutsNoMarksOnAPlanEntry() {
    let marks = TaskListView.entryMarks(
      Self.entry, mark: TranscriptSearchMark(terms: [], isCurrent: true))

    #expect(marks.isEmpty)
  }
}
