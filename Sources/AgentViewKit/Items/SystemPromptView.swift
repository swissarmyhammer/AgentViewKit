import SwiftUI

/// The default view of a system prompt item: a block labelled
/// "Instructions" that the user can open (plan.md §9 A2).
///
/// The block is closed by default. The user decision is in the
/// ``ExpandedBlocksStore`` of the environment, keyed by the record id. A
/// block with no user decision uses the
/// ``ExpandedBlocksStore/defaultExpanded`` policy of the store, which is
/// closed by default. When the environment has no store, the view uses a
/// store of its own.
///
/// The open block shows the text through ``ResponseView``. While the text
/// streams, the view uses the stream of the thread of the environment.
public struct SystemPromptView: View {
  /// The accessibility identifier of the block.
  public static let identifier = "system-prompt"

  /// The accessibility identifier of the expand button.
  public static let toggleIdentifier = identifier + "-toggle"

  /// The accessibility identifier of the text of the open block.
  public static let bodyIdentifier = identifier + "-body"

  /// The record to show.
  let record: SystemPrompt

  /// The store that the view uses when the environment has no store.
  @State private var ownStore = ExpandedBlocksStore()

  @Environment(\.expandedBlocksStore) private var environmentStore
  @Environment(\.agentThread) private var thread
  @Environment(\.agentTheme) private var theme

  /// Makes the view of a system prompt.
  ///
  /// - Parameter record: The instructions to show.
  public init(record: SystemPrompt) {
    self.record = record
  }

  /// The title of the block.
  public static var title: String { String(localized: "Instructions") }

  public var body: some View {
    let store = environmentStore ?? ownStore
    let expanded = store.decision(for: record.id) ?? store.defaultExpanded(.system(record))
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      header(store: store, expanded: expanded)
      if expanded {
        ResponseView(message: bodyMessage, streaming: thread?.streaming[record.id])
          .foregroundStyle(.secondary)
          .contentContainer(identifier: Self.bodyIdentifier)
      }
    }
    .contentContainer(identifier: Self.identifier)
    .accessibilityLabel(Self.title)
    // The row is a container with this block as its one child. The second
    // hidden child keeps SwiftUI from merging the block into the row, so
    // the block keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The message that holds the text of the instructions.
  ///
  /// The message id is the record id, because the code block cache and the
  /// evaluation counter use it as a key.
  private var bodyMessage: Message {
    Message(id: record.id, blocks: [ContentBlock(text: record.text)])
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
      Text(Self.title)
        .font(theme.proseFont)
        .foregroundStyle(.secondary)
      Spacer(minLength: theme.spacing.s)
      Button(action: toggle) {
        Image(systemName: "chevron.right")
          .fontWeight(theme.symbolWeight)
          .rotationEffect(expanded ? ReasoningView.expandedChevronAngle : .zero)
      }
      .buttonStyle(.borderless)
      .accessibilityLabel(
        expanded ? Text("Hide instructions") : Text("Show instructions")
      )
      .accessibilityIdentifier(Self.toggleIdentifier)
    }
    .contentShape(Rectangle())
    .onTapGesture(perform: toggle)
  }
}
