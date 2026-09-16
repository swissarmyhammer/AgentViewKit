import Observation

/// A structured segment that no mapping claimed (plan.md §3.2).
///
/// The view registry finds the view for the record by ``schemaName``. The
/// payload is a ``JSONValue``, so this target does not import
/// FoundationModels. The FoundationModels target converts `GeneratedContent`
/// to this value.
@Observable
public final class StructuredRecord: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The schema name of the segment, such as `AgentViewKit.Chart`.
  public var schemaName: String

  /// The content of the segment.
  public var payload: JSONValue

  /// Makes a structured record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - schemaName: The schema name of the segment.
  ///   - payload: The content of the segment.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, schemaName: String, payload: JSONValue, meta: JSONValue? = nil) {
    self.id = id
    self.schemaName = schemaName
    self.payload = payload
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
