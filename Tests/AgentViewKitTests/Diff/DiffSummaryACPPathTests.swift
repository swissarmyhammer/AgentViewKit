@testable import AgentViewKit
import AgentViewKitStyle
import Testing

/// The paths of an ACP `git_patch`: absolute paths with no `a/` and `b/`
/// prefix (ACP `DiffPatchFormat.gitPatch`), as FoundationModelsACPAgent
/// writes them, and the git quoting of an unusual path.
@Suite struct DiffSummaryACPPathTests {
  static let path = "/var/folders/T/Agents/Greeting.swift"

  /// A change in the form of the `WholeFilePatch` of FoundationModelsACPAgent.
  static let acpModify = """
    diff --git \(path) \(path)
    --- \(path)
    +++ \(path)
    @@ -1,2 +1,2 @@
    -let greeting = "Hello"
    -print(greeting)
    +let greeting = "Hello, world"
    +print(greeting)

    """

  @Test func acpPatchHasTheAbsolutePath() {
    let files = DiffSummary.parse(gitPatch: Self.acpModify)
    #expect(files.map(\.path) == [Self.path])
    #expect(files.first?.operation == .modify)
    #expect(files.first?.hunks.count == 1)
  }

  @Test func acpNewFileHasTheAbsolutePath() {
    let patch = """
      diff --git \(Self.path) \(Self.path)
      new file mode 100644
      --- /dev/null
      +++ \(Self.path)
      @@ -0,0 +1 @@
      +let greeting = "Hello"

      """
    let files = DiffSummary.parse(gitPatch: patch)
    #expect(files.map(\.path) == [Self.path])
    #expect(files.first?.operation == .add)
  }

  @Test func acpDeletedFileKeepsTheOldPath() {
    let patch = """
      diff --git \(Self.path) \(Self.path)
      deleted file mode 100644
      --- \(Self.path)
      +++ /dev/null
      @@ -1 +0,0 @@
      -let greeting = "Hello"

      """
    let files = DiffSummary.parse(gitPatch: patch)
    #expect(files.map(\.path) == [Self.path])
    #expect(files.first?.operation == .delete)
  }

  @Test func acpPathWithASpaceSplitsInTheMiddle() {
    let path = "/Users/me/My Project/a b.swift"
    let patch = """
      diff --git \(path) \(path)
      --- \(path)
      +++ \(path)
      @@ -1 +1 @@
      -a
      +b

      """
    #expect(DiffSummary.parse(gitPatch: patch).map(\.path) == [path])
  }

  @Test func acpHeaderAloneGivesTheNewPathOfARename() {
    let patch = """
      diff --git /r/old.swift /r/new.swift
      similarity index 100%
      rename from /r/old.swift
      rename to /r/new.swift

      """
    #expect(DiffSummary.parse(gitPatch: patch).map(\.path) == ["/r/new.swift"])
  }

  @Test func quotedPathIsUnquoted() {
    let patch = """
      diff --git "/r/caf\\303\\251\\tx.swift" "/r/caf\\303\\251\\tx.swift"
      --- "/r/caf\\303\\251\\tx.swift"
      +++ "/r/caf\\303\\251\\tx.swift"
      @@ -1 +1 @@
      -a
      +b

      """
    #expect(DiffSummary.parse(gitPatch: patch).map(\.path) == ["/r/café\tx.swift"])
  }

  @Test func quotedGitPathLosesItsPrefix() {
    let patch = """
      diff --git "a/caf\\303\\251.md" "b/caf\\303\\251.md"

      """
    #expect(DiffSummary.parse(gitPatch: patch).map(\.path) == ["café.md"])
  }

  @Test func gitPatchKeepsItsRelativePath() {
    let patch = """
      diff --git a/Sources/App.swift b/Sources/App.swift
      --- a/Sources/App.swift
      +++ b/Sources/App.swift
      @@ -1 +1 @@
      -a
      +b

      """
    #expect(DiffSummary.parse(gitPatch: patch).map(\.path) == ["Sources/App.swift"])
  }
}

/// The EditorKit preview of an ACP `git_patch` (EditorKit c31d8069 reads the
/// unprefixed absolute paths).
@MainActor @Suite struct DiffPreviewACPPatchTests {
  @Test func acpPatchParsesAndFindsItsFile() throws {
    let diff = try DiffView.diff(of: DiffSummaryACPPathTests.acpModify, file: DiffSummaryACPPathTests.path).get()
    #expect(diff.files.count == 1)
    #expect(diff.files.first?.newPath == DiffSummaryACPPathTests.path)
  }

  @Test func pathOfTheSummaryIsThePathOfThePreview() throws {
    let summary = try #require(DiffSummary.parse(gitPatch: DiffSummaryACPPathTests.acpModify).first)
    let diff = try DiffView.diff(of: DiffSummaryACPPathTests.acpModify, file: summary.path).get()
    #expect(diff.files.first.map { $0.newPath ?? $0.oldPath } == summary.path)
  }
}
