import Observation

/// The record that a ``ThreadItem`` case holds (plan.md §3.2).
///
/// Each record is an `@Observable` class. A patch changes the record in place
/// and calls ``bump()``. A row view reads one record, so only that row
/// becomes invalid when the record changes (plan.md §8).
///
/// The `id` of a record is a `String`. It does not change when a patch
/// occurs.
public protocol ThreadRecord: AnyObject, Identifiable, Observable where ID == String {
  /// The number of patches on the record.
  ///
  /// A new record has revision zero. Two rows are equal when they have the
  /// same id and the same revision.
  var revision: Int { get }

  /// The `_meta` value of the source, unchanged.
  ///
  /// An adapter or a host can read extension data from it.
  var meta: JSONValue? { get }

  /// Increments ``revision`` by one.
  ///
  /// Call this function after each patch on the record.
  func bump()
}
