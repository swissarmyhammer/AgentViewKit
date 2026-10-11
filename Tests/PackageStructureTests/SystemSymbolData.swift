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
    let data = try Data(contentsOf: resources.appending(path: name))
    let value = try PropertyListSerialization.propertyList(from: data, format: nil)
    guard let table = value as? [String: String] else {
      throw NotAStringTable(file: name)
    }
    return table
  }
}
