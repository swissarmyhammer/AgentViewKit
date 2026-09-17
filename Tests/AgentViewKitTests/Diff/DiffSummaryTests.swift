import AgentViewKit
import Testing

@Suite struct DiffSummaryTests {
  /// A git patch that changes two files.
  static let twoFilePatch = """
    diff --git a/Sources/App.swift b/Sources/App.swift
    index 1111111..2222222 100644
    --- a/Sources/App.swift
    +++ b/Sources/App.swift
    @@ -1,3 +1,4 @@
     import SwiftUI
    -let name = "old"
    +let name = "new"
    +let count = 2
     struct App {}
    @@ -10,2 +11,2 @@
    --- a comment line that starts with two dashes
    +-- a comment line that starts with two dashes
     }
    diff --git a/README.md b/README.md
    index 3333333..4444444 100644
    --- a/README.md
    +++ b/README.md
    @@ -1 +1,2 @@
     # Title
    +More text.

    """

  /// A git patch that adds a file.
  static let addPatch = """
    diff --git a/new.py b/new.py
    new file mode 100644
    index 0000000..5555555
    --- /dev/null
    +++ b/new.py
    @@ -0,0 +1,2 @@
    +print("a")
    +print("b")

    """

  /// A git patch that deletes a file.
  static let deletePatch = """
    diff --git a/old.txt b/old.txt
    deleted file mode 100644
    index 6666666..0000000
    --- a/old.txt
    +++ /dev/null
    @@ -1,3 +0,0 @@
    -one
    -two
    -three

    """

  /// A git patch that renames a file and changes one line.
  static let renamePatch = """
    diff --git a/src/a.rs b/src/b.rs
    similarity index 90%
    rename from src/a.rs
    rename to src/b.rs
    index 7777777..8888888 100644
    --- a/src/a.rs
    +++ b/src/b.rs
    @@ -1,2 +1,2 @@
     fn main() {
    -}
    +    }

    """

  /// A plain unified diff with no git header lines.
  static let plainPatch = """
    --- x
    +++ x
    @@ -1 +1 @@
    -old
    +new
    --- y\t2026-01-01
    +++ y\t2026-01-02
    @@ -1,2 +1 @@
    -a
    -b
    +c

    """

  @Test func aTwoFilePatchGivesTwoSummariesWithTheirCounts() {
    let files = DiffSummary.parse(gitPatch: Self.twoFilePatch)

    #expect(files.map(\.path) == ["Sources/App.swift", "README.md"])
    #expect(files.map(\.operation) == [.modified, .modified])
    #expect(files.map(\.added) == [3, 1])
    #expect(files.map(\.removed) == [2, 0])
    #expect(files[0].hunks.count == 2)
    #expect(files[0].hunks[1].header == "@@ -10,2 +11,2 @@")
    #expect(
      files[0].hunks[1].lines == [
        "--- a comment line that starts with two dashes",
        "+-- a comment line that starts with two dashes",
        " }",
      ])
    #expect(files[1].hunks.count == 1)
  }

  @Test func anAddedFileCountsItsLines() {
    let files = DiffSummary.parse(gitPatch: Self.addPatch)

    #expect(files.count == 1)
    #expect(files.first?.path == "new.py")
    #expect(files.first?.operation == .added)
    #expect(files.first?.added == 2)
    #expect(files.first?.removed == 0)
  }

  @Test func aDeletedFileKeepsItsOldPath() {
    let files = DiffSummary.parse(gitPatch: Self.deletePatch)

    #expect(files.count == 1)
    #expect(files.first?.path == "old.txt")
    #expect(files.first?.operation == .deleted)
    #expect(files.first?.added == 0)
    #expect(files.first?.removed == 3)
  }

  @Test func aRenamedFileHasItsNewPathAndItsOldPath() {
    let files = DiffSummary.parse(gitPatch: Self.renamePatch)

    #expect(files.count == 1)
    #expect(files.first?.path == "src/b.rs")
    #expect(files.first?.operation == .renamed(from: "src/a.rs"))
    #expect(files.first?.added == 1)
    #expect(files.first?.removed == 1)
  }

  @Test func aPlainUnifiedDiffSplitsAtEachFileHeader() {
    let files = DiffSummary.parse(gitPatch: Self.plainPatch)

    #expect(files.map(\.path) == ["x", "y"])
    #expect(files.map(\.operation) == [.modified, .modified])
    #expect(files.map(\.added) == [1, 1])
    #expect(files.map(\.removed) == [1, 2])
  }

  @Test func textWithNoDiffGivesNoSummary() {
    #expect(DiffSummary.parse(gitPatch: "").isEmpty)
    #expect(DiffSummary.parse(gitPatch: "just some words\n").isEmpty)
  }

  @Test func theChangedLinesAreTheAddedAndRemovedLines() {
    let file = DiffSummary.parse(gitPatch: Self.renamePatch)[0]

    #expect(file.changedLines == ["-}", "+    }"])
  }

  @Test func theLanguageComesFromTheFileExtension() {
    #expect(DiffSummary.language(forPath: "Sources/App.swift") == "Swift")
    #expect(DiffSummary.language(forPath: "new.py") == "Python")
    #expect(DiffSummary.language(forPath: "notes.xyz") == "XYZ")
    #expect(DiffSummary.language(forPath: "Makefile") == "Text")
  }

  @Test func theAccessibilityLabelHasTheLanguageAndTheCounts() {
    let file = DiffSummary.parse(gitPatch: Self.addPatch)[0]

    #expect(file.accessibilityLabel == "Python diff, +2 \u{2212}0")
  }
}
