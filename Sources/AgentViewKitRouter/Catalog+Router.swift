import AgentViewKit
import Foundation
import FoundationModels

/// A typed value that a Router transcript carries as a
/// `Transcript.StructuredSegment` (plan.md §3.3, §11#5).
///
/// This protocol has the shape of the FoundationModelsRouter protocol with
/// the same name. The Router protocol is internal to the Router module, so an
/// adapter cannot conform to it. The Router records each structured segment
/// by its `schemaName`, its `id`, and its JSON body, and restores the same
/// segment. So a segment that this protocol makes persists and restores
/// through the Router with no Router change.
public nonisolated protocol PersistableStructuredSegment: Sendable {
  /// The typed body of the segment, persisted as JSON.
  associatedtype Content: Codable & Sendable & Equatable

  /// The stable name that identifies the type in a transcript.
  static var schemaName: String { get }

  /// The id of the segment.
  var id: String { get }

  /// The typed body.
  var content: Content { get }

  /// Makes a segment from its persisted id and its decoded body.
  ///
  /// - Parameters:
  ///   - id: The id of the segment.
  ///   - content: The typed body.
  /// - Throws: An error when `content` cannot make a valid segment.
  init(id: String, content: Content) throws
}

nonisolated extension PersistableStructuredSegment {
  /// The value as the SDK structured segment that carries it.
  ///
  /// - Throws: `EncodingError` when the body does not encode, and the error
  ///   of `GeneratedContent(json:)` when the JSON does not parse.
  public func structuredSegment() throws -> Transcript.StructuredSegment {
    let data = try JSONEncoder().encode(content)
    let json = String(decoding: data, as: UTF8.self)
    return Transcript.StructuredSegment(
      id: id,
      schemaName: Self.schemaName,
      content: try GeneratedContent(json: json)
    )
  }

  /// Makes the value from an SDK structured segment.
  ///
  /// - Parameter structuredSegment: The segment from a transcript.
  /// - Returns: `nil` when the segment has the `schemaName` of another type.
  /// - Throws: `DecodingError` when the body does not decode.
  public init?(structuredSegment: Transcript.StructuredSegment) throws {
    guard structuredSegment.schemaName == Self.schemaName else { return nil }
    let data = Data(structuredSegment.content.jsonString.utf8)
    try self.init(id: structuredSegment.id, content: JSONDecoder().decode(Content.self, from: data))
  }
}

/// A catalog payload in a Router structured segment.
///
/// The `schemaName` of the segment is the ``StructuredPayload/schemaName`` of
/// the payload, the name in `catalog.md`. So the Router persists and restores
/// each catalog payload under its catalog name.
public nonisolated struct CatalogSegment<Payload: StructuredPayload>: PersistableStructuredSegment, Equatable
{
  /// The catalog name of the payload.
  public static var schemaName: String { Payload.schemaName }

  /// The id of the segment.
  public let id: String

  /// The payload.
  public let content: Payload

  /// Makes a segment.
  ///
  /// - Parameters:
  ///   - id: The id of the segment.
  ///   - content: The payload.
  public init(id: String, content: Payload) {
    self.id = id
    self.content = content
  }
}

/// An approval payload in a Router structured segment.
public typealias ApprovalSegment = CatalogSegment<ApprovalPayload>

/// A plan payload in a Router structured segment.
public typealias PlanSegment = CatalogSegment<PlanPayload>

/// A citation payload in a Router structured segment.
public typealias CitationSegment = CatalogSegment<CitationPayload>

/// An artifact payload in a Router structured segment.
public typealias ArtifactSegment = CatalogSegment<ArtifactPayload>

/// An authorization payload in a Router structured segment.
public typealias AuthorizationSegment = CatalogSegment<AuthorizationPayload>

/// A usage payload in a Router structured segment.
public typealias UsageSegment = CatalogSegment<UsagePayload>

nonisolated extension StructuredPayload {
  /// The payload as a Router structured segment.
  ///
  /// - Parameter id: The id of the segment.
  /// - Returns: The segment, with the catalog name of the payload.
  public func routerSegment(id: String) -> CatalogSegment<Self> {
    CatalogSegment(id: id, content: self)
  }
}
