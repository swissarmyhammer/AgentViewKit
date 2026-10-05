import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// One use of a removed symbol in a Swift source file.
struct RemovedSymbolUse: Equatable, CustomStringConvertible {
  /// The file that holds the use, relative to the package root.
  let file: String
  /// The line number of the use. The first line is line 1.
  let line: Int
  /// The removed symbol.
  let symbol: String

  var description: String {
    "\(file):\(line) uses \(symbol)"
  }
}

/// Holds `Sources/` free of the symbols that the ACP client kit removed
/// (update.md §3, §6).
///
/// Each removal task adds its symbols to ``removedSymbols``. The scan reads
/// each Swift file as text, and finds a symbol only as a whole word. Thus
/// `addBranch` does not match `addBranches`.
@Suite struct RemovedVocabularyTests {
  /// The directory that the scan reads.
  static let sourcesPath = "Sources"

  /// The symbols that no file in `Sources/` can use.
  static let removedSymbols = [
    // Branches.
    "BranchNavigator", "addBranch", "selectBranch",
  ]

  /// Finds each use of a removed symbol in the text of one Swift file.
  ///
  /// - Parameters:
  ///   - symbols: The removed symbols.
  ///   - source: The text of the file.
  ///   - file: The name to write into each use.
  /// - Returns: The uses, in line order, and in symbol order on one line.
  static func uses(of symbols: [String], inSource source: String, file: String) -> [RemovedSymbolUse] {
    source.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
      .flatMap { offset, line in
        symbols
          .filter { line.contains(wholeWord($0)) }
          .map { RemovedSymbolUse(file: file, line: offset + 1, symbol: $0) }
      }
  }

  /// The pattern that matches a symbol only as a whole word.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Parameter symbol: The symbol.
  /// - Returns: The pattern.
  static func wholeWord(_ symbol: String) -> Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      symbol
      Anchor.wordBoundary
    }
  }

  @Test func usesFindsAWholeWordOnItsLine() {
    let source = "let a = 1\nthread.apply(.addBranch(afterUserMessage: id, items: []))"

    let found = Self.uses(of: ["addBranch"], inSource: source, file: "A.swift")

    #expect(found == [RemovedSymbolUse(file: "A.swift", line: 2, symbol: "addBranch")])
  }

  @Test func usesSkipsALongerWord() {
    let found = Self.uses(of: ["addBranch"], inSource: "addBranches(); preaddBranch()", file: "A.swift")

    #expect(found.isEmpty)
  }

  @Test func sourcesUseNoRemovedSymbol() throws {
    let root = PackageFiles.root.standardizedFileURL.pathComponents.count
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(Self.sourcesPath))

    let found = try files.flatMap { url in
      let relative = url.standardizedFileURL.pathComponents.dropFirst(root).joined(separator: "/")
      let text = try String(contentsOf: url, encoding: .utf8)
      return Self.uses(of: Self.removedSymbols, inSource: text, file: relative)
    }

    #expect(found.isEmpty, "\(found)")
  }
}
