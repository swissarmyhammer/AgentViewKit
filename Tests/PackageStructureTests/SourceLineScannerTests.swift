import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// The shared line scan of ``SourceLineScanner``.
@Suite struct SourceLineScannerTests {
  /// The fixture directory. It holds one Swift file at the top and one Swift
  /// file in a subdirectory.
  static var fixtures: URL {
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/ImportBoundary/Violating") }
  }

  @Test func matchesGivesEachLineItsFileAndNumber() {
    let found = SourceLineScanner.matches(inSource: "first\n\nthird", file: "A.swift") { line in
      [line]
    }

    #expect(
      found == [
        SourceLine(file: "A.swift", number: 1, text: "first"),
        SourceLine(file: "A.swift", number: 2, text: ""),
        SourceLine(file: "A.swift", number: 3, text: "third"),
      ]
    )
  }

  @Test func matchesKeepsEachMatchOfALineInOrder() {
    let found = SourceLineScanner.matches(inSource: "ab\nc", file: "A.swift") { line in
      line.text.map { "\(line.number)\($0)" }
    }

    #expect(found == ["1a", "1b", "2c"])
  }

  @Test func usesGivesTheFileAndTheNumberOfALineThatHoldsThePattern() {
    let found = SourceLineScanner.matches(inSource: "first\nsecond", file: "A.swift") { line in
      SourceLineScanner.uses(of: Regex { "sec" }, on: line)
    }

    #expect(found == ["A.swift:2"])
  }

  @Test func matchesNamesEachFileRelativeToTheBase() throws {
    let base = try Self.fixtures.deletingLastPathComponent()

    let files = try SourceLineScanner.matches(inSwiftFilesBelow: Self.fixtures, relativeTo: base) { line in
      line.number == 1 ? [line.file] : []
    }

    #expect(files.sorted() == ["Violating/ImportsNothingForbidden.swift", "Violating/Nested/ImportsRuntimes.swift"])
  }

  /// The fixture directory with the comments and the string literals of the
  /// fixed color scan.
  static var literalFixtures: URL {
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/ThemeColors/Clean") }
  }

  @Test func codeMatchesSkipsTheCommentsAndTheStringLiterals() throws {
    let found = try SourceLineScanner.codeMatches(inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures) { line in
      line.text.contains("Color.") || line.text.contains("Color(") ? [line.number] : []
    }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func codeMatchesKeepsTheLineNumbersOfTheCode() throws {
    let found = try SourceLineScanner.codeMatches(inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures) { line in
      line.text.contains("editorTheme.selection") ? ["\(line.file):\(line.number)"] : []
    }

    #expect(found == ["ThemeColors.swift:20"])
  }

  @Test func codeMatchesSkipsTheSkippedFiles() throws {
    let found = try SourceLineScanner.codeMatches(
      inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures, skipping: ["ThemeColors.swift"]
    ) { [$0.number] }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func matchStartLinesGivesTheLineWhereEachMatchStarts() {
    let pattern = Regex {
      "start"
      OneOrMore(.whitespace)
      "end"
    }

    let lines = SourceLineScanner.matchStartLines(of: pattern, in: "first\nstart\n  end\nstart end")

    #expect(lines == [2, 4])
  }

  @Test func codeMatchStartsSkipsTheCommentsAndTheStringLiterals() throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: Regex { "NSColor" }, inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures)

    #expect(found.isEmpty, "\(found)")
  }

  @Test func codeMatchStartsNamesTheFileAndTheLineOfEachMatch() throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: Regex { "editorTheme.selection" }, inSwiftFilesBelow: Self.literalFixtures,
      relativeTo: Self.literalFixtures)

    #expect(found == ["ThemeColors.swift:20"])
  }

  @Test func codeMatchStartsSkipsTheSkippedFiles() throws {
    let unskipped = try SourceLineScanner.codeMatchStarts(
      of: Regex { "editorTheme" }, inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures)
    let found = try SourceLineScanner.codeMatchStarts(
      of: Regex { "editorTheme" }, inSwiftFilesBelow: Self.literalFixtures, relativeTo: Self.literalFixtures,
      skipping: ["ThemeColors.swift"])

    #expect(!unskipped.isEmpty)
    #expect(found.isEmpty, "\(found)")
  }

  @Test func matchesFailsOnADirectoryThatDoesNotExist() throws {
    let missing = try Self.fixtures.appending(path: "NoSuchDirectory")

    #expect(throws: CocoaError.self) {
      try SourceLineScanner.matches(inSwiftFilesBelow: missing, relativeTo: missing) { [$0] }
    }
  }
}
