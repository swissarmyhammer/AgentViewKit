import EditorTestSupport
import Foundation
import Testing

/// Holds the SF Symbol names of the kit and of the examples current and free
/// of restrictions.
///
/// An old name still shows a symbol, because the system keeps it as an
/// alias of the current name. `NSImage(systemSymbolName:)` accepts an old
/// name, so a check that a symbol exists cannot find one. These tests read
/// the lists of the system (``SystemSymbolData``) at test time, and compare
/// each symbol name that ``SymbolNameScanner`` finds with them.
@Suite struct SymbolNameTests {
  /// The symbol names in the Swift files below ``KitSourceFiles/viewPaths``.
  ///
  /// - Returns: The uses, in directory order.
  /// - Throws: The error of the scan when a directory cannot be read.
  static func symbolNames() throws -> [SymbolNameUse] {
    try KitSourceFiles.scanViewFiles { directory in
      try SymbolNameScanner.names(inSwiftFilesBelow: directory, relativeTo: PackageFiles().root)
    }
  }

  /// Finds the symbol names of a source.
  ///
  /// - Parameter source: The text of a Swift file.
  /// - Returns: The names, in source order.
  static func names(in source: String) -> [String] {
    SymbolNameScanner(source: source).names(file: "A.swift").map(\.name)
  }

  // MARK: - The scan

  @Test func theScanFindsTheArgumentOfASymbolLabel() {
    let source = """
      Image(systemName: "mic")
      Button("Copy code", systemImage: "doc.on.doc") { copy() }
      Label(isOn ? "On" : "Off", systemImage: isOn ? "circle.fill" : "circle")
      StateBanner.Content(
        symbolName: "clock", text: "Waiting")
      """

    #expect(Self.names(in: source) == ["mic", "doc.on.doc", "circle.fill", "circle", "clock"])
  }

  @Test func theScanFindsTheLineOfEachName() {
    let source = "let a = 1\nImage(systemName: \"mic\")"

    let found = SymbolNameScanner(source: source).names(file: "A.swift")

    #expect(found == [SymbolNameUse(file: "A.swift", line: 2, name: "mic")])
  }

  @Test func theScanFindsTheValueOfASymbolDeclaration() {
    let source = """
      static let commandSymbol = "terminal"
      static let symbol = "hand.raised"
      public static let identifier = "terminal"
      let symbolName: String
      let title = "Title"
      """

    #expect(Self.names(in: source) == ["terminal", "hand.raised"])
  }

  @Test func theScanFindsTheBodyOfASymbolDeclaration() {
    let source = """
      enum ToolKindSymbol {
        static func name(for kind: Kind) -> String {
          switch kind {
          case .read: "doc.text"
          }
        }
      }
      var systemImage: String {
        switch self { case .copy: "doc.on.clipboard" }
      }
      static func symbolName(
        for state: State
      ) -> String { state.isOn ? "bolt.fill" : "bolt" }
      var kindName: String {
        switch self { case .terminal: "terminal" }
      }
      """

    #expect(Self.names(in: source) == ["doc.text", "doc.on.clipboard", "bolt.fill", "bolt"])
  }

  @Test func theScanFindsTheBodyOfAnExtensionOfASymbolType() {
    let source = """
      nonisolated extension SharedSymbol {
        static let userAction = "hand.raised.fill"
      }
      extension AgentViewKitStyle.SharedSymbol {
        static let refusal = "exclamationmark.bubble.fill"
      }
      extension SharedTable {
        static let title = "Title"
      }
      """

    #expect(Self.names(in: source) == ["hand.raised.fill", "exclamationmark.bubble.fill"])
  }

  @Test func theScanSkipsCommentsAndLiteralsWithAnEscape() {
    let source = """
      // Image(systemName: "doc")
      /* Label("A", systemImage: "mic") */
      static let symbol = "folder" // The "mic" symbol is old.
      Image(systemName: "\\(name).fill")
      """

    #expect(Self.names(in: source) == ["folder"])
  }

  @Test func theScanReadsBracketsInALiteralAsText() {
    let source = """
      enum ShareSymbol {
        static let title = "} https://a.b {"
        static let name = "square.and.arrow.up"
      }
      static let symbol = #"a "quote" "#
      Image(systemName: "folder")
      """

    #expect(Self.names(in: source) == [#"} https://a.b {"#, "square.and.arrow.up", #"a "quote" "#, "folder"])
  }

