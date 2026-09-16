import Observation

/// Keeps which thread items are expanded (plan.md §8, §9 C2).
///
/// The store is outside the row views, so a toggle does not invalidate the
/// list. The store keeps one observed value for each identifier, so a toggle
/// invalidates only the views that read that identifier.
///
/// An item with no recorded decision uses ``defaultExpanded``.
/// ``seed(_:)`` records the policy value for an item one time, so that a read
/// by identifier and ``toggle(_:)`` start from the policy.
@MainActor
@Observable
public final class ExpandedBlocksStore {
  /// The observed decision for one identifier.
  ///
  /// The `@Observable` macro makes an extension of the class, so the class is
  /// `fileprivate` and not `private`.
  @MainActor
  @Observable
  fileprivate final class Entry {
    /// `true` while the item is expanded, or `nil` when no decision is
    /// recorded.
    var decision: Bool?
  }

  /// The policy for an item with no recorded decision.
  public let defaultExpanded: (ThreadItem) -> Bool

  /// The observed decision of each identifier that the store has read or
  /// written.
  ///
  /// A read adds an entry with no decision. The dictionary itself is not
  /// observed, so an added identifier invalidates no view.
  @ObservationIgnored private var entries: [String: Entry] = [:]

  /// Makes a store.
  ///
  /// - Parameter defaultExpanded: The policy for an item with no recorded
  ///   decision. The default expands no item.
  public init(defaultExpanded: @escaping (ThreadItem) -> Bool = { _ in false }) {
    self.defaultExpanded = defaultExpanded
  }

  // MARK: - Read

  /// Tells if the item with this identifier is expanded.
  ///
  /// - Parameter id: The item identifier.
  /// - Returns: The recorded decision, or `false` when there is none.
  public func isExpanded(_ id: String) -> Bool {
    entry(for: id).decision ?? false
  }

  /// Tells if the item is expanded.
  ///
  /// - Parameter item: The item.
  /// - Returns: The recorded decision, or the ``defaultExpanded`` value when
  ///   there is none.
  public func isExpanded(_ item: ThreadItem) -> Bool {
    entry(for: item.id).decision ?? defaultExpanded(item)
  }

  // MARK: - Write

  /// Records the ``defaultExpanded`` value for the item, when the item has no
  /// decision.
  ///
  /// - Parameter item: The item.
  public func seed(_ item: ThreadItem) {
    guard entry(for: item.id).decision == nil else { return }
    set(item.id, expanded: defaultExpanded(item))
  }

  /// Flips the item with this identifier, and leaves each other item.
  ///
  /// - Parameter id: The item identifier.
  public func toggle(_ id: String) {
    set(id, expanded: !isExpanded(id))
  }

  /// Expands the item with this identifier.
  ///
  /// - Parameter id: The item identifier.
  public func expand(_ id: String) {
    set(id, expanded: true)
  }

  /// Collapses the item with this identifier.
  ///
  /// - Parameter id: The item identifier.
  public func collapse(_ id: String) {
    set(id, expanded: false)
  }

  // MARK: - Private

  /// Gets the entry for an identifier, and adds one with no decision when
  /// there is none.
  ///
  /// - Parameter id: The item identifier.
  /// - Returns: The entry.
  private func entry(for id: String) -> Entry {
    if let existing = entries[id] {
      return existing
    }
    let added = Entry()
    entries[id] = added
    return added
  }

  /// Records a decision for an identifier.
  ///
  /// The entry changes only when the decision changes, so an equal write
  /// invalidates no view.
  ///
  /// - Parameters:
  ///   - id: The item identifier.
  ///   - expanded: The new decision.
  private func set(_ id: String, expanded: Bool) {
    let target = entry(for: id)
    guard target.decision != expanded else { return }
    target.decision = expanded
  }
}
