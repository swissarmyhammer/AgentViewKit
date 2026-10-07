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
/// Each public method takes the `TranscriptEntry` of the row. The store keys
/// the decision of an entry by its row key
/// (``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``).
///
/// A transcript entry with no recorded decision uses ``defaultExpanded``.
/// The policy gets the entry object, so it reads the values of the model,
/// such as the status of a tool call. A view that reads the policy in its
/// body therefore opens when the model sets a value that the policy expands.
/// ``toggle(entry:)`` flips the policy value of an entry with no decision.
/// ``seed(entry:)`` records the policy value for an entry one time, so that
/// a later change of the model does not change the open state.
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

  /// Tells if the row of a transcript entry is expanded.
  ///
  /// - Parameter transcriptEntry: The entry.
  /// - Returns: The recorded decision for the row key of the entry, or the
  ///   ``defaultExpanded`` value when there is none.
  public func isExpanded(entry transcriptEntry: TranscriptEntry) -> Bool {
    decision(for: transcriptEntry) ?? defaultExpanded(transcriptEntry)
  }

  /// The recorded decision for the row of a transcript entry.
  ///
  /// A view that has its own default, for example a block that is open
  /// while it streams, uses this value to tell a user decision from no
  /// decision.
  ///
  /// - Parameter transcriptEntry: The entry.
  /// - Returns: The recorded decision for the row key of the entry, or `nil`
  ///   when there is none.
  public func decision(for transcriptEntry: TranscriptEntry) -> Bool? {
    decision(for: transcriptEntry.rowKey)
  }

  // MARK: - Write

  /// Records the ``defaultExpanded`` value for the row of a transcript
  /// entry, when the row has no decision.
  ///
  /// - Parameter transcriptEntry: The entry.
  public func seed(entry transcriptEntry: TranscriptEntry) {
    guard decision(for: transcriptEntry) == nil else { return }
    set(id: transcriptEntry.rowKey, expanded: defaultExpanded(transcriptEntry))
  }

  /// Flips the row of a transcript entry, and leaves each other row.
  ///
  /// A row with no decision flips the ``defaultExpanded`` value.
  ///
  /// - Parameter transcriptEntry: The entry.
  public func toggle(entry transcriptEntry: TranscriptEntry) {
    set(id: transcriptEntry.rowKey, expanded: !isExpanded(entry: transcriptEntry))
  }

  /// Expands the row of a transcript entry.
  ///
  /// - Parameter transcriptEntry: The entry.
  public func expand(entry transcriptEntry: TranscriptEntry) {
    expand(id: transcriptEntry.rowKey)
  }

  /// Collapses the row of a transcript entry.
  ///
  /// - Parameter transcriptEntry: The entry.
  public func collapse(entry transcriptEntry: TranscriptEntry) {
    collapse(id: transcriptEntry.rowKey)
  }

  // MARK: - Row identifier

  // A row with no transcript entry keys its decision by an identifier. The
  // kit callers are the rows of the old thread path, which have `ThreadItem`
  // ids (`ToolCallView`, `ReasoningView` and the expand-all command over an
  // `AgentThread`), and `JSONDisclosure`, whose rows include unknown values
  // and unknown content blocks. These forms are internal: the public form
  // takes the transcript entry. No identifier read applies the policy,
  // because the policy reads a transcript entry.

  /// Tells if the row with this identifier is expanded.
  ///
  /// - Parameter id: The row identifier.
  /// - Returns: The recorded decision, or `false` when there is none.
  func isExpanded(id: String) -> Bool {
    decision(for: id) ?? false
  }

  /// The recorded decision for the row with this identifier.
  ///
  /// - Parameter id: The row identifier.
  /// - Returns: The recorded decision, or `nil` when there is none.
  func decision(for id: String) -> Bool? {
    entry(for: id).decision
  }

  /// Expands the row with this identifier.
  ///
  /// - Parameter id: The row identifier.
  func expand(id: String) {
    set(id: id, expanded: true)
  }

  /// Collapses the row with this identifier.
  ///
  /// - Parameter id: The row identifier.
  func collapse(id: String) {
    set(id: id, expanded: false)
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
  private func set(id: String, expanded: Bool) {
    let target = entry(for: id)
    guard target.decision != expanded else { return }
    target.decision = expanded
  }
}
