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
    // Checkpoints.
    "CheckpointCapabilities", "CheckpointView", "setCheckpoints",
    // Subagents.
    "SubagentRun", "SubagentSource", "SubagentTreeView", "upsertSubagent",
    // Compaction markers.
    "CompactionMarker", "CompactionMarkerView", "compactionView", "compactionViewOverride",
    // The system prompt item.
    "SystemPrompt", "SystemPromptView", "systemPromptView", "systemPromptViewOverride",
  ]

  /// Finds each use of a removed symbol on one line of a Swift file.
  ///
  /// - Parameters:
  ///   - symbols: The removed symbols.
  ///   - line: The line.
  /// - Returns: The uses, in symbol order.
  static func uses(of symbols: [String], on line: SourceLine) -> [RemovedSymbolUse] {
    symbols
      .filter { line.text.contains(wholeWord($0)) }
      .map { RemovedSymbolUse(file: line.file, line: line.number, symbol: $0) }
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

    let found = SourceLineScanner.matches(inSource: source, file: "A.swift") { line in
      Self.uses(of: ["addBranch"], on: line)
    }

    #expect(found == [RemovedSymbolUse(file: "A.swift", line: 2, symbol: "addBranch")])
  }

  @Test func usesSkipsALongerWord() {
    let line = SourceLine(file: "A.swift", number: 1, text: "addBranches(); preaddBranch()")

    let found = Self.uses(of: ["addBranch"], on: line)

    #expect(found.isEmpty)
  }

  @Test func sourcesUseNoRemovedSymbol() throws {
    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(Self.sourcesPath),
      relativeTo: PackageFiles.root
    ) { line in
      Self.uses(of: Self.removedSymbols, on: line)
    }

    #expect(found.isEmpty, "\(found)")
  }
}
