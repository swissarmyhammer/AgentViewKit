import SwiftUI
import Textual

extension EnvironmentValues {
  /// The footer of each message item: the `messageFooter` slot
  /// (plan.md §9 A2).
  ///
  /// ``UserMessageView`` and ``AssistantMessageView`` show the footer below
  /// the content. The value is `nil` by default, and the views then show no
  /// footer. Set the value with ``SwiftUI/View/messageFooter(_:)``.
  @Entry public var messageFooter: ItemViewRenderer<Message>? = nil
}

extension View {
  /// Sets the footer of each message item in this view.
  ///
  /// `MessageActions` fills this slot with the message actions.
  ///
  /// - Parameter content: The function that makes the footer of a message.
  /// - Returns: A view that gives the footer to its subtree.
  public func messageFooter<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (Message) -> Content
  ) -> some View {
    environment(\.messageFooter) { message in AnyView(content(message)) }
  }
}

/// The shared body of ``UserMessageView`` and ``AssistantMessageView``
/// (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks, and the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot.
///
/// - When the message does not stream and has no citation block, each block
///   shows in a ``ContentBlockView``, in message order.
/// - When the message streams or has a ``CitationPayload`` block, the text
///   shows in one ``ResponseView``, and each block that is not text shows in
///   a ``ContentBlockView`` below it. The response view gets the stream of
///   the thread, and it puts the citation pills in the text.
///
/// Each citation block shows below the other blocks, so the
/// ``SourcesView`` is the footer of the content. The view applies
/// ``SwiftUI/View/citationScope()``, so a pill of the message highlights a
/// row of the sources of the same message.
///
/// The text of the message is selectable, one message at a time
/// (``MessageActions/selectionMode``).
///
/// This view, and not the row, reads the thread. Thus a chunk evaluates only
/// this view, and the row stays equal. In a scroll view that is not a
/// ``ConversationView``, apply ``SwiftUI/View/lazyResponseParagraphs(_:)``
/// to the scroll view content.
struct MessageItemView: View {
  /// The message to show.
  let message: Message

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  @Environment(\.agentThread) private var thread
  @Environment(\.messageFooter) private var footer
  @Environment(\.agentTheme) private var theme

  /// The id of the view of the block at `index` of a message.
  ///
  /// - Parameters:
  ///   - messageID: The identifier of the message.
  ///   - index: The position of the block in the message.
  /// - Returns: `<message id>-<index>`.
  static func blockID(messageID: String, index: Int) -> String {
    "\(messageID)-\(index)"
  }

  var body: some View {
    let streaming = thread?.streaming[message.id]
    let ordered = orderedBlocks
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      MessageHeader(role: role, date: date)
      if streaming != nil || ordered.contains(where: \.element.isCitation) {
        ResponseView(message: message, streaming: streaming)
        blockViews(ordered.filter { $0.element.kind != .text })
      } else {
        blockViews(ordered)
      }
      if let footer {
        footer(message)
      }
    }
    .citationScope()
    // Each paragraph of the message is in one linked reading group, also
    // when the paragraphs are in more than one text block (plan.md §6).
    .environment(\.accessibilityMessageGroupID, message.id)
    .accessibilityReadingScope()
    // The text of one message is selectable. A selection does not go into
    // the next message (Docs/decisions/text-selection.md).
    .textual.textSelection(.enabled)
    .contentContainer(identifier: role.messageIdentifier(for: message.id))
    .accessibilityLabel(role.accessibilityLabel)
    // The row is a container with this view as its one child. The second
    // hidden child keeps SwiftUI from merging this view into the row, so
    // this view keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The blocks of the message with their positions. The citation blocks are
  /// last, and each group keeps the message order.
  private var orderedBlocks: [EnumeratedSequence<[ContentBlock]>.Element] {
    let enumerated = Array(message.blocks.enumerated())
    return enumerated.filter { !$0.element.isCitation } + enumerated.filter(\.element.isCitation)
  }

  /// One ``ContentBlockView`` for each block, keyed by its position.
  ///
  /// - Parameter blocks: The blocks to show, with their positions in the
  ///   message.
  /// - Returns: The block views.
  private func blockViews(
    _ blocks: [EnumeratedSequence<[ContentBlock]>.Element]
  ) -> some View {
    ForEach(blocks, id: \.offset) { index, block in
      ContentBlockView(block: block, id: Self.blockID(messageID: message.id, index: index))
    }
  }
}
