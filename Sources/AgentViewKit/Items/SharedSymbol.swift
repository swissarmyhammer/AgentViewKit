import Foundation

/// The SF Symbols that more than one view of the kit shows.
///
/// Each view that shows one of these symbols reads the name from here, so
/// all such views change together. A symbol name is written in this file
/// only. The package test `SymbolNameTests` makes sure that no other source
/// file writes one of these names again.
nonisolated enum SharedSymbol {
  /// The symbol of a terminal or a shell command: the `execute` tool kind,
  /// a terminal, a command output row and a command in a permission request.
  static let terminal = "apple.terminal"

  /// The symbol of a button that copies text to the pasteboard.
  static let copy = "document.on.document"
}
