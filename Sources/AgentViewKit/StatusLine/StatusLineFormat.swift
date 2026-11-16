import Foundation

/// A format string of the status line, as the format of starship and of
/// `sah statusline` (D194 (e)).
///
/// - `$name` and `${name}` are references. In the format of the line, a
///   reference names a module, such as `$directory`. In the format of a
///   module, a reference names a value of the module, such as `$branch`.
/// - Other text is literal. `\$`, `\(`, `\)` and `\\` are the literal
///   characters.
/// - A group `( … )` shows only when a reference in it has a value. A group
///   can hold groups.
///
/// The text form is the Codable form, so a format in a setting is a string.
/// A wrong format, such as a group with no end, is a decode error.
nonisolated public struct StatusLineFormat: Hashable, Sendable, Codable, ExpressibleByStringLiteral {
  /// One part of a parsed format.
  public enum Node: Hashable, Sendable {
    /// Literal text.
    case literal(String)
    /// A reference, by name.
    case reference(String)
    /// A group that shows only when a reference in it has a value.
    case group([Node])
  }

  /// One part of the output of ``render(_:)``.
  public enum Output<Value> {
    /// Literal text.
    case literal(String)
    /// The value of a reference.
    case value(Value)
  }

  /// The error of a wrong format.
  public struct ParseError: Error, Equatable, Sendable, CustomStringConvertible {
    /// The format text.
    public let text: String

    /// What is wrong.
    public let message: String

    public var description: String {
      "The format \"\(text)\" is not valid: \(message)."
    }
  }

  /// The text of the format.
  public let text: String

  /// The parsed parts of the format.
  public let nodes: [Node]

  /// Parses a format.
  ///
  /// - Parameter text: The format text, such as `$directory $git_branch`.
  /// - Throws: ``ParseError`` for a group with no end, an end with no group,
  ///   a `${` with no `}`, or a `\` at the end.
  public init(parsing text: String) throws {
    var parser = Parser(text: text)
    self.text = text
    self.nodes = try parser.parse()
  }

  /// Makes a format from a literal. A wrong literal is a programmer error.
  ///
  /// - Parameter value: The format text.
  public init(stringLiteral value: String) {
    do {
      try self.init(parsing: value)
    } catch {
      preconditionFailure("\(error)")
    }
  }

  /// The names of the references of the format, in each group too.
  public var references: Set<String> {
    Self.references(in: nodes)
  }

  /// Tells if a reference with no value is in the format: a check of the
  /// names against the names that a module knows.
  ///
  /// - Parameter known: The names that the format can use.
  /// - Throws: ``ParseError`` that names the first unknown reference.
  public func validate(references known: Set<String>) throws {
    if let unknown = references.subtracting(known).sorted().first {
      throw ParseError(
        text: text,
        message: "it has the unknown reference $\(unknown); use one of \(known.sorted().map { "$" + $0 }.joined(separator: ", "))")
    }
  }

  /// Renders the format.
  ///
  /// A group with no reference that has a value shows nothing. The output
  /// keeps each literal as it is: ``normalized(_:)`` removes the spaces that
  /// a missing value leaves.
  ///
  /// - Parameter value: The value of a reference, or `nil` when the
  ///   reference has no value.
  /// - Returns: The parts of the output, in order.
  public func render<Value>(_ value: (String) -> Value?) -> [Output<Value>] {
    Self.render(nodes, value: value).output
  }

  /// Removes the spaces that missing values leave: adjacent literals join,
  /// each run of spaces in a literal becomes one space, and the output has no
  /// space at its start or its end.
  ///
  /// - Parameter output: The output of ``render(_:)``.
  /// - Returns: The output with no double space.
  public static func normalized<Value>(_ output: [Output<Value>]) -> [Output<Value>] {
    var joined: [Output<Value>] = []
    for part in output {
      if case .literal(let next) = part, let last = joined.last, case .literal(let previous) = last {
        joined[joined.count - 1] = .literal(previous + next)
      } else {
        joined.append(part)
      }
    }
    var result: [Output<Value>] = joined.map { part in
      guard case .literal(let text) = part else { return part }
      return .literal(collapsedSpaces(text))
    }
    if let first = result.first, case .literal(let text) = first {
      result[0] = .literal(String(text.drop { $0 == " " }))
    }
    if let last = result.last, case .literal(let text) = last {
      result[result.count - 1] = .literal(String(text.reversed().drop { $0 == " " }.reversed()))
    }
    return result.filter { part in
      if case .literal(let text) = part { !text.isEmpty } else { true }
    }
  }

  /// Renders the format to text, with the normalized spaces.
  ///
  /// - Parameter value: The text of a reference, or `nil` or the empty text
  ///   when the reference has no value.
  /// - Returns: The text.
  public func renderText(_ value: (String) -> String?) -> String {
    let output = Self.normalized(render { name in value(name).flatMap { $0.isEmpty ? nil : $0 } })
    return output.map { part in
      switch part {
      case .literal(let text): text
      case .value(let text): text
      }
    }.joined()
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

  public static func == (lhs: StatusLineFormat, rhs: StatusLineFormat) -> Bool {
    lhs.text == rhs.text
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(text)
  }

  // MARK: - Private

  private static func references(in nodes: [Node]) -> Set<String> {
    nodes.reduce(into: Set<String>()) { names, node in
      switch node {
      case .literal: break
      case .reference(let name): names.insert(name)
      case .group(let children): names.formUnion(references(in: children))
      }
    }
  }

  private static func render<Value>(_ nodes: [Node], value: (String) -> Value?) -> (
    output: [Output<Value>], hasValue: Bool
  ) {
    var output: [Output<Value>] = []
    var hasValue = false
    for node in nodes {
      switch node {
      case .literal(let text):
        output.append(.literal(text))
      case .reference(let name):
        if let found = value(name) {
          output.append(.value(found))
          hasValue = true
        }
      case .group(let children):
        let group = render(children, value: value)
        if group.hasValue {
          output.append(contentsOf: group.output)
          hasValue = true
        }
      }
    }
    return (output, hasValue)
  }

  private static func collapsedSpaces(_ text: String) -> String {
    var result = ""
    var previousIsSpace = false
    for character in text {
      let isSpace = character == " "
      if !(isSpace && previousIsSpace) { result.append(character) }
      previousIsSpace = isSpace
    }
    return result
  }

  /// The parser of the format text.
  private struct Parser {
    let text: String
    var index: String.Index

    init(text: String) {
      self.text = text
      self.index = text.startIndex
    }

    mutating func parse() throws -> [Node] {
      let nodes = try parseNodes(inGroup: false)
      return nodes
    }

    private mutating func parseNodes(inGroup: Bool) throws -> [Node] {
      var nodes: [Node] = []
      var literal = ""
      func flush() {
        if !literal.isEmpty {
          nodes.append(.literal(literal))
          literal = ""
        }
      }
      while index < text.endIndex {
        let character = text[index]
        switch character {
        case "\\":
          let next = text.index(after: index)
          guard next < text.endIndex else { throw error("it ends with \\") }
          literal.append(text[next])
          index = text.index(after: next)
        case "$":
          if let name = try parseReference() {
            flush()
            nodes.append(.reference(name))
          } else {
            literal.append("$")
          }
        case "(":
          flush()
          index = text.index(after: index)
          nodes.append(.group(try parseNodes(inGroup: true)))
        case ")":
          guard inGroup else { throw error("it has a ) with no (") }
          flush()
          index = text.index(after: index)
          return nodes
        default:
          literal.append(character)
          index = text.index(after: index)
        }
      }
      if inGroup { throw error("it has a ( with no )") }
      flush()
      return nodes
    }

    /// Reads a reference at `$`. Returns `nil`, and reads only the `$`, when
    /// no name follows it.
    private mutating func parseReference() throws -> String? {
      var cursor = text.index(after: index)
      if cursor < text.endIndex, text[cursor] == "{" {
        cursor = text.index(after: cursor)
        let start = cursor
        while cursor < text.endIndex, text[cursor] != "}" { cursor = text.index(after: cursor) }
        guard cursor < text.endIndex else { throw error("it has a ${ with no }") }
        let name = String(text[start..<cursor])
        guard !name.isEmpty, name.allSatisfy(Self.isNameCharacter) else {
          throw error("${\(name)} is not a name")
        }
        index = text.index(after: cursor)
        return name
      }
      let start = cursor
      while cursor < text.endIndex, Self.isNameCharacter(text[cursor]) { cursor = text.index(after: cursor) }
      guard cursor > start else {
        index = text.index(after: index)
        return nil
      }
      index = cursor
      return String(text[start..<cursor])
    }

    private static func isNameCharacter(_ character: Character) -> Bool {
      character == "_" || (character.isASCII && (character.isLetter || character.isNumber))
    }

    private func error(_ message: String) -> ParseError {
      ParseError(text: text, message: message)
    }
  }
}
