#if DEBUG
  @testable import AgentViewKit
  import FoundationModelsACP
  import Testing

  /// The files of an ACP diff, and the location paths that name them (card
  /// ^tgjr9xg). A tool call shows no location chip for a file that its diff
  /// shows, so the two must agree on which path names which file.
  @Suite struct DiffFileLocationTests {
    /// The relative path of the file of ``patch``.
    static let relativePath = "Sources/App.swift"

    /// A git patch that changes ``relativePath``.
    static let patch = """
      diff --git a/Sources/App.swift b/Sources/App.swift
      --- a/Sources/App.swift
      +++ b/Sources/App.swift
      @@ -1 +1 @@
      -let name = "old"
      +let name = "new"

      """

    /// The absolute path of the file of the structured change.
    static let absolutePath = "/project/Sources/new.swift"

    /// One structured change that adds ``absolutePath``.
    static let changes = [
      DiffChange(operation: .add(DiffPathChange(path: AbsolutePath(rawValue: absolutePath))))
    ]

    /// The one file of ``patch``.
    static var patchFile: DiffSummary.FileSummary {
      DiffSummary.FileSummary(path: relativePath, operation: .modified, hunks: [])
    }

    // MARK: - Files of a diff

    @Test func aDiffWithGitPatchTextGivesTheFilesOfThePatch() {
      let diff = FoundationModelsACP.Diff(changes: Self.changes, patch: DiffPatch(format: .gitPatch, text: Self.patch))

      #expect(DiffSummary.files(of: diff).map(\.path) == [Self.relativePath])
    }

    @Test func aDiffWithNoPatchTextGivesTheFilesOfItsChanges() {
      let diff = FoundationModelsACP.Diff(changes: Self.changes)

      #expect(DiffSummary.files(of: diff).map(\.path) == [Self.absolutePath])
    }

    // MARK: - Location paths

    @Test func theSamePathNamesTheFile() {
      let file = DiffSummary.FileSummary(path: Self.absolutePath, operation: .added, hunks: [])

      #expect(file.hasPath(Self.absolutePath))
    }

    @Test func anAbsolutePathThatEndsWithTheRelativePathNamesTheFile() {
      #expect(Self.patchFile.hasPath("/project/" + Self.relativePath))
    }

    @Test func aPathThatEndsInsideAFolderNameDoesNotNameTheFile() {
      #expect(!Self.patchFile.hasPath("/project/My" + Self.relativePath))
    }

    @Test func anotherAbsolutePathDoesNotNameAnAbsoluteFile() {
      let file = DiffSummary.FileSummary(path: Self.absolutePath, operation: .added, hunks: [])

      #expect(!file.hasPath("/other" + Self.absolutePath))
    }
  }
#endif
