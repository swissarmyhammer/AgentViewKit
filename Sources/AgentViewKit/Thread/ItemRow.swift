import SwiftUI

/// The row of one thread item (plan.md §3.6, §8).
///
/// The row reads only its own record. Thus a patch to the record makes only
/// this row invalid. The row switches over ``ThreadItem``. For each kind, it
/// shows the override of the environment when there is one, and otherwise the
/// default view of the kind.
///
/// Two rows are equal when they show the same record object with the same id
/// and the same revision. Apply `.equatable()` to the row, so that a change to
/// the item list does not evaluate the rows that did not change.
public struct ItemRow: View, Equatable {
  /// The start of the accessibility identifier of each row.
  public static let identifierPrefix = "item-row-"

  /// The start of the accessibility identifier of each placeholder view.
  public static let placeholderIdentifierPrefix = "item-placeholder-"

  /// The start of the ``BodyEvaluationCounter`` key of each row.
  public static let counterKeyPrefix = "row-"

  /// The item to show.
  let item: ThreadItem

  /// Makes a row.
  ///
  /// - Parameter item: The item to show.
  public init(item: ThreadItem) {
    self.item = item
  }

  /// The accessibility identifier of the row of `id`.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `item-row-<id>`.
  public static func identifier(for id: String) -> String {
    identifierPrefix + id
  }

  /// The accessibility identifier of the placeholder view of `id`.
  ///
  /// A later task replaces each placeholder with the default view of its kind.
  ///
  /// - Parameter id: The identifier of the item.
  /// - Returns: `item-placeholder-<id>`.
  public static func placeholderIdentifier(for id: String) -> String {
    placeholderIdentifierPrefix + id
  }

  /// The ``BodyEvaluationCounter`` key of the row of `id`.
  ///
  /// - Parameter id: The identifier of the item, or the start of it.
  /// - Returns: `row-<id>`.
  public static func counterKey(for id: String) -> String {
    counterKeyPrefix + id
  }

  /// Tells whether two rows show the same record at the same revision.
  ///
  /// The comparison includes the record object. A new record object with the
  /// same id and revision, for example after a remove and an insert, is then
  /// a different row.
  ///
  /// - Parameters:
  ///   - lhs: A row.
  ///   - rhs: A row.
  /// - Returns: `true` when the two rows show the same record at the same
  ///   revision.
  public static func == (lhs: ItemRow, rhs: ItemRow) -> Bool {
    let left = lhs.item.record
    let right = rhs.item.record
    return ObjectIdentifier(left) == ObjectIdentifier(right)
      && left.id == right.id
      && left.revision == right.revision
  }

  public var body: some View {
    #if DEBUG
      BodyEvaluationCounter.note(Self.counterKey(for: item.id))
    #endif
    // The row reads the revision, so that each patch of the record evaluates
    // this body one time.
    _ = item.record.revision
    return content
      .frame(maxWidth: .infinity, alignment: .leading)
      .accessibilityElement(children: .contain)
      .accessibilityIdentifier(Self.identifier(for: item.id))
  }

  /// The view of the item: the override of its kind, or the default view.
  @ViewBuilder private var content: some View {
    switch item {
    case .system(let record):
      OverridableItemView(\.systemPromptViewOverride, record: record) { _ in
        placeholder("Instructions")
      }
    case .userMessage(let record):
      OverridableItemView(\.userMessageViewOverride, record: record) { _ in
        placeholder("User message")
      }
    case .assistantMessage(let record):
      OverridableItemView(\.assistantMessageViewOverride, record: record) { _ in
        placeholder("Assistant message")
      }
    case .reasoning(let record):
      OverridableItemView(\.reasoningViewOverride, record: record) { _ in
        placeholder("Reasoning")
      }
    case .toolCall(let record):
      OverridableItemView(\.toolCallViewOverride, record: record) { _ in
        placeholder("Tool call")
      }
    case .structured(let record):
      OverridableItemView(\.structuredItemViewOverride, record: record) { record in
        RegisteredStructuredItemView(record: record)
      }
    case .compaction(let record):
      OverridableItemView(\.compactionViewOverride, record: record) { _ in
        placeholder("Compaction")
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

  /// A labelled text that stands in for the default view of a kind.
  ///
  /// - Parameter label: The name of the item kind.
  /// - Returns: The placeholder view.
  private func placeholder(_ label: LocalizedStringKey) -> some View {
    Text(label)
      .foregroundStyle(.secondary)
      .accessibilityIdentifier(Self.placeholderIdentifier(for: item.id))
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

/// Shows the registration of the schema name of a structured record, or
/// ``StructuredItemView`` when the name has no registration (plan.md §3.6).
private struct RegisteredStructuredItemView: View {
  /// The record to show.
  let record: StructuredRecord

  @Environment(\.structuredItemRegistry) private var registry

  var body: some View {
    if let renderer = registry.resolve(schemaName: record.schemaName) {
      renderer(StructuredItemContent(record: record))
    } else {
      StructuredItemView(record: record)
    }
  }
}
