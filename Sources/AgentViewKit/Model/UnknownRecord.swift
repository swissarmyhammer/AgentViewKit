import Observation

/// An item that the adapter did not know (plan.md §3.2).
///
/// The kit shows this record and does not drop it.
@Observable
public final class UnknownRecord: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The name of the item kind that the source gave, such as a wire tag.
  public var kind: String

  /// The item as the source gave it.
  public var raw: JSONValue

  /// Makes an unknown record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - kind: The name of the item kind that the source gave.
  ///   - raw: The item as the source gave it.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, kind: String, raw: JSONValue, meta: JSONValue? = nil) {
    self.id = id
    self.kind = kind
    self.raw = raw
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
