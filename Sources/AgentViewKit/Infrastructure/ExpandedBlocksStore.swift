import FoundationModelsACPClient
import Observation
import SwiftUI

extension EnvironmentValues {
  /// The store of the expanded rows that the item views read.
  ///
  /// ``AgentThreadView`` sets a store for its rows. A view with no store
  /// keeps its expanded state itself.
  @Entry public var expandedBlocksStore: ExpandedBlocksStore? = nil
}

/// Keeps which rows are expanded (plan.md §8, §9 C2).
///
/// The store is outside the row views, so a toggle does not invalidate the
/// list. The store keeps one observed value for each identifier, so a toggle
/// invalidates only the views that read that identifier. The open state is
/// view state: the store keeps no value of the session model.
///
/// A transcript entry with no recorded decision uses ``defaultExpanded``.
/// The policy gets the entry object, so it reads the values of the model,
/// such as the status of a tool call. A view that reads the policy in its
/// body therefore opens when the model sets a value that the policy expands.
/// ``seed(_:)`` records the policy value for an entry one time, so that a
/// read by identifier and ``toggle(_:)`` start from the policy. The
/// identifier of an entry is its row key
/// (``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``).
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
    /// `true` while the row is expanded, or `nil` when no decision is
    /// recorded.
    var decision: Bool?
  }

  /// The policy for a transcript entry with no recorded decision.
  public let defaultExpanded: @MainActor (TranscriptEntry) -> Bool

  /// The observed decision of each identifier that the store has read or
  /// written.
  ///
  /// A read adds an entry with no decision. The dictionary itself is not
  /// observed, so an added identifier invalidates no view.
  @ObservationIgnored private var entries: [String: Entry] = [:]

  /// Makes a store.
  ///
  /// - Parameter defaultExpanded: The policy for a transcript entry with no
  ///   recorded decision. The default expands no entry.
  public init(defaultExpanded: @escaping @MainActor (TranscriptEntry) -> Bool = { _ in false }) {
    self.defaultExpanded = defaultExpanded
  }

  // MARK: - Read

  /// Tells if the row with this identifier is expanded.
  ///
  /// - Parameter id: The row identifier.
  /// - Returns: The recorded decision, or `false` when there is none.
  public func isExpanded(_ id: String) -> Bool {
    entry(for: id).decision ?? false
  }

  /// Tells if the row of a transcript entry is expanded.
  ///
  /// - Parameter transcriptEntry: The entry.
  /// - Returns: The recorded decision for the row key of the entry, or the
  ///   ``defaultExpanded`` value when there is none.
  public func isExpanded(_ transcriptEntry: TranscriptEntry) -> Bool {
    entry(for: transcriptEntry.rowKey).decision ?? defaultExpanded(transcriptEntry)
  }

  /// The recorded decision for the row with this identifier.
  ///
  /// A view that has its own default, for example a block that is open
  /// while it streams, uses this value to tell a user decision from no
  /// decision.
  ///
  /// - Parameter id: The row identifier.
  /// - Returns: The recorded decision, or `nil` when there is none.
  public func decision(for id: String) -> Bool? {
    entry(for: id).decision
  }

  // MARK: - Write

  /// Records the ``defaultExpanded`` value for the row of a transcript
  /// entry, when the row has no decision.
  ///
  /// - Parameter transcriptEntry: The entry.
  public func seed(_ transcriptEntry: TranscriptEntry) {
    let id = transcriptEntry.rowKey
    guard entry(for: id).decision == nil else { return }
    set(id, expanded: defaultExpanded(transcriptEntry))
  }

  /// Flips the row with this identifier, and leaves each other row.
  ///
  /// - Parameter id: The row identifier.
  public func toggle(_ id: String) {
    set(id, expanded: !isExpanded(id))
  }

  /// Expands the row with this identifier.
  ///
  /// - Parameter id: The row identifier.
  public func expand(_ id: String) {
    set(id, expanded: true)
  }

  /// Collapses the row with this identifier.
  ///
  /// - Parameter id: The row identifier.
  public func collapse(_ id: String) {
    set(id, expanded: false)
  }

  // MARK: - Private

  /// Gets the entry for an identifier, and adds one with no decision when
  /// there is none.
  ///
  /// - Parameter id: The row identifier.
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
  ///   - id: The row identifier.
  ///   - expanded: The new decision.
  private func set(_ id: String, expanded: Bool) {
    let target = entry(for: id)
    guard target.decision != expanded else { return }
    target.decision = expanded
  }
}
