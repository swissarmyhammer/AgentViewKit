import EditorSwiftUI
import Testing

@testable import AgentViewKit

/// Checks what the EditorKit preview of a ``DiffView`` shows, with no view.
@Suite @MainActor struct DiffPreviewSourceTests {
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

  /// A patch whose hunk header EditorKit cannot read.
  static let unreadablePatch = "--- a/A.swift\n+++ b/A.swift\n@@ bad @@\n-a\n+b"

  @Test func aReadablePatchPreviewsTheDiffOfTheSelectedFile() throws {
    let selected = try EditorKitDiffRenderer.diff(of: Self.patch, file: Self.secondPath).get()

    #expect(DiffView.previewSource(of: Self.patch, file: Self.secondPath) == .value(.diff(selected)))
  }

  @Test func anUnreadablePatchShowsNoDiffAtOnce() {
    let source = DiffView.previewSource(of: Self.unreadablePatch, file: nil)

    #expect(source.summary == EditorSwiftUIStrings.preview)
  }
}
