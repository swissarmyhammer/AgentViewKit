import EditorCommands
import EditorDiff
import SwiftUI
import Testing

@testable import AgentViewKitStyle

/// Checks the diff renderer setup, the diff summary, the file chip and the
/// tool call scope kind through their public API.
@Suite @MainActor struct DiffStyleTests {
  /// The path of the first file of the sample patch.
  static let firstPath = "Sources/A.swift"

  /// The path of the second file of the sample patch.
  static let secondPath = "Sources/B.swift"

  /// A patch of two files: one changed line in each.
  static let patch = """
    diff --git a/Sources/A.swift b/Sources/A.swift
    --- a/Sources/A.swift
    +++ b/Sources/A.swift
    @@ -1 +1 @@
    -let a = 1
    +let a = 2
    diff --git a/Sources/B.swift b/Sources/B.swift
    --- a/Sources/B.swift
    +++ b/Sources/B.swift
    @@ -1 +1,2 @@
    -let b = 1
    +let b = 2
    +let c = 3
    """

  /// A patch whose hunk header EditorKit cannot read, on its third line.
  static let unreadablePatch = "--- a/A.swift\n+++ b/A.swift\n@@ bad @@\n-a\n+b"

  /// The line of the hunk header of ``unreadablePatch``.
  static let unreadableLine = 3

  @Test func theSummaryCountsTheLinesOfEachFile() throws {
    let files = DiffSummary.parse(gitPatch: Self.patch)

    #expect(files.map(\.path) == [Self.firstPath, Self.secondPath])
    #expect(files.map(\.added) == [1, 2])
    #expect(files.map(\.removed) == [1, 1])
  }

  @Test func eachOperationHasALabel() {
    let operations: [DiffSummary.Operation] = [
      .added, .deleted, .modified, .renamed(from: "a"), .copied(from: "a"), .binary, .unknown("x"),
    ]

    #expect(operations.map(\.label) == ["Added", "Deleted", "Modified", "Renamed", "Copied", "Binary", "Changed"])
  }

  @Test func theChangeLabelOfAFileNamesItsOperationAndItsLanguage() {
    let file = DiffSummary.FileSummary(path: Self.firstPath, operation: .added, hunks: [])

    #expect(file.changeAccessibilityLabel == "Added Swift file")
  }

  @Test func theIdentifierOfAFileChipIsThePrefixAndThePath() {
    #expect(DiffFileChip.identifier(for: Self.firstPath) == DiffFileChip.identifierPrefix + Self.firstPath)
  }

  @Test func eachFileOperationHasTheSymbolOfItsConcept() {
    #expect(DiffFileChip.symbolName(for: .added) == SharedSymbol.addedFile)
    #expect(DiffFileChip.symbolName(for: .deleted) == SharedSymbol.deletedFile)
    #expect(DiffFileChip.symbolName(for: .modified) == SharedSymbol.modifiedFile)
    #expect(DiffFileChip.symbolName(for: .renamed(from: "a")) == SharedSymbol.renamedFile)
    #expect(DiffFileChip.symbolName(for: .copied(from: "a")) == SharedSymbol.copiedFile)
    #expect(DiffFileChip.symbolName(for: .binary) == SharedSymbol.binary)
  }

  @Test func aBinaryFileOfAPatchHasTheBinaryOperation() {
    let files = DiffSummary.parse(
      gitPatch: """
        diff --git a/logo.png b/logo.png
        index 1234567..89abcde 100644
        Binary files a/logo.png and b/logo.png differ
        """)

    #expect(files.map(\.operation) == [.binary])
  }

  @Test func aGitBinaryPatchHasTheBinaryOperation() {
    let files = DiffSummary.parse(
      gitPatch: """
        diff --git a/logo.png b/logo.png
        index 1234567..89abcde 100644
        GIT binary patch
        """)

    #expect(files.map(\.operation) == [.binary])
  }

  @Test func theBinaryOperationHasItsWord() {
    #expect(DiffSummary.Operation.binary.label == "Binary")
  }

  @Test func aLabelWithNoOperationShowsTheDocumentSymbol() {
    #expect(DiffFileLabel.symbolName(for: nil) == SharedSymbol.document)
  }

  @Test func aLabelWithAnOperationShowsTheSymbolOfTheOperation() {
    #expect(DiffFileLabel.symbolName(for: .added) == SharedSymbol.addedFile)
  }

  @Test func aLabelKeepsItsCounts() {
    let counts = DiffFileLabel.Counts(added: 1, removed: 2)

    #expect(DiffFileLabel.shownCounts(counts, for: .modified) == counts)
  }

  @Test func aBinaryFileShowsNoCounts() {
    #expect(DiffFileLabel.shownCounts(DiffFileLabel.Counts(added: 1, removed: 2), for: .binary) == nil)
  }

  @Test func aLabelNamesTheLastPartOfThePath() {
    #expect(DiffFileLabel.name(ofPath: "Sources/Board/BoardColumn.swift") == "BoardColumn.swift")
  }

  @Test func theRendererKeepsOnlyTheSelectedFile() throws {
    let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: Self.secondPath).get()

    #expect(diff.files.map(\.newPath) == [Self.secondPath])
  }

  @Test func theRendererKeepsEachFileWithNoSelection() throws {
    let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: nil).get()

    #expect(diff.files.count == 2)
  }

  @Test func theRendererKeepsEachFileWhenTheSelectionMatchesNone() throws {
    let diff = try EditorKitDiffRenderer.diff(of: Self.patch, file: "Missing.swift").get()

    #expect(diff.files.count == 2)
  }

  @Test func theRendererGivesTheLineWhereTheParseStopped() {
    let error = #expect(throws: UnifiedDiffError.self) {
      try EditorKitDiffRenderer.diff(of: Self.unreadablePatch, file: nil).get()
    }

    #expect(error.map(EditorKitDiffRenderer.line(of:)) == Self.unreadableLine)
  }

  @Test func eachDiffLayoutHasItsEditorKitLayout() {
    #expect(DiffLayout.inline.documentLayout == .inline)
    #expect(DiffLayout.sideBySide.documentLayout == .sideBySide)
  }

  @Test func theDefaultDiffLayoutIsInline() {
    #expect(EnvironmentValues().diffLayout == .inline)
  }

  @Test func theToolCallSegmentNamesTheToolCallID() {
    let segment = AgentScopeKind.toolCall("call-1")

    #expect(segment == FocusSegment(kind: AgentScopeKind.toolCall, id: "call-1"))
  }
}
