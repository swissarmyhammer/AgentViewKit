import Foundation

/// A typed body of a custom structured segment (plan.md §3.3, §11#5).
///
/// A FoundationModels source carries custom content in a `.structure`
/// segment. The segment has a `schemaName` and a JSON body. A type that
/// conforms to this protocol is the typed form of one such body. The
/// ``StructuredCatalog`` maps a `schemaName` to the type.
///
/// The shape is the `Content` shape of the Router
/// `PersistableStructuredSegment`: `Codable`, `Sendable`, and `Equatable`. So
/// the Router adapter can persist each payload and read it back.
public nonisolated protocol StructuredPayload: Codable, Sendable, Equatable {
  /// The stable name that identifies the type in a transcript.
  ///
  /// The default is the full type name, such as
  /// `AgentViewKit.ApprovalPayload`. This is the convention of the Router
  /// `PersistableStructuredSegment`. `catalog.md` lists each name.
  static var schemaName: String { get }
}

nonisolated extension StructuredPayload {
  /// The full type name, such as `AgentViewKit.ApprovalPayload`.
  public static var schemaName: String { String(reflecting: Self.self) }

  /// Decodes a payload from a JSON value.
  ///
  /// - Parameter content: The JSON body of the segment.
  /// - Throws: `DecodingError` when `content` is not a valid body of this type.
  public init(content: JSONValue) throws {
    let data = try JSONEncoder().encode(content)
    self = try JSONDecoder().decode(Self.self, from: data)
  }

  /// The payload as a JSON value, for a `structured` content block.
  ///
  /// - Returns: The JSON body of the payload.
  /// - Throws: `EncodingError` when a value of the payload cannot be encoded.
  public func jsonValue() throws -> JSONValue {
    let data = try JSONEncoder().encode(self)
    return try JSONDecoder().decode(JSONValue.self, from: data)
  }

  /// Compares the payload with a payload of an unknown type.
  ///
  /// - Parameter other: The payload to compare with.
  /// - Returns: `true` when `other` has the same type and is equal.
  public func isEqual(to other: any StructuredPayload) -> Bool {
    guard let other = other as? Self else { return false }
    return self == other
  }
}
