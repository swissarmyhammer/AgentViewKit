import SwiftUI

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
/// - When the message does not stream, each block shows in a
///   ``ContentBlockView``, in message order.
/// - When the message streams, the text shows in one ``ResponseView`` with
///   the stream of the thread, and each block that is not text shows in a
///   ``ContentBlockView`` below it.
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
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      MessageHeader(role: role, date: date)
      if let streaming {
        ResponseView(message: message, streaming: streaming)
        blockViews(blocks.filter { $0.element.kind != .text })
      } else {
        blockViews(blocks)
      }
      if let footer {
        footer(message)
      }
    }
    .contentContainer(identifier: role.messageIdentifier(for: message.id))
    .accessibilityLabel(role.accessibilityLabel)
    // The row is a container with this view as its one child. The second
    // hidden child keeps SwiftUI from merging this view into the row, so
    // this view keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }

  /// The blocks of the message with their positions.
  private var blocks: [EnumeratedSequence<[ContentBlock]>.Element] {
    Array(message.blocks.enumerated())
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
