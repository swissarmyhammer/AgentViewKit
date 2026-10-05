import Foundation
import PackageFileSupport
import Testing

/// The shared line scan of ``SourceLineScanner``.
@Suite struct SourceLineScannerTests {
  /// The fixture directory. It holds one Swift file at the top and one Swift
  /// file in a subdirectory.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ImportBoundary/Violating") }
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

  @Test func matchesNamesEachFileRelativeToTheBase() throws {
    let base = try Self.fixtures.deletingLastPathComponent()

    let files = try SourceLineScanner.matches(inSwiftFilesBelow: Self.fixtures, relativeTo: base) { line in
      line.number == 1 ? [line.file] : []
    }

    #expect(files.sorted() == ["Violating/ImportsNothingForbidden.swift", "Violating/Nested/ImportsRuntimes.swift"])
  }

  @Test func matchesFailsOnADirectoryThatDoesNotExist() throws {
    let missing = try Self.fixtures.appending(path: "NoSuchDirectory")

    #expect(throws: CocoaError.self) {
      try SourceLineScanner.matches(inSwiftFilesBelow: missing, relativeTo: missing) { [$0] }
    }
  }
}
