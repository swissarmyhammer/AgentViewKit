import SwiftUI

/// The default view of a compaction item: a divider row that marks the
/// point where the source rewrote the thread (plan.md §9 A2,
/// Docs/decisions/compaction-ux.md).
///
/// The row shows the title "Conversation compacted" between two rules, the
/// number of removed items, and the summary when the source gave one. A
/// "Show removed" button opens a list of the removed kinds with the count of
/// each kind. The row has a tinted background, so that it looks different
/// from a message.
///
/// The list is closed by default. The user decision is in the
/// ``ExpandedBlocksStore`` of the environment, keyed by the record id. A
/// marker with no user decision uses the
/// ``ExpandedBlocksStore/defaultExpanded`` policy of the store. When the
/// environment has no store, the view uses a store of its own.
public struct CompactionMarkerView: View {
  /// The accessibility identifier of the row.
  public static let identifier = "compaction-marker"

  /// The accessibility identifier of the "Show removed" button.
  public static let toggleIdentifier = identifier + "-toggle"

  /// The accessibility identifier of the list of removed kinds.
  public static let removedIdentifier = identifier + "-removed"

  /// The accessibility identifier of the summary text.
  public static let summaryIdentifier = identifier + "-summary"

  /// The start of the accessibility identifier of each removed kind.
  public static let kindIdentifierPrefix = identifier + "-kind-"

  /// The opacity of the background tint of the row.
  static let backgroundOpacity: Double = 0.08

  /// The record to show.
  let record: CompactionMarker

