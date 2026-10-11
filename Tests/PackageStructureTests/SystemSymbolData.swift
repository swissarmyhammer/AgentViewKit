import Foundation

/// Reads the SF Symbols data of the operating system.
///
/// The data is in `CoreGlyphs.bundle`, the bundle that holds the system
/// symbols. Each file is a binary property list of names. The tests read the
/// files at test time, so that the lists follow the system that runs the
/// tests. CI runs on the self-hosted macOS 27 runner, which has the same
/// bundle.
enum SystemSymbolData {
  /// The error when a data file is not a table of strings.
  struct NotAStringTable: Error, Equatable {
    /// The name of the data file.
    let file: String
  }

  /// The directory of the data files.
  static let resources = URL(filePath: "/System/Library/CoreServices/CoreGlyphs.bundle/Contents/Resources")

  /// The file of the old names. An old name still shows a symbol, but only
  /// as an alias of a current name.
  static let aliasesFile = "name_aliases.strings"

  /// The file of the restricted names. A restricted symbol can only refer
  /// to one Apple product or feature.
  static let restrictionsFile = "symbol_restrictions.strings"

  /// The file of the names that show a symbol. Its `symbols` table holds each
  /// current name and each old name, with the release that added the name as
  /// the value.
  static let availabilityFile = "name_availability.plist"

  /// The key of the table of the names in ``availabilityFile``.
  static let symbolsKey = "symbols"

  /// The error when the availability file has no table of names.
  struct NoNameTable: Error, Equatable {
    /// The name of the data file.
    let file: String
  }

  /// The names that show a symbol: each current name and each old name.
  ///
  /// - Returns: The names.
  /// - Throws: The error of the read when the file cannot be read, or
  ///   ``NoNameTable`` when the file has no `symbols` table.
  static func availableNames() throws -> Set<String> {
    let value = try propertyList(named: availabilityFile)
    guard let symbols = (value as? [String: Any])?[symbolsKey] as? [String: Any] else {
      throw NoNameTable(file: availabilityFile)
    }
    return Set(symbols.keys)
  }

  /// The old names.
  ///
  /// - Returns: Each old name, with its current name as the value.
  /// - Throws: The error of the read when the file cannot be read, or
  ///   ``NotAStringTable`` when the file is not a table of strings.
  static func aliases() throws -> [String: String] {
    try table(named: aliasesFile)
  }

  /// The restricted names.
  ///
  /// - Returns: Each restricted name, with the text of its restriction as
  ///   the value.
  /// - Throws: The error of the read when the file cannot be read, or
  ///   ``NotAStringTable`` when the file is not a table of strings.
  static func restrictions() throws -> [String: String] {
    try table(named: restrictionsFile)
  }

  /// Reads one data file as a table of strings.
  ///
  /// - Parameter name: The file name in ``resources``.
  /// - Returns: The table.
  /// - Throws: The error of the read when the file cannot be read, or
  ///   ``NotAStringTable`` when the file is not a table of strings.
  private static func table(named name: String) throws -> [String: String] {
    guard let table = try propertyList(named: name) as? [String: String] else {
      throw NotAStringTable(file: name)
    }
    return table
  }

  /// Reads one data file and decodes it as a property list.
  ///
  /// Each read of a data file goes through this function, so that all the
  /// reads use the same file location and the same decoder. The caller
  /// checks the shape of the value.
  ///
  /// - Parameter name: The file name in ``resources``.
  /// - Returns: The decoded property list.
  /// - Throws: The error of the read when the file cannot be read or is not
  ///   a property list.
  private static func propertyList(named name: String) throws -> Any {
    let data = try Data(contentsOf: resources.appending(path: name))
    return try PropertyListSerialization.propertyList(from: data, format: nil)
  }
}
