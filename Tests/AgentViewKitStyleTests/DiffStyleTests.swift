import EditorCommands
import EditorDiff
import SwiftUI
import Testing

@testable import AgentViewKitStyle

/// Checks the diff summary, the word of an operation and the tool call
/// scope kind through their public API.
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

  @Test func theSummaryCountsTheLinesOfEachFile() throws {
    let files = DiffSummary.parse(gitPatch: Self.patch)

    #expect(files.map(\.path) == [Self.firstPath, Self.secondPath])
    #expect(files.map(\.added) == [1, 2])
    #expect(files.map(\.removed) == [1, 1])
  }

  @Test func eachOperationHasALabel() {
    let operations: [FileDiff.Operation] = [
      .add, .delete, .modify, .rename(from: "a"), .copy(from: "a"), .binary, .unknown("x"),
    ]

    #expect(operations.map(\.label) == ["Added", "Deleted", "Modified", "Renamed", "Copied", "Binary", "Changed"])
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
    #expect(FileDiff.Operation.binary.label == "Binary")
  }

  @Test func theToolCallSegmentNamesTheToolCallID() {
    let segment = AgentScopeKind.toolCall("call-1")

    #expect(segment == FocusSegment(kind: AgentScopeKind.toolCall, id: "call-1"))
  }
}
