import FoundationModelsACPClient
import SwiftUI

/// The row of one thread item or one transcript entry (plan.md §3.6, §8;
/// update.md §4.2).
///
/// The row reads only its own record. Thus a patch to the record makes only
/// this row invalid. The row switches over ``ThreadItem``. For each kind, it
/// shows the override of the environment when there is one, and otherwise the
/// default view of the kind.
///
/// A row of a `TranscriptEntry` switches over the entry case. A user message,
/// an agent message, a thought, a tool call, a terminal, a plan, an unknown
/// update, a compaction and an error show in ``UserMessageView``,
/// ``AssistantMessageView``, ``ReasoningView``, ``ToolCallView``,
/// ``TerminalView``, ``TaskListView``, ``UnknownItemView``,
/// ``CompactionEntryView`` and ``ErrorView``. The row itself reads nothing of
/// the entry: the item view reads the content, so a streamed chunk evaluates
/// the item view and not the row.
///
/// Two rows are equal when they show the same record object with the same id
/// and the same revision, or the same entry object. Apply `.equatable()` to
/// the row, so that a change to the item list does not evaluate the rows that
/// did not change.
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

  /// The value that a row shows.
  private enum Source {
    /// An item of an ``AgentThread``.
    case item(ThreadItem)

    /// An entry of the transcript of a `SessionModel`.
    case entry(TranscriptEntry)
  }

  /// The value to show.
  private let source: Source

  /// Makes a row.
  ///
  /// - Parameter item: The item to show.
  public init(item: ThreadItem) {
    self.source = .item(item)
  }

  /// Makes the row of a transcript entry.
  ///
  /// - Parameter entry: The entry to show.
  public init(entry: TranscriptEntry) {
    self.source = .entry(entry)
  }

  /// The text identity of the row: the item id, or the row key of the entry.
  var id: String {
    switch source {
    case .item(let item): item.id
    case .entry(let entry): entry.rowKey
    }
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

  /// Tells whether two rows show the same record at the same revision, or the
  /// same transcript entry object.
  ///
  /// The comparison includes the record object. A new record object with the
  /// same id and revision, for example after a remove and an insert, is then
  /// a different row. An entry object keeps its identity for its whole life,
  /// so two rows of the same entry object are equal.
  ///
  /// - Parameters:
  ///   - lhs: A row.
  ///   - rhs: A row.
  /// - Returns: `true` when the two rows show the same record at the same
  ///   revision, or the same entry object.
  public static func == (lhs: ItemRow, rhs: ItemRow) -> Bool {
    switch (lhs.source, rhs.source) {
    case (.item(let left), .item(let right)):
      ObjectIdentifier(left.record) == ObjectIdentifier(right.record)
        && left.record.id == right.record.id
        && left.record.revision == right.record.revision
    case (.entry(let left), .entry(let right)):
      left.id == right.id && ObjectIdentifier(left.object) == ObjectIdentifier(right.object)
    case (.item, .entry), (.entry, .item):
      false
    }
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

  /// The view of the item or of the entry.
  @ViewBuilder private var content: some View {
    switch source {
    case .item(let item):
      // The row reads the revision, so that each patch of the record
      // evaluates this body one time.
      let _ = item.record.revision
      itemContent(item)
    case .entry(let entry):
      entryContent(entry)
    }
  }

  /// The view of a transcript entry.
  ///
  /// Each entry kind shows in its item view, which reads the entry object.
  ///
  /// - Parameter entry: The entry to show.
  /// - Returns: The view of the entry.
  @ViewBuilder private func entryContent(_ entry: TranscriptEntry) -> some View {
    switch entry {
    case .userMessage(let message):
      UserMessageView(entry: message)
    case .agentMessage(let message):
      AssistantMessageView(entry: message)
    case .thought(let thought):
      ReasoningView(entry: thought)
    case .toolCall(let toolCall):
      ToolCallView(entry: toolCall)
    case .terminal(let terminal):
      TerminalView(entry: terminal)
    case .plan(let plan):
      TaskListView(entry: plan)
    case .unknown(let unknown):
      UnknownItemView(entry: unknown)
    case .error(let error):
      ErrorView(entry: error)
    case .compaction(let compaction):
      CompactionEntryView(entry: compaction)
    }
  }

  /// The view of a thread item: the override of its kind, or the default
  /// view.
  ///
  /// - Parameter item: The item to show.
  /// - Returns: The view of the item.
  @ViewBuilder private func itemContent(_ item: ThreadItem) -> some View {
    switch item {
    case .userMessage(let record):
      OverridableItemView(\.userMessageViewOverride, record: record) { record in
        UserMessageView(message: record)
      }
    case .assistantMessage(let record):
      OverridableItemView(\.assistantMessageViewOverride, record: record) { record in
        AssistantMessageView(message: record)
      }
    case .reasoning(let record):
      OverridableItemView(\.reasoningViewOverride, record: record) { record in
        ThreadReasoningView(record: record)
      }
    case .toolCall(let record):
      OverridableItemView(\.toolCallViewOverride, record: record) { record in
        ToolCallView(record: record)
      }
    case .error(let record):
      OverridableItemView(\.errorViewOverride, record: record) { record in
        ErrorView(error: record)
      }
    case .unknown(let record):
      OverridableItemView(\.unknownItemViewOverride, record: record) { record in
        UnknownItemView(record: record)
      }
    }
  }
}

/// Shows the override of one item kind, or the default view of the kind.
///
/// The view reads only the environment key of its kind. Thus a change to the
/// override of a different kind does not make this view invalid.
private struct OverridableItemView<Record, Fallback: View>: View {
  /// The override of the kind, or `nil`.
  @Environment private var override: ItemViewRenderer<Record>?

  /// The record to show.
  let record: Record

  /// The function that makes the default view.
  let fallback: (Record) -> Fallback

  /// Makes the view.
  ///
  /// - Parameters:
  ///   - key: The environment key of the override of the kind.
  ///   - record: The record to show.
  ///   - fallback: The function that makes the default view.
  init(
    _ key: KeyPath<EnvironmentValues, ItemViewRenderer<Record>?>,
    record: Record,
    @ViewBuilder fallback: @escaping (Record) -> Fallback
  ) {
    _override = Environment(key)
    self.record = record
    self.fallback = fallback
  }

  var body: some View {
    if let override {
      override(record)
    } else {
      fallback(record)
    }
  }
}

/// Shows a ``ReasoningView`` with the in-progress state and the stream from
/// the thread of the environment (plan.md §3.5).
///
/// This view, and not the row, reads the thread. Thus a change to the last
/// item or to the run state evaluates only this view, and the row stays
/// equal.
private struct ThreadReasoningView: View {
  /// The record to show.
  let record: Reasoning

  @Environment(\.agentThread) private var thread

  var body: some View {
    ReasoningView(
      record: record,
      isInProgress: thread?.isLastWhileRunning(record.id) ?? false,
      streaming: thread?.streaming[record.id]
    )
  }
}
