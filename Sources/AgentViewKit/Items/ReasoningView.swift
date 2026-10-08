import FoundationModelsACPClient
import SwiftUI

/// The reasoning of the agent, as a collapsible block (plan.md §5, §9 B):
/// the view of a `ThoughtEntry` of a `SessionModel` (plan.md §3.2).
///
/// The block has the complete look: the title is "Thought". The session
/// model does not tell whether a thought is in progress, so the view shows
/// the ACP content blocks as the entry holds them, with no kit record between
/// the entry and the view (``ThoughtEntryBlock``). Only the views that read
/// `agentState` show that the agent works. The view reads the content of the
/// entry, so a streamed chunk evaluates only this view. A thought and an
/// agent message with the same `messageId` are two entries, so they show in
/// two rows.
///
/// The user decision is in the ``ExpandedBlocksStore`` of the environment,
/// keyed by the row key of the entry. A block with no user decision uses the
/// ``ExpandedBlocksStore/defaultExpanded`` policy of the store, which is
/// closed by default. When the environment has no store, the view uses a
/// store of its own.
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

  /// The thought entry to show.
  let entry: ThoughtEntry

  /// Makes the reasoning block of a thought entry of a session transcript.
  ///
  /// The block has the complete look, also while the agent runs.
  ///
  /// - Parameter entry: The thought to show.
  public init(entry: ThoughtEntry) {
    self.entry = entry
  }

  /// The accessibility identifier of the block of `id`.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `reasoning-<id>`.
  public static func identifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: identifierPrefix, value: id)
  }

  /// The accessibility identifier of the title of a complete block.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `reasoning-<id>-title`.
  public static func titleIdentifier(for id: String) -> String {
    identifier(for: id) + titleSuffix
  }

  /// The accessibility identifier of the expand button.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `reasoning-<id>-toggle`.
  public static func toggleIdentifier(for id: String) -> String {
    identifier(for: id) + toggleSuffix
  }

  /// The accessibility identifier of the body.
  ///
  /// - Parameter id: The row key of the entry.
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
    ThoughtEntryBlock(entry: entry)
  }
}

/// The collapsible block of one reasoning. See ``ReasoningView``.
///
/// The block shows the complete title, an expand button, and its content
/// while it is open. ``ThoughtEntryBlock`` gives the ACP content of a thought
/// entry.
struct ReasoningBlock<Content: View>: View {
  /// The id of the reasoning: the row key of the entry. It keys the
  /// accessibility identifiers.
  let id: String

  /// The transcript entry that keys the user decision in the store, and that
  /// the ``ExpandedBlocksStore/defaultExpanded`` policy of the store reads.
  let policyEntry: TranscriptEntry

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
    .accessibilityLabel(ReasoningView.accessibilityLabel(isInProgress: false, duration: nil))
    // The row is a container with this block as its one child. The second
    // hidden child keeps SwiftUI from merging the block into the row, so
    // the block keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// Tells if the block is open.
  ///
  /// - Parameter store: The store of the user decisions.
  /// - Returns: The user decision, or the store policy for the entry when
  ///   there is no decision.
  private func isExpanded(in store: ExpandedBlocksStore) -> Bool {
    store.isExpanded(entry: policyEntry)
  }

  /// The title and the expand button.
  ///
  /// - Parameters:
  ///   - store: The store of the user decisions.
  ///   - expanded: `true` while the block is open.
  /// - Returns: The header view.
  private func header(store: ExpandedBlocksStore, expanded: Bool) -> some View {
    let toggle = { store.toggle(entry: policyEntry) }
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

  /// The complete title.
  private var title: some View {
    Text(ReasoningView.completedTitle(duration: nil))
      .foregroundStyle(.secondary)
      .accessibilityIdentifier(ReasoningView.titleIdentifier(for: id))
  }
}
