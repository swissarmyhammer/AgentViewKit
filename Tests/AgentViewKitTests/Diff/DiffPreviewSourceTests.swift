import EditorDiff
import EditorSwiftUI
import Testing

@testable import AgentViewKit

/// Checks what the EditorKit preview of a ``DiffView`` shows, with no view:
/// the file filter of the patch, the source of the preview, and the failure
/// of a patch that EditorKit cannot read.
@Suite @MainActor struct DiffPreviewSourceTests {
  /// The path of the first file of the patch.
  static let firstPath = "Sources/A.swift"

  /// The path of the second file of the patch.
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
    @@ -1 +1 @@
    -let b = 1
    +let b = 2
    """

  /// A patch whose hunk header EditorKit cannot read, on its third line.
  static let unreadablePatch = "--- a/A.swift\n+++ b/A.swift\n@@ bad @@\n-a\n+b"

  /// The line of the hunk header of ``unreadablePatch``.
  static let unreadableLine = 3

  // MARK: - File filter

  @Test func aSelectedFileKeepsOnlyThatFile() throws {
    let diff = try DiffView.diff(of: Self.patch, file: Self.secondPath).get()

    #expect(diff.files.map(\.newPath) == [Self.secondPath])
  }

  @Test func noSelectedFileKeepsEachFile() throws {
    let diff = try DiffView.diff(of: Self.patch, file: nil).get()

    #expect(diff.files.map(\.newPath) == [Self.firstPath, Self.secondPath])
  }

  @Test func aSelectionThatMatchesNoFileKeepsEachFile() throws {
    let diff = try DiffView.diff(of: Self.patch, file: "Missing.swift").get()

    #expect(diff.files.count == 2)
  }

  @Test func anUnreadablePatchGivesTheLineWhereTheParseStopped() {
    let error = #expect(throws: UnifiedDiffError.self) {
      try DiffView.diff(of: Self.unreadablePatch, file: nil).get()
    }

    #expect(error.map { UnreadablePatch($0).line } == Self.unreadableLine)
  }

  @Test func eachParseErrorGivesItsLine() {
    let errors: [UnifiedDiffError] = [
      .malformedHunkHeader(line: 3), .hunkLineCountMismatch(line: 4), .unexpectedLine(line: 5),
    ]

    #expect(errors.map { UnreadablePatch($0).line } == [3, 4, 5])
  }

  @Test func anUnreadablePatchSaysTheLineWhereTheParseStopped() {
    let unreadable = UnreadablePatch(.malformedHunkHeader(line: Self.unreadableLine))

    #expect(unreadable.errorDescription == "Cannot read the patch at line \(Self.unreadableLine)")
  }

  // MARK: - Preview source

  @Test func aReadablePatchPreviewsTheDiffOfTheSelectedFile() throws {
    let selected = try DiffView.diff(of: Self.patch, file: Self.secondPath).get()

    #expect(DiffView.previewSource(of: Self.patch, file: Self.secondPath) == .value(.diff(selected)))
  }

  @Test func anUnreadablePatchShowsNoDiffAtOnce() {
    let source = DiffView.previewSource(of: Self.unreadablePatch, file: nil)

    #expect(source.summary == EditorSwiftUIStrings.preview)
  }
}
