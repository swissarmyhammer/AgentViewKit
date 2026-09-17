import SwiftUI

/// The reasoning of the agent, as a collapsible block (plan.md §5, §9 B).
///
/// - While the reasoning is in progress, the title is a ``ShimmerView``, and
///   the block is open. The body streams through ``ResponseView``.
/// - When the reasoning is complete, the title is "Thought for N s" when the
///   record has both times, and "Thought" when it does not. The block
///   collapses, unless the user expanded it.
///
/// The user decision is in the ``ExpandedBlocksStore`` of the environment,
/// keyed by the record id. A block with no user decision is open while it is
/// in progress. When it is complete, it uses the
/// ``ExpandedBlocksStore/defaultExpanded`` policy of the store, which is
/// closed by default. When the environment has no store, the view uses a
/// store of its own.
///
/// ``AgentThreadView`` finds the in-progress state from the thread: a
/// reasoning item is in progress when it is the last item and the thread
/// runs (plan.md §3.5). See ``AgentThread/isLastWhileRunning(_:)``.
public struct ReasoningView: View {
  /// The start of the accessibility identifier of each block.
  public static let identifierPrefix = "reasoning-"

  /// The end of the accessibility identifier of the title.
  static let titleSuffix = "-title"

  /// The end of the accessibility identifier of the expand button.
  static let toggleSuffix = "-toggle"

  /// The end of the accessibility identifier of the body.
  static let bodySuffix = "-body"

  /// The number of degrees in a quarter turn.
  static let quarterTurnDegrees: Double = 90

  /// The rotation of the chevron while the block is open: a quarter turn,
  /// so that the chevron points down.
  static let expandedChevronAngle = Angle.degrees(quarterTurnDegrees)

  /// The record to show.
  let record: Reasoning

  /// `true` while the agent still writes the reasoning.
  let isInProgress: Bool

  /// The stream of the reasoning, or `nil` when it does not stream.
  let streaming: StreamingMessage?

  /// The store that the view uses when the environment has no store.
  @State private var ownStore = ExpandedBlocksStore()

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.agentTheme) private var theme

  /// Makes a reasoning block.
  ///
  /// - Parameters:
  ///   - record: The reasoning to show.
  ///   - isInProgress: `true` while the agent still writes the reasoning.
  ///   - streaming: The stream of the reasoning, or `nil` when it does not
  ///     stream. Give `thread.streaming[record.id]`.
  public init(record: Reasoning, isInProgress: Bool, streaming: StreamingMessage? = nil) {
    self.record = record
    self.isInProgress = isInProgress
    self.streaming = streaming
  }

  /// The accessibility identifier of the block of `id`.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `reasoning-<id>`.
  public static func identifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id)
  }

  /// The accessibility identifier of the title of a complete block.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `reasoning-<id>-title`.
  public static func titleIdentifier(for id: String) -> String {
    identifier(for: id) + titleSuffix
  }

  /// The accessibility identifier of the expand button.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `reasoning-<id>-toggle`.
  public static func toggleIdentifier(for id: String) -> String {
    identifier(for: id) + toggleSuffix
  }

  /// The accessibility identifier of the body.
  ///
  /// - Parameter id: The identifier of the record.
  /// - Returns: `reasoning-<id>-body`.
  public static func bodyIdentifier(for id: String) -> String {
    identifier(for: id) + bodySuffix
  }

  /// The title of a complete block.
  ///
  /// - Parameter duration: The time of the reasoning, or `nil` when it is not
  ///   known.
  /// - Returns: "Thought for N s", with N rounded to whole seconds, or
  ///   "Thought" when `duration` is `nil`.
  public static func completedTitle(duration: TimeInterval?) -> String {
    guard let duration else { return String(localized: "Thought") }
    let seconds = Int(duration.rounded())
    return String(localized: "Thought for \(seconds) s")
  }

  public var body: some View {
    let store = environmentStore ?? ownStore
    let expanded = isExpanded(in: store)
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header(store: store, expanded: expanded)
      if expanded {
        ResponseView(message: bodyMessage, streaming: streaming)
          .foregroundStyle(.secondary)
          .contentContainer(identifier: Self.bodyIdentifier(for: record.id))
      }
    }
    .contentContainer(identifier: Self.identifier(for: record.id))
    // The row is a container with this block as its one child. The second
    // hidden child keeps SwiftUI from merging the block into the row, so
    // the block keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The message that holds the text of the reasoning.
  ///
  /// The message id is the record id, because the code block cache and the
  /// evaluation counter use it as a key.
  private var bodyMessage: Message {
    Message(id: record.id, blocks: [ContentBlock(text: record.text)])
  }

  /// Tells if the block is open.
  ///
  /// - Parameter store: The store of the user decisions.
  /// - Returns: The user decision. With no decision, `true` while in
  ///   progress, and the store policy when complete.
  private func isExpanded(in store: ExpandedBlocksStore) -> Bool {
    if let decision = store.decision(for: record.id) {
      return decision
    }
    return isInProgress || store.defaultExpanded(.reasoning(record))
  }

  /// The title and the expand button.
  ///
  /// - Parameters:
  ///   - store: The store of the user decisions.
  ///   - expanded: `true` while the block is open.
  /// - Returns: The header view.
  private func header(store: ExpandedBlocksStore, expanded: Bool) -> some View {
    let id = record.id
    let toggle = {
      if expanded {
        store.collapse(id)
      } else {
        store.expand(id)
      }
    }
    return HStack(spacing: theme.spacing.s) {
      title
      Spacer(minLength: theme.spacing.s)
      Button(action: toggle) {
        Image(systemName: "chevron.right")
          .fontWeight(theme.symbolWeight)
          .rotationEffect(expanded ? Self.expandedChevronAngle : .zero)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(
        expanded ? Text("Hide reasoning") : Text("Show reasoning")
      )
      .accessibilityIdentifier(Self.toggleIdentifier(for: id))
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: toggle)
  }

  /// The shimmer while in progress, or the complete title.
  @ViewBuilder private var title: some View {
    if isInProgress {
      ShimmerView(text: ActivityIndicator.thinkingText)
    } else {
      Text(Self.completedTitle(duration: record.duration))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(Self.titleIdentifier(for: record.id))
    }
  }
}