  /// The store that the view uses when the environment has no store.
  @State private var ownStore = ExpandedBlocksStore()

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.agentTheme) private var theme

  /// Makes the view of a compaction marker.
  ///
  /// - Parameter record: The marker to show.
  public init(record: CompactionMarker) {
    self.record = record
  }

  /// The accessibility identifier of the line of one removed kind.
  ///
  /// - Parameter kind: The ``ThreadItem/kindName`` of the kind.
  /// - Returns: `compaction-marker-kind-<kind>`.
  public static func kindIdentifier(for kind: String) -> String {
    AccessibilityIdentifier.make(prefix: kindIdentifierPrefix, value: kind)
  }

  /// The accessibility label of the row.
  ///
  /// - Parameter removedCount: The number of removed items.
  /// - Returns: "Conversation compacted, N items summarized", with "item"
  ///   when N is one.
  public static func accessibilityText(removedCount: Int) -> String {
    removedCount == 1
      ? String(localized: "Conversation compacted, 1 item summarized")
      : String(localized: "Conversation compacted, \(removedCount) items summarized")
  }

  /// The text of the count of removed items.
  ///
  /// - Parameter removedCount: The number of removed items.
  /// - Returns: "N items summarized", with "item" when N is one.
  static func countText(removedCount: Int) -> String {
    removedCount == 1
      ? String(localized: "1 item summarized")
      : String(localized: "\(removedCount) items summarized")
  }

  /// The text of the line of one removed kind.
  ///
  /// - Parameters:
  ///   - kind: The ``ThreadItem/kindName`` of the kind.
  ///   - count: The number of removed items of the kind.
  /// - Returns: The count and the name of the kind, such as "2 tool calls".
  ///   An unknown kind name shows as it is.
  public static func kindText(kind: String, count: Int) -> String {
    let noun = kindNoun(kind, singular: count == 1) ?? kind
    return String(localized: "\(count) \(noun)")
  }

  /// The display noun of a kind.
  ///
  /// - Parameters:
  ///   - kind: The ``ThreadItem/kindName`` of the kind.
  ///   - singular: `true` for the noun of one item.
  /// - Returns: The noun, or `nil` for an unknown kind name.
  private static func kindNoun(_ kind: String, singular: Bool) -> String? {
    switch kind {
    case "system":
      singular ? String(localized: "instruction block") : String(localized: "instruction blocks")
    case "user":
      singular ? String(localized: "user message") : String(localized: "user messages")
    case "assistant":
      singular ? String(localized: "agent message") : String(localized: "agent messages")
    case "reasoning":
      singular ? String(localized: "reasoning block") : String(localized: "reasoning blocks")
    case "tool-call":
      singular ? String(localized: "tool call") : String(localized: "tool calls")
    case "structured":
      singular ? String(localized: "structured item") : String(localized: "structured items")
    case "compaction":
      singular ? String(localized: "earlier compaction") : String(localized: "earlier compactions")
    case "error":
      singular ? String(localized: "error") : String(localized: "errors")
    case "unknown":
      singular ? String(localized: "other item") : String(localized: "other items")
    default:
      nil
    }
  }

  /// The removed kinds with their counts, the largest count first. Kinds
  /// with the same count are in name order.
  ///
  /// - Parameter kinds: The count of each kind.
  /// - Returns: The kinds in display order.
  static func orderedKinds(_ kinds: [String: Int]) -> [(kind: String, count: Int)] {
    kinds
      .map { (kind: $0.key, count: $0.value) }
      .sorted { $0.count != $1.count ? $0.count > $1.count : $0.kind < $1.kind }
  }

  public var body: some View {
    let store = environmentStore ?? ownStore
    let expanded = store.isExpanded(.compaction(record))
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      divider
      if let summary = record.summary, !summary.isEmpty {
        Text(summary)
          .font(theme.proseFont)
          .foregroundStyle(.secondary)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
          .accessibilityIdentifier(Self.summaryIdentifier)
      }
      if record.removedCount > 0 {
        toggle(store: store, expanded: expanded)
        if expanded {
          removedList
        }
      }
    }
    .padding(theme.rowPadding)
    .background(
      theme.accent.opacity(Self.backgroundOpacity),
      in: RoundedRectangle(cornerRadius: theme.radii.m)
    )
    .contentContainer(identifier: Self.identifier)
    .accessibilityLabel(Self.accessibilityText(removedCount: record.removedCount))
    // The row is a container with this block as its one child. The second
    // hidden child keeps SwiftUI from merging the block into the row, so
    // the block keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The title and the count between two rules.
  private var divider: some View {
    HStack(spacing: theme.spacing.s) {
      rule
      Image(systemName: "arrow.down.and.line.horizontal.and.arrow.up")
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(.secondary)
        .accessibilityHidden(true)
      Text("Conversation compacted")
        .font(theme.proseFont.weight(.semibold))
        .foregroundStyle(.secondary)
      Text(Self.countText(removedCount: record.removedCount))
        .font(theme.proseFont)
        .foregroundStyle(.tertiary)
      rule
    }
  }

  /// One horizontal rule that fills the free width.
  private var rule: some View {
    Rectangle()
      .fill(.separator)
      .frame(height: 1)
      .frame(maxWidth: .infinity)
      .accessibilityHidden(true)
  }

  /// The button that opens and closes the list of removed kinds.
  ///
  /// - Parameters:
  ///   - store: The store of the user decisions.
  ///   - expanded: `true` while the list is open.
  /// - Returns: The button.
  private func toggle(store: ExpandedBlocksStore, expanded: Bool) -> some View {
    let id = record.id
    return Button {
      store.toggle(id)
    } label: {
      HStack(spacing: theme.spacing.xs) {
        Image(systemName: "chevron.right")
          .fontWeight(theme.symbolWeight)
          .rotationEffect(expanded ? ReasoningView.expandedChevronAngle : .zero)
        expanded ? Text("Hide removed") : Text("Show removed")
      }
      .font(theme.proseFont)
      .foregroundStyle(.secondary)
    }
    .buttonStyle(.borderless)
    .accessibilityLabel(expanded ? Text("Hide removed items") : Text("Show removed items"))
    .accessibilityIdentifier(Self.toggleIdentifier)
  }

  /// The list of removed kinds with their counts.
  private var removedList: some View {
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      ForEach(Self.orderedKinds(record.removedKinds), id: \.kind) { entry in
        Text(Self.kindText(kind: entry.kind, count: entry.count))
          .font(theme.proseFont)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(Self.kindIdentifier(for: entry.kind))
      }
    }
    .padding(.leading, theme.spacing.l)
    .contentContainer(identifier: Self.removedIdentifier)
  }
}
