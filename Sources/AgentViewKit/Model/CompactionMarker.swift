import Observation

/// The point where the source rewrote the thread to make it shorter
/// (plan.md §3.2).
@Observable
public final class CompactionMarker: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The summary that replaced the earlier items, if the source gave one.
  public var summary: String?

  /// Makes a compaction marker record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - summary: The summary that replaced the earlier items.
  ///   - meta: The `_meta` value of the source.
  public init(id: String, summary: String?, meta: JSONValue? = nil) {
    self.id = id
    self.summary = summary
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}
