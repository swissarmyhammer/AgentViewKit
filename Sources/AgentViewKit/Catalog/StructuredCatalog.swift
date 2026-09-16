/// A registry from a `schemaName` to the payload type of that name
/// (plan.md §3.3, §11#5).
///
/// A source calls ``decode(schemaName:content:)`` for each structured
/// segment. A known name gives the typed payload. An unknown name gives `nil`,
/// and the source keeps the segment as a raw structured record.
/// `catalog.md`, in the same folder, lists each name of ``standard`` and the
/// fields of its payload.
public nonisolated struct StructuredCatalog: Sendable {
  /// A function that decodes the JSON body of one payload type.
  public typealias Decoder = @Sendable (JSONValue) throws -> any StructuredPayload

  /// The decoder of each registered name.
  private var decoders: [String: Decoder] = [:]

  /// The catalog with each payload type of the kit: approval, plan, citation,
  /// artifact, authorization, and usage.
  public static let standard = StructuredCatalog(payloadTypes: [
    ApprovalPayload.self,
    PlanPayload.self,
    CitationPayload.self,
    ArtifactPayload.self,
    AuthorizationPayload.self,
    UsagePayload.self,
  ])

  /// Makes a catalog that holds the given payload types.
  ///
  /// - Parameter payloadTypes: The payload types to register. When two types
  ///   have the same name, the last type wins.
  public init(payloadTypes: [any StructuredPayload.Type]) {
    for payloadType in payloadTypes {
      register(payloadType)
    }
  }

  /// The registered names, in sorted order.
  public var schemaNames: [String] {
    decoders.keys.sorted()
  }

  /// Registers a payload type under its ``StructuredPayload/schemaName``.
  ///
  /// A type with the name of a registered type replaces that type.
  ///
  /// - Parameter payloadType: The payload type to register.
  public mutating func register(_ payloadType: any StructuredPayload.Type) {
    decoders[payloadType.schemaName] = { content in
      try payloadType.init(content: content)
    }
  }

  /// Decodes the body of a structured segment.
  ///
  /// - Parameters:
  ///   - schemaName: The `schemaName` of the segment.
  ///   - content: The JSON body of the segment.
  /// - Returns: The typed payload, or `nil` when no type has `schemaName`.
  ///   An unknown name never throws.
  /// - Throws: `DecodingError` when the type of `schemaName` is known and
  ///   `content` is not a valid body of that type.
  public func decode(schemaName: String, content: JSONValue) throws -> (any StructuredPayload)? {
    guard let decoder = decoders[schemaName] else { return nil }
    return try decoder(content)
  }
}
