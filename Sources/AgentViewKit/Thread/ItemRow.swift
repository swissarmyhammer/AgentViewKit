import FoundationModelsACPClient
import SwiftUI

/// The row of one transcript entry (plan.md §3.2, §3.6,
/// §8).
///
/// A row of a `TranscriptEntry` switches over the entry case. For each case,
/// it shows the override of the environment when there is one (see
/// ``SwiftUI/EnvironmentValues/toolCallViewOverride`` and the other keys of
/// the cases), and otherwise the default view of the case. The override gets
/// the entry object, so it reads the model directly. A user message, an agent
/// message, a thought, a tool call, a terminal, a plan, an unknown update, a
/// compaction and an error show by default in ``UserMessageView``,
/// ``AssistantMessageView``, ``ReasoningView``, ``ToolCallView``,
/// ``TerminalView``, ``TaskListView``, ``UnknownItemView``,
/// ``CompactionEntryView`` and ``ErrorView``. The row itself reads nothing of
/// the entry: the item view reads the content, so a streamed chunk evaluates
/// the item view and not the row.
///
/// Two rows are equal when they show the same entry object. Apply
/// `.equatable()` to the row, so that a change to the transcript does not
/// evaluate the rows that did not change.
public struct ItemRow: View, Equatable {
  /// The start of the accessibility identifier of each row.
  public static let identifierPrefix = "item-row-"

  /// The start of the accessibility identifier of each placeholder view.
  public static let placeholderIdentifierPrefix = "item-placeholder-"

  /// The start of the ``BodyEvaluationCounter`` key of each row.
  public static let counterKeyPrefix = "row-"

  /// The start of the ``BodyEvaluationCounter`` key of the view that reads
  /// the content of a transcript entry.
  public static let contentCounterKeyPrefix = "row-content-"

  /// The transcript entry to show.
  private let entry: TranscriptEntry

  /// Makes the row of a transcript entry.
  ///
  /// - Parameter entry: The entry to show.
  public init(entry: TranscriptEntry) {
    self.entry = entry
  }

  /// The text identity of the row: the row key of the entry.
  var id: String {
    entry.rowKey
  }

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `item-row-<id>`.
  public static func identifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id)
  }

  /// The accessibility identifier of the placeholder view of `id`.
  ///
  /// Each item kind now has a default view, so no row shows a placeholder.
  /// Tests use this identifier to check that no placeholder comes back.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `item-placeholder-<id>`.
  public static func placeholderIdentifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: placeholderIdentifierPrefix, value: id)
  }

  /// The ``BodyEvaluationCounter`` key of the row of `id`.
  ///
  /// - Parameter id: The identifier of the item, or the start of it.
  /// - Returns: `row-<id>`.
  public static func counterKey(for id: String) -> String {
    counterKeyPrefix + id
  }

  /// The ``BodyEvaluationCounter`` key of the view that reads the content of
  /// the transcript entry of the row of `id`.
  ///
  /// The row of an entry does not read the entry, so a chunk does not
  /// evaluate the row. The item view of the entry notes this key each time
  /// that it reads the content again.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `row-content-<id>`.
  public static func contentCounterKey(for id: String) -> String {
    contentCounterKeyPrefix + id
  }

  /// Tells whether two rows show the same transcript entry object.
  ///
  /// An entry object keeps its identity for its whole life, so two rows of
  /// the same entry object are equal.
  ///
  /// - Parameters:
  ///   - lhs: A row.
  ///   - rhs: A row.
  /// - Returns: `true` when the two rows show the same entry object.
  public static func == (lhs: ItemRow, rhs: ItemRow) -> Bool {
    lhs.entry.id == rhs.entry.id
      && ObjectIdentifier(lhs.entry.object) == ObjectIdentifier(rhs.entry.object)
  }

  public var body: some View {
    let id = id
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: id))
    #endif
    return
      content
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(Self.identifier(for: id))
  }

  /// The view of the entry: the override of its case, or the default view.
  ///
  /// The override and the default view get the entry object, so they read
  /// the values of the model directly. Neither one gets a copy of the entry.
  @ViewBuilder private var content: some View {
    switch entry {
    case .userMessage(let message):
      OverridableItemView(\.userMessageViewOverride, entry: message) { UserMessageView(entry: $0) }
    case .agentMessage(let message):
      OverridableItemView(\.assistantMessageViewOverride, entry: message) { AssistantMessageView(entry: $0) }
    case .thought(let thought):
      OverridableItemView(\.reasoningViewOverride, entry: thought) { ReasoningView(entry: $0) }
    case .toolCall(let toolCall):
      OverridableItemView(\.toolCallViewOverride, entry: toolCall) { ToolCallView(entry: $0) }
    case .terminal(let terminal):
      OverridableItemView(\.terminalViewOverride, entry: terminal) { TerminalView(entry: $0) }
    case .plan(let plan):
      OverridableItemView(\.planViewOverride, entry: plan) { TaskListView(entry: $0) }
    case .unknown(let unknown):
      OverridableItemView(\.unknownItemViewOverride, entry: unknown) { UnknownItemView(entry: $0) }
    case .error(let error):
      OverridableItemView(\.errorViewOverride, entry: error) { ErrorView(entry: $0) }
    case .compaction(let compaction):
      OverridableItemView(\.compactionEntryViewOverride, entry: compaction) { CompactionEntryView(entry: $0) }
    }
  }
}

/// Shows the override of one transcript entry case, or the default view of
/// the case.
///
/// The view reads only the environment key of its case. Thus a change to the
/// override of a different case does not make this view invalid. The view
/// reads no value of the entry: the override or the default view reads it.
private struct OverridableItemView<Entry, Fallback: View>: View {
  /// The override of the case, or `nil`.
  @Environment private var override: ItemViewRenderer<Entry>?

  /// The entry object to show.
  let entry: Entry

  /// The function that makes the default view.
  let fallback: (Entry) -> Fallback

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - key: The environment key of the override of the case.
  ///   - entry: The entry object to show.
  ///   - fallback: The function that makes the default view.
  init(
    _ key: KeyPath<EnvironmentValues, ItemViewRenderer<Entry>?>,
    entry: Entry,
    @ViewBuilder fallback: @escaping (Entry) -> Fallback
  ) {
    _override = Environment(key)
    self.entry = entry
    self.fallback = fallback
  }

  var body: some View {
    if let override {
      override(entry)
    } else {
      fallback(entry)
    }
  }
}
