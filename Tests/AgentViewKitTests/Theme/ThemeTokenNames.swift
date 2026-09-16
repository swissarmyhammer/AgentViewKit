import SwiftUI

/// Changes the token names of the theme files into SwiftUI values.
///
/// `DefaultTokens.json` and the token table in
/// `Docs/decisions/visual-audit.md` name each color, weight, and font. The
/// theme tests use this lookup for the two files.
enum ThemeTokenNames {
  /// The errors that the name lookup gives.
  enum LookupError: Error, Equatable {
    /// The file has a name that the lookup does not know.
    case unknownName(String)
  }

  /// The colors that a file can name.
  private static let colors: [String: Color] = [
    "accentColor": .accentColor,
    "blue": .blue,
    "green": .green,
    "red": .red,
    "orange": .orange,
    "gray": .gray,
    "secondary": .secondary,
    "purple": .purple,
  ]

  /// The weights that a file can name.
  private static let weights: [String: Font.Weight] = [
    "light": .light,
    "regular": .regular,
    "medium": .medium,
    "semibold": .semibold,
    "bold": .bold,
  ]

  /// The text styles that a file can name.
  private static let textStyles: [String: Font.TextStyle] = [
    "body": .body,
    "callout": .callout,
    "footnote": .footnote,
    "caption": .caption,
  ]

  /// The font designs that a file can name.
  private static let designs: [String: Font.Design] = [
    "default": .default,
    "monospaced": .monospaced,
    "rounded": .rounded,
    "serif": .serif,
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

  /// The color that `name` names.
  ///
  /// - Parameter name: A color name from a file.
  /// - Returns: The SwiftUI color.
  /// - Throws: ``LookupError/unknownName(_:)`` for a name that is not known.
  static func color(named name: String) throws -> Color {
    try value(named: name, in: colors)
  }

  /// The weight that `name` names.
  ///
  /// - Parameter name: A weight name from a file.
  /// - Returns: The font weight.
  /// - Throws: ``LookupError/unknownName(_:)`` for a name that is not known.
  static func weight(named name: String) throws -> Font.Weight {
    try value(named: name, in: weights)
  }

  /// The system font with a named text style and a named design.
  ///
  /// - Parameters:
  ///   - textStyle: The name of the `Font.TextStyle`, such as `body`.
  ///   - design: The name of the `Font.Design`, such as `monospaced`.
  /// - Returns: The system font with the style and the design.
  /// - Throws: ``LookupError/unknownName(_:)`` for a name that is not known.
  static func font(textStyle: String, design: String) throws -> Font {
    .system(try value(named: textStyle, in: textStyles), design: try value(named: design, in: designs))
  }
}
