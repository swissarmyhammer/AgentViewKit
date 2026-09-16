import Foundation

/// A JSON value that the core target owns (plan.md §3.2, §11#1).
///
/// The core target must not import the ACP wire package or FoundationModels.
/// So `_meta` fields, `structured` content blocks, and elicitation answers use
/// this type. The adapter targets convert their JSON types to and from it.
///
/// Equality and hashing use the `Dictionary` of an object, so the order of the
/// keys in the source text is not significant.
public nonisolated enum JSONValue: Sendable, Hashable, Codable {
  /// The JSON `null` literal.
  case null
  /// A JSON `true` or `false`.
  case bool(Bool)
  /// A JSON number.
  case number(Double)
  /// A JSON string.
  case string(String)
  /// A JSON array.
  case array([JSONValue])
  /// A JSON object.
  case object([String: JSONValue])

  // MARK: - Codable

  /// Decodes a value from one JSON value of the decoder.
  ///
  /// The decoder tries the cases in this order: `null`, `Bool`, `Double`,
  /// `String`, array, object.
  ///
  /// - Parameter decoder: The decoder to read from.
  /// - Throws: `DecodingError.typeMismatch` when the value is not JSON.
  public init(from decoder: any Decoder) throws {
    let container = try decoder.singleValueContainer()
    if container.decodeNil() {
      self = .null
    } else if let value = try? container.decode(Bool.self) {
      self = .bool(value)
    } else if let value = try? container.decode(Double.self) {
      self = .number(value)
    } else if let value = try? container.decode(String.self) {
      self = .string(value)
    } else if let value = try? container.decode([JSONValue].self) {
      self = .array(value)
    } else if let value = try? container.decode([String: JSONValue].self) {
      self = .object(value)
    } else {
      throw DecodingError.typeMismatch(
        JSONValue.self,
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "The value is not a JSON null, bool, number, string, array, or object."
        )
      )
    }
  }

  /// Encodes the value as one JSON value of the encoder.
  ///
  /// - Parameter encoder: The encoder to write to.
  /// - Throws: The error of the encoder. `JSONEncoder` throws for a number
  ///   that is not finite. ``jsonString`` and ``prettyPrinted`` write such a
  ///   number as `null` and do not throw.
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .bool(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .string(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }

  // MARK: - Parsing

  /// Parses JSON text.
  ///
  /// The text can be one scalar, for example `true` or `"text"`.
  ///
  /// - Parameter json: The JSON text.
  /// - Throws: `DecodingError` when the text is not valid JSON.
  public init(json: String) throws {
    self = try JSONDecoder().decode(JSONValue.self, from: Data(json.utf8))
  }

  // MARK: - Subscripts

  /// The member of an object for `key`.
  ///
  /// - Parameter key: The member name.
  /// - Returns: The member, or `nil` when the value is not an object or has no
  ///   member for `key`. A member that is JSON `null` returns ``null``.
  public subscript(key: String) -> JSONValue? {
    guard case .object(let members) = self else { return nil }
    return members[key]
  }

  /// The element of an array at `index`.
  ///
  /// - Parameter index: The position of the element, from zero.
  /// - Returns: The element, or `nil` when the value is not an array or
  ///   `index` is out of bounds.
  public subscript(index: Int) -> JSONValue? {
    guard case .array(let elements) = self, elements.indices.contains(index) else { return nil }
    return elements[index]
  }

  // MARK: - Conversions

  /// The value of a ``bool(_:)``, or `nil` for each other case.
  public var boolValue: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  /// The value of a ``number(_:)``, or `nil` for each other case.
  public var doubleValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }

  /// The value of a ``number(_:)`` as an `Int`.
  ///
  /// The value is `nil` for each other case, and for a number that has a
  /// fraction, that is not finite, or that is out of the `Int` range.
  public var intValue: Int? {
    guard case .number(let value) = self else { return nil }
    return Int(exactly: value)
  }

  /// The value of a ``string(_:)``, or `nil` for each other case.
  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  // MARK: - Printing

  /// The compact JSON text of the value, with sorted object keys.
  ///
  /// The output has no whitespace and does not escape `/`. A number that is
  /// not finite prints as `null`, because JSON has no literal for it.
  public var jsonString: String {
    Self.encodedText(of: self, formatting: [.sortedKeys, .withoutEscapingSlashes])
  }

  /// The indented JSON text of the value, with sorted object keys.
  ///
  /// The output is the same for equal values, so a view or a snapshot test
  /// can show it. A number that is not finite prints as `null`.
  public var prettyPrinted: String {
    Self.encodedText(of: self, formatting: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
  }

  /// Encodes `value` to JSON text.
  ///
  /// - Parameters:
  ///   - value: The value to encode.
  ///   - formatting: The output format.
  /// - Returns: The JSON text.
  private static func encodedText(
    of value: JSONValue,
    formatting: JSONEncoder.OutputFormatting
  ) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = formatting
    // After `finite`, each number is finite. `JSONEncoder` throws only for a
    // number that is not finite, so this encode cannot fail.
    guard let data = try? encoder.encode(value.finite) else {
      preconditionFailure("JSONEncoder failed on a JSONValue with finite numbers.")
    }
    return String(decoding: data, as: UTF8.self)
  }

  /// A copy of the value in which each number that is not finite is ``null``.
  private var finite: JSONValue {
    switch self {
    case .number(let value) where !value.isFinite:
      return .null
    case .null, .bool, .number, .string:
      return self
    case .array(let elements):
      return .array(elements.map(\.finite))
    case .object(let members):
      return .object(members.mapValues(\.finite))
    }
  }
}