  @Test func theScanFindsTheSymbolNamesOfTheKit() throws {
    let names = try Self.symbolNames()

    #expect(names.contains { $0.file.hasPrefix(KitSourceFiles.kitFile("")) })
    #expect(names.contains { $0.file.hasPrefix(KitSourceFiles.styleFile("")) })
  }

  // MARK: - The system data

  @Test func theAliasesMapAnOldNameToItsCurrentName() throws {
    let aliases = try SystemSymbolData.aliases()

    #expect(aliases["doc.on.doc"] == "document.on.document")
  }

  @Test func theAvailableNamesHoldACurrentNameAndAnOldName() throws {
    let names = try SystemSymbolData.availableNames()

    #expect(names.contains("document.on.document"))
    #expect(names.contains("doc.on.doc"))
    #expect(!names.contains("Result lost"))
  }

  @Test func theRestrictionsHoldThePasskeySymbol() throws {
    let restrictions = try SystemSymbolData.restrictions()

    #expect(restrictions["person.badge.key"]?.contains("passkey") == true)
  }

  // MARK: - The names

  @Test func noSymbolNameIsAnOldName() throws {
    let aliases = try SystemSymbolData.aliases()

    let found = try Self.symbolNames().compactMap { use in
      aliases[use.name].map { "\(use) is an old name of \($0)" }
    }

    #expect(found.isEmpty, "\(found)")
  }

  @Test func noSymbolNameIsRestricted() throws {
    let restrictions = try SystemSymbolData.restrictions()

    let found = try Self.symbolNames().compactMap { use in
      restrictions[use.name].map { "\(use) is restricted: \($0)" }
    }

    #expect(found.isEmpty, "\(found)")
  }

  // MARK: - The symbol table

  /// The file of the shared symbol table of the style library: the symbols
  /// that each view kit shows.
  static let styleSymbolFile = KitSourceFiles.styleFile("Symbols/SharedSymbol.swift")

  /// The file of the agent symbols of the kit: an extension of the shared
  /// symbol table.
  static let agentSymbolFile = KitSourceFiles.kitFile("Items/SharedSymbol+Agent.swift")

  /// The files of the symbol table. The two files together are the table:
  /// each symbol name of the two libraries is in one of them.
  static let symbolTableFiles = [styleSymbolFile, agentSymbolFile]

  /// The symbol names that the files of the symbol table write.
  ///
  /// - Returns: The uses, in the order of ``symbolTableFiles`` and in source
  ///   order.
  /// - Throws: The error when a file cannot be read.
  static func tableNames() throws -> [SymbolNameUse] {
    try symbolTableFiles.flatMap { path in
      let tableFile = try PackageFiles().file(path)
      return SymbolNameScanner(source: try String(contentsOf: tableFile, encoding: .utf8))
        .names(file: path)
    }
  }

  /// The test compares only the names that show a system symbol. The scan
  /// also finds the other literals of a symbol type, such as the wire value
  /// and the labels of `ToolStatusSymbol`, and these are not in the lists of
  /// the system.
  @Test func eachSymbolNameOfTheKitIsWrittenOnlyInTheSymbolTable() throws {
    let availableNames = try SystemSymbolData.availableNames()
    let libraryNames = try KitSourceFiles.scanLibraryFiles { directory in
      try SymbolNameScanner.names(inSwiftFilesBelow: directory, relativeTo: PackageFiles().root)
    }.filter { availableNames.contains($0.name) }

    let outside = libraryNames.filter { !Self.symbolTableFiles.contains($0.file) }

    for file in Self.symbolTableFiles {
      #expect(libraryNames.contains { $0.file == file }, "\(file) writes no symbol name")
    }
    #expect(outside.isEmpty, "Add the name to SharedSymbol and read it from there: \(outside)")
  }

  @Test func eachNameOfTheSymbolTableShowsASymbol() throws {
    let availableNames = try SystemSymbolData.availableNames()

    let unknown = try Self.tableNames().filter { !availableNames.contains($0.name) }

    #expect(unknown.isEmpty, "\(unknown)")
  }

  @Test func theSymbolTableWritesEachNameOnce() throws {
    let names = try Self.tableNames().map(\.name)

    let repeated = Dictionary(grouping: names, by: \.self).filter { $0.value.count > 1 }.keys.sorted()

    #expect(!names.isEmpty)
    #expect(repeated.isEmpty, "Two constants of SharedSymbol have the same name: \(repeated)")
  }
}
