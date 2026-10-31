import AgentViewKitStyle
import AppKit
import Testing

/// Checks the public shared symbol table: the names that the view kits read,
/// each a symbol of the system, and none a clock symbol.
@Suite @MainActor struct SharedSymbolTests {
  /// The names that KanbanViewKit and SnapshotViewKit read from the table.
  static let sharedNames = [
    SharedSymbol.error, SharedSymbol.warning, SharedSymbol.information, SharedSymbol.reload,
    SharedSymbol.dismiss, SharedSymbol.edit, SharedSymbol.delete, SharedSymbol.move, SharedSymbol.link,
    SharedSymbol.binary, SharedSymbol.document, SharedSymbol.closed, SharedSymbol.disclosure,
  ]

  /// The tool-kind and file-operation names.
  static let toolAndFileNames = [
    SharedSymbol.read, SharedSymbol.search, SharedSymbol.terminal, SharedSymbol.reasoning, SharedSymbol.web,
    SharedSymbol.switchMode, SharedSymbol.tool, SharedSymbol.addedFile, SharedSymbol.deletedFile,
    SharedSymbol.modifiedFile, SharedSymbol.renamedFile, SharedSymbol.copiedFile,
  ]

  /// Each name of the table.
  static var allNames: [String] { sharedNames + toolAndFileNames }

  /// The names of the clock symbols, which only a scheduled task shows
  /// (EditorKit `style.md`).
  static let clockNames: Set<String> = ["clock", "timer", "alarm"]

  /// The start of the name of each other clock symbol.
  static let clockPrefix = "clock."

  @Test func eachNameShowsASymbolOfTheSystem() {
    let missing = Self.allNames.filter { NSImage(systemSymbolName: $0, accessibilityDescription: nil) == nil }

    #expect(missing.isEmpty, "\(missing)")
  }

  @Test func noNameIsAClockSymbol() {
    let clocks = Self.allNames.filter { Self.clockNames.contains($0) || $0.hasPrefix(Self.clockPrefix) }

    #expect(clocks.isEmpty, "\(clocks)")
  }

  @Test func eachConceptHasItsOwnSymbol() {
    #expect(Set(Self.allNames).count == Self.allNames.count)
  }
}
