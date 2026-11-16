import Foundation

/// The style of a part of the status line, as text in the form of starship:
/// `bold cyan`, `dimmed secondary`, `bright_blue italic` (D194 (i)).
///
/// The words are in any order, with spaces between them:
///
/// - A color name (`black`, `red`, `green`, `yellow`, `blue`, `purple` or
///   `magenta`, `cyan`, `white`, and each with `bright_` in front) is an
///   entry of the `terminalPalette` of the EditorKit theme.
/// - A role (`primary`, `secondary`, `tertiary`, `accent`) is a color of the
///   theme.
/// - A modifier is `bold`, `italic` or `dimmed`.
///
/// A style has at most one color. The empty text is the plain style: the
/// primary color of the theme, with no modifier. A wrong word is a decode
/// error, so a wrong style in a setting is a problem with its key path
/// (``StatusLineSetting``).
nonisolated public struct StatusLineStyle: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
  /// A color of the style.
  public enum Color: Hashable, Sendable {
    /// An ANSI color: an entry of the terminal palette of the theme.
    case ansi(ANSIColor)
    /// A color role of the theme.
    case role(Role)
  }

  /// An ANSI color name. The raw value is the word of the style.
  public enum ANSIColor: String, CaseIterable, Hashable, Sendable {
    case black, red, green, yellow, blue, purple, magenta, cyan, white
    case brightBlack = "bright_black"
    case brightRed = "bright_red"
    case brightGreen = "bright_green"
    case brightYellow = "bright_yellow"
    case brightBlue = "bright_blue"
    case brightPurple = "bright_purple"
    case brightMagenta = "bright_magenta"
    case brightCyan = "bright_cyan"
    case brightWhite = "bright_white"
  }

  /// A color role of the theme. The raw value is the word of the style.
  public enum Role: String, CaseIterable, Hashable, Sendable {
    case primary, secondary, tertiary, accent
  }

  /// A modifier of the style. The raw value is the word of the style.
  public enum Modifier: String, CaseIterable, Hashable, Sendable {
    case bold, italic, dimmed
  }

  /// The error of a style text with a wrong word.
  public struct ParseError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The style text.
    public let text: String

    /// The wrong word.
    public let word: String

    public var description: String {
      "The style \"\(text)\" has the unknown word \"\(word)\". Use a color name, a role (primary, secondary, tertiary, accent) or a modifier (bold, italic, dimmed)."
    }
  }

  /// The color, or `nil` for the primary color of the theme.
  public var color: Color?

  /// The modifiers.
  public var modifiers: Set<Modifier>

  /// The plain style.
  public static let plain = StatusLineStyle(color: nil, modifiers: [])

  /// Makes a style.
  ///
  /// - Parameters:
  ///   - color: The color, or `nil` for the primary color of the theme.
  ///   - modifiers: The modifiers.
  public init(color: Color? = nil, modifiers: Set<Modifier> = []) {
    self.color = color
    self.modifiers = modifiers
  }

  /// Parses a style text.
  ///
  /// - Parameter text: The text, such as `bold cyan`.
  /// - Throws: ``ParseError`` for a word that is not a color, a role or a
  ///   modifier, or for a second color.
  public init(parsing text: String) throws {
    var color: Color?
    var modifiers: Set<Modifier> = []
    for word in text.split(whereSeparator: \.isWhitespace).map({ String($0).lowercased() }) {
      if let modifier = Modifier(rawValue: word) {
        modifiers.insert(modifier)
      } else if word == "dim" {
        modifiers.insert(.dimmed)
      } else if let next = ANSIColor(rawValue: word).map(Color.ansi) ?? Role(rawValue: word).map(Color.role) {
        guard color == nil else { throw ParseError(text: text, word: word) }
        color = next
      } else {
        throw ParseError(text: text, word: word)
      }
    }
    self.init(color: color, modifiers: modifiers)
  }

  /// Makes a style from a literal. A wrong literal is a programmer error.
  ///
  /// - Parameter value: The style text.
  public init(stringLiteral value: String) {
    do {
      try self.init(parsing: value)
    } catch {
      preconditionFailure("\(error)")
    }
  }

  /// The style as text, in the order color, then modifiers.
  public var text: String {
    let colorWord: String? =
      switch color {
      case .ansi(let ansi): ansi.rawValue
      case .role(let role): role.rawValue
      case nil: nil
      }
    let modifierWords = Modifier.allCases.filter(modifiers.contains).map(\.rawValue)
    return ([colorWord].compactMap { $0 } + modifierWords).joined(separator: " ")
  }

  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    let text = try container.decode(String.self)
    do {
      try self.init(parsing: text)
    } catch let error as ParseError {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: error.description)
    }
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}

/// A symbol of the status line: text, an SF Symbol, or an icon that the kit
/// bundles (D194 (i)).
///
/// In a setting, a symbol is text: `sf:<name>` names an SF Symbol,
/// `icon:<name>` names a bundled icon (the language icons,
/// ``StatusLineIcons``), and other text shows as it is.
nonisolated public enum StatusLineSymbol: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
  /// Text, such as `⎇ `.
  case text(String)
  /// An SF Symbol, by name.
  case sfSymbol(String)
  /// An icon that the kit bundles, by name, such as `swift`.
  case icon(String)

  /// The prefix of an SF Symbol in the text form.
  public static let sfPrefix = "sf:"

  /// The prefix of a bundled icon in the text form.
  public static let iconPrefix = "icon:"

  /// Makes a symbol from its text form.
  ///
  /// - Parameter text: The text form, such as `sf:folder` or `icon:swift`.
  public init(text: String) {
    if text.hasPrefix(Self.sfPrefix) {
      self = .sfSymbol(String(text.dropFirst(Self.sfPrefix.count)))
    } else if text.hasPrefix(Self.iconPrefix) {
      self = .icon(String(text.dropFirst(Self.iconPrefix.count)))
    } else {
      self = .text(text)
    }
  }

  public init(stringLiteral value: String) {
    self.init(text: value)
  }

  /// The text form of the symbol.
  public var text: String {
    switch self {
    case .text(let text): text
    case .sfSymbol(let name): Self.sfPrefix + name
    case .icon(let name): Self.iconPrefix + name
    }
  }

  /// `true` for empty text.
  public var isEmpty: Bool {
    if case .text(let text) = self { text.isEmpty } else { false }
  }

  public init(from decoder: any Decoder) throws {
    self.init(text: try decoder.singleValueContainer().decode(String.self))
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    try container.encode(text)
  }
}
