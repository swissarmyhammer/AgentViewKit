import Observation

/// The point where the source rewrote the thread to make it shorter
/// (plan.md §3.2, Docs/decisions/compaction-ux.md).
///
/// ``ThreadChange/compact(marker:removing:)`` removes the earlier items and
/// puts this marker in their place. That change writes ``removedItemIDs``
/// and ``removedKinds`` from the items that it removed.
@Observable
public final class CompactionMarker: ThreadRecord {
  /// The identifier of the record.
  public nonisolated let id: String

  /// The number of patches on the record. Call ``bump()`` to change it.
  public var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The summary that replaced the earlier items, if the source gave one.
  public var summary: String?

  /// The identifiers of the items that the compaction removed, in thread
  /// order.
  public var removedItemIDs: [String]

  /// The number of removed items of each kind, keyed by
  /// ``ThreadItem/kindName``.
  public var removedKinds: [String: Int]

  /// Makes a compaction marker record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - summary: The summary that replaced the earlier items.
  ///   - removedItemIDs: The identifiers of the removed items, in thread
  ///     order.
  ///   - removedKinds: The number of removed items of each kind.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: String,
    summary: String?,
    removedItemIDs: [String] = [],
    removedKinds: [String: Int] = [:],
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.summary = summary
    self.removedItemIDs = removedItemIDs
    self.removedKinds = removedKinds
    self.meta = meta
  }

  /// The number of items that the compaction removed.
  public var removedCount: Int {
    removedItemIDs.count
  }
}
