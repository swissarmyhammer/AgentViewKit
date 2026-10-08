import Foundation
import FoundationModelsACP
import OSLog

/// The members that the kit reads on an ACP JSON value.
///
/// The views and the elicitation form read the ACP `JSONValue` directly. The
/// kit has no JSON type of its own. These members parse, encode and read the
/// ACP value.
nonisolated extension FoundationModelsACP.JSONValue {
  // MARK: - Parsing and encoding

  /// Parses JSON text.
  ///
  /// The text can be one scalar, for example `true` or `"text"`.
  ///
  /// - Parameter json: The JSON text.
  /// - Throws: `DecodingError` when the text is not valid JSON.
  public init(json: String) throws {
    self = try JSONDecoder().decode(Self.self, from: Data(json.utf8))
  }

  /// The JSON form of an encodable value.
  ///
  /// - Parameter value: The value to encode.
  /// - Throws: `EncodingError` when the value does not encode.
  public init(encoding value: some Encodable) throws {
    let data = try JSONEncoder().encode(value)
    self = try JSONDecoder().decode(Self.self, from: data)
  }

  /// The JSON form of an encodable value, or `null` when the value does not
  /// encode.
  ///
  /// The elicitation form reads the requested schema through this value. The
  /// log records each failure.
  ///
  /// - Parameter value: The value to encode.
  /// - Returns: The JSON value, or `null`.
  static func encodedOrNull(_ value: some Encodable) -> Self {
    do {
      return try Self(encoding: value)
    } catch {
      membersLogger.error("A value does not encode as JSON: \(String(describing: error), privacy: .public)")
      return .null
    }
  }

  /// The log of ``encodedOrNull(_:)``.
  private static let membersLogger = Logger(subsystem: "AgentViewKit", category: "JSONValue")

  // MARK: - Subscripts

  /// The member of an object for `key`.
  ///
  /// - Parameter key: The member name.
  /// - Returns: The member, or `nil` when the value is not an object or has no
  ///   member for `key`. A member that is JSON `null` returns `null`.
  public subscript(key: String) -> Self? {
    guard case .object(let members) = self else { return nil }
    return members[key]
  }

  /// The element of an array at `index`.
  ///
  /// - Parameter index: The position of the element, from zero.
  /// - Returns: The element, or `nil` when the value is not an array or
  ///   `index` is out of bounds.
  public subscript(index: Int) -> Self? {
    guard case .array(let elements) = self, elements.indices.contains(index) else { return nil }
    return elements[index]
  }

  // MARK: - Scalar readers

  /// The value of a `bool`, or `nil` for each other case.
  public var boolValue: Bool? {
    guard case .bool(let value) = self else { return nil }
    return value
  }

  /// The value of a `number`, or `nil` for each other case.
  public var doubleValue: Double? {
    guard case .number(let value) = self else { return nil }
    return value
  }

  /// The value of a `number` as an `Int`.
  ///
  /// The value is `nil` for each other case, and for a number that has a
  /// fraction, that is not finite, or that is out of the `Int` range.
  public var intValue: Int? {
    guard case .number(let value) = self else { return nil }
    return Int(exactly: value)
  }

  /// The value of a `string`, or `nil` for each other case.
  public var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }
}
