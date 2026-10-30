import EditorTestSupport
import Foundation
import Testing

/// One SF Symbol name in a Swift file.
struct SymbolNameUse: Equatable, CustomStringConvertible {
  /// The file, relative to the package root.
  let file: String
  /// The line of the name. The first line is line 1.
  let line: Int
  /// The symbol name.
  let name: String

  var description: String { "\(file):\(line): \(name)" }
}

/// Holds each SF Symbol name of the two libraries in the shared symbol table.
///
/// EditorKit's `SymbolNameScanner` (``StyleRuleEngineTests``) holds each name
/// of the kit and of the examples to a current, unrestricted name of macOS 27.
/// This suite holds the place of the names: the kit and its style library
/// write each name in the symbol table and read it from there. The names come
/// from the same scan, and the names that show a symbol come from the
/// CoreGlyphs tables of the Mac (`SymbolCatalog.system()`).
@Suite struct SymbolNameTests {
  /// The file of the shared symbol table of the style library: the symbols
  /// that each view kit shows.
  static let styleSymbolFile = KitSourceFiles.styleFile("Symbols/SharedSymbol.swift")

  /// The file of the agent symbols of the kit: an extension of the shared
  /// symbol table.
  static let agentSymbolFile = KitSourceFiles.kitFile("Items/SharedSymbol+Agent.swift")

  /// The files of the symbol table. The two files together are the table:
  /// each symbol name of the two libraries is in one of them.
  static let symbolTableFiles = [styleSymbolFile, agentSymbolFile]

  /// The symbol names of one Swift text, as EditorKit's scan finds them.
  ///
  /// - Parameters:
  ///   - text: The text of the file.
  ///   - file: The file, relative to the package root.
  /// - Returns: The uses, in source order.
  /// - Throws: The error of the scan.
  static func names(in text: String, file: String) throws -> [SymbolNameUse] {
    try SymbolNameScanner.names(inSource: text).map { SymbolNameUse(file: file, line: $0.line, name: $0.name) }
  }

  /// The symbol names that the files of the symbol table write.
  ///
  /// - Returns: The uses, in the order of ``symbolTableFiles`` and in source
  ///   order.
  /// - Throws: The error when a file cannot be read.
  static func tableNames() throws -> [SymbolNameUse] {
    try symbolTableFiles.flatMap { path in try names(in: PackageFiles().text(of: path), file: path) }
  }

  /// The names that show a symbol on this Mac: each current name and each
  /// old name.
  ///
  /// - Returns: The names.
  /// - Throws: The error of `SymbolCatalog.system()`.
  static func availableNames() throws -> Set<String> {
    Set(try SymbolCatalog.system().years.keys)
  }

  /// The test compares only the names that show a system symbol. The scan
  /// also finds the other literals of a symbol type, such as the wire value
  /// and the labels of `ToolStatusSymbol`, and these are not in the lists of
  /// the system.
  @Test func eachSymbolNameOfTheKitIsWrittenOnlyInTheSymbolTable() throws {
    let availableNames = try Self.availableNames()
    let package = PackageFiles()
    let libraryNames = try KitSourceFiles.libraryPaths
      .flatMap { try package.swiftFileTexts(under: package.file($0)) }
      .flatMap { try Self.names(in: $0.text, file: $0.path) }
      .filter { availableNames.contains($0.name) }

    let outside = libraryNames.filter { !Self.symbolTableFiles.contains($0.file) }

    for file in Self.symbolTableFiles {
      #expect(libraryNames.contains { $0.file == file }, "\(file) writes no symbol name")
    }
    #expect(outside.isEmpty, "Add the name to SharedSymbol and read it from there: \(outside)")
  }

  @Test func theSymbolTableWritesEachNameOnce() throws {
    let names = try Self.tableNames().map(\.name)

    let repeated = Dictionary(grouping: names, by: \.self).filter { $0.value.count > 1 }.keys.sorted()

    #expect(!names.isEmpty)
    #expect(repeated.isEmpty, "Two constants of SharedSymbol have the same name: \(repeated)")
  }
}
