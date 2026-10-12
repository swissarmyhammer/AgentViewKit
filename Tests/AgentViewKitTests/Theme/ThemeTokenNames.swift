import SwiftUI

/// Changes the token names of the theme files into SwiftUI values.
///
/// `DefaultTokens.json` and the token table in
/// `Docs/decisions/visual-audit.md` name each weight. The theme tests use
/// this lookup for the two files.
enum ThemeTokenNames {
  /// The errors that the name lookup gives.
  enum LookupError: Error, Equatable {
    /// The file has a name that the lookup does not know.
    case unknownName(String)
  }

  /// The weights that a file can name.
  private static let weights: [String: Font.Weight] = [
    "light": .light,
    "regular": .regular,
    "medium": .medium,
    "semibold": .semibold,
    "bold": .bold,
  ]

  /// Gives the value that `name` names in `table`.
  ///
  /// - Parameters:
  ///   - name: A name from a file.
  ///   - table: The names that the lookup knows, with their values.
  /// - Returns: The value of `name`.
  /// - Throws: ``LookupError/unknownName(_:)`` for a name that is not known.
  private static func value<Value>(named name: String, in table: [String: Value]) throws -> Value {
    guard let value = table[name] else { throw LookupError.unknownName(name) }
    return value
  }

  /// The weight that `name` names.
  ///
  /// - Parameter name: A weight name from a file.
  /// - Returns: The font weight.
  /// - Throws: ``LookupError/unknownName(_:)`` for a name that is not known.
  static func weight(named name: String) throws -> Font.Weight {
    try value(named: name, in: weights)
  }
}
