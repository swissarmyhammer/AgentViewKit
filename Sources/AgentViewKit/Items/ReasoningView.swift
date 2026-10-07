import FoundationModelsACPClient
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
/// keyed by the record id or the row key of the entry. A block with no user
/// decision is open while it is in progress. A complete thought entry uses
/// the ``ExpandedBlocksStore/defaultExpanded`` policy of the store, which is
/// closed by default. A complete reasoning record is closed. When the
/// environment has no store, the view uses a store of its own.
///
/// ``AgentThreadView`` finds the in-progress state from the thread: a
/// reasoning item is in progress when it is the last item and the thread
/// runs (plan.md §3.5). See ``AgentThread/isLastWhileRunning(_:)``.
///
/// The view also shows a `ThoughtEntry` of a `SessionModel` (update.md §4.2).
/// The block of a thought entry always has the complete look: the session
/// model does not tell whether a thought is in progress, so the view shows
/// the ACP content blocks as the entry holds them, with no kit record
/// between the entry and the view (``ThoughtEntryBlock``). Only the views
/// that read `agentState` show that the agent works. The view of an entry
/// reads the content of the entry, so a streamed chunk evaluates only this
/// view. A thought and an agent message with the same `messageId` are two
/// entries, so they show in two rows.
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

  /// The reasoning that the view shows.
  private enum Source {
    /// A reasoning record, with its in-progress state and its stream.
    case record(Reasoning, isInProgress: Bool, streaming: StreamingMessage?)

    /// A thought entry of a session transcript.
    case entry(ThoughtEntry)
  }

  /// The reasoning to show.
  private let source: Source

  /// Makes a reasoning block.
  ///
  /// - Parameters:
  ///   - record: The reasoning to show.
  ///   - isInProgress: `true` while the agent still writes the reasoning.
  ///   - streaming: The stream of the reasoning, or `nil` when it does not
  ///     stream. Give `thread.streaming[record.id]`.
  public init(record: Reasoning, isInProgress: Bool, streaming: StreamingMessage? = nil) {
    self.source = .record(record, isInProgress: isInProgress, streaming: streaming)
  }

  /// Makes the reasoning block of a thought entry of a session transcript.
  ///
  /// The block has the complete look, also while the agent runs.
  ///
  /// - Parameter entry: The thought to show.
  public init(entry: ThoughtEntry) {
    self.source = .entry(entry)
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

  /// The label that VoiceOver reads for a block (plan.md §6).
  ///
  /// - Parameters:
  ///   - isInProgress: Whether the agent still reasons.
  ///   - duration: The time of the reasoning, or `nil` when it is not known.
  /// - Returns: "Reasoning, in progress" while in progress, "Reasoning, N
  ///   seconds" with N rounded to whole seconds when complete, or
  ///   "Reasoning" when complete with no known time.
  public static func accessibilityLabel(isInProgress: Bool, duration: TimeInterval?) -> String {
    if isInProgress {
      return String(localized: "Reasoning, in progress")
    }
    guard let duration else { return String(localized: "Reasoning") }
    let seconds = Int(duration.rounded())
    return String(localized: "Reasoning, \(seconds) seconds")
  }

  public var body: some View {
    switch source {
    case .record(let record, let isInProgress, let streaming):
      ReasoningBlock(
        id: record.id, isInProgress: isInProgress, duration: record.duration, policyEntry: nil
      ) {
        // The message id is the record id, because the code block cache and
        // the evaluation counter use it as a key.
        ResponseView(
          message: Message(id: record.id, blocks: [ContentBlock(text: record.text)]), streaming: streaming)
      }
    case .entry(let entry):
      ThoughtEntryBlock(entry: entry)
    }
  }
}

/// The collapsible block of one reasoning. See ``ReasoningView``.
///
/// The block shows a title, an expand button, and its content while it is
/// open. ``ReasoningView`` gives the text of a reasoning record as the
/// content, and ``ThoughtEntryBlock`` gives the ACP content of a thought
/// entry.
struct ReasoningBlock<Content: View>: View {
  /// The id of the reasoning. It keys the user decision in the store and
  /// the accessibility identifiers.
  let id: String

  /// `true` while the agent still writes the reasoning.
  let isInProgress: Bool

  /// The time of the reasoning, or `nil` when it is not known.
  let duration: TimeInterval?

  /// The transcript entry that the ``ExpandedBlocksStore/defaultExpanded``
  /// policy of the store reads, or `nil` when the policy does not apply. The
  /// policy takes a transcript entry, so a reasoning record has no policy.
  let policyEntry: TranscriptEntry?

  /// Makes the content of the open block. The block calls it in its body
  /// only while it is open, so a closed block does not read the values of
  /// the content.
  @ViewBuilder let content: () -> Content

  /// The store that the view uses when the environment has no store.
  @State private var ownStore = ExpandedBlocksStore()

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.agentTheme) private var theme

  var body: some View {
    let store = environmentStore ?? ownStore
    let expanded = isExpanded(in: store)
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header(store: store, expanded: expanded)
      if expanded {
        content()
          .foregroundStyle(.secondary)
          .contentContainer(identifier: ReasoningView.bodyIdentifier(for: id))
      }
    }
    .contentContainer(identifier: ReasoningView.identifier(for: id))
    .accessibilityLabel(
      ReasoningView.accessibilityLabel(isInProgress: isInProgress, duration: duration))
    // The row is a container with this block as its one child. The second
    // hidden child keeps SwiftUI from merging the block into the row, so
    // the block keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// Tells if the block is open.
  ///
  /// A block with a policy entry gives the entry to the store. A reasoning
  /// record has no transcript entry, so it gives its id.
  ///
  /// - Parameter store: The store of the user decisions.
  /// - Returns: The user decision. With no decision, `true` while in
  ///   progress, and when complete the store policy, or `false` with no
  ///   policy entry.
  private func isExpanded(in store: ExpandedBlocksStore) -> Bool {
    guard let policyEntry else {
      return store.decision(for: id) ?? isInProgress
    }
    return store.decision(for: policyEntry) ?? (isInProgress || store.defaultExpanded(policyEntry))
  }

  /// Records a user decision for the block.
  ///
  /// A block with a policy entry gives the entry to the store. A reasoning
  /// record has no transcript entry, so it gives its id.
  ///
  /// - Parameters:
  ///   - expanded: `true` to open the block, `false` to close it.
  ///   - store: The store of the user decisions.
  private func setExpanded(to expanded: Bool, in store: ExpandedBlocksStore) {
    guard let policyEntry else {
      if expanded { store.expand(id: id) } else { store.collapse(id: id) }
      return
    }
    if expanded { store.expand(entry: policyEntry) } else { store.collapse(entry: policyEntry) }
  }

  /// The title and the expand button.
  ///
  /// - Parameters:
  ///   - store: The store of the user decisions.
  ///   - expanded: `true` while the block is open.
  /// - Returns: The header view.
  private func header(store: ExpandedBlocksStore, expanded: Bool) -> some View {
    let toggle = { setExpanded(to: !expanded, in: store) }
    return HStack(spacing: theme.spacing.s) {
      title
      Spacer(minLength: theme.spacing.s)
      Button(action: toggle) {
        Image(systemName: "chevron.right")
          .fontWeight(theme.symbolWeight)
          .rotationEffect(expanded ? ReasoningView.expandedChevronAngle : .zero)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(
        expanded ? Text("Hide reasoning") : Text("Show reasoning")
      )
      .accessibilityIdentifier(ReasoningView.toggleIdentifier(for: id))
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: toggle)
  }

  /// The shimmer while in progress, or the complete title.
  @ViewBuilder private var title: some View {
    if isInProgress {
      ShimmerView(text: ActivityIndicator.thinkingText)
    } else {
      Text(ReasoningView.completedTitle(duration: duration))
        .foregroundStyle(.secondary)
        .accessibilityIdentifier(ReasoningView.titleIdentifier(for: id))
    }
  }
}
