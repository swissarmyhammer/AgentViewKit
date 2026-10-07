import SwiftUI

/// The shared body of ``UserMessageView`` and ``AssistantMessageView`` for a
/// message of the deprecated thread path (plan.md §9 A2).
///
/// The view shows a ``MessageHeader`` and the content blocks.
///
/// - When the message does not stream, each block shows in a
///   ``ContentBlockView``, in message order.
/// - When the message streams, the text shows in one ``ResponseView``, and
///   each block that is not text shows in a ``ContentBlockView`` below it.
///   The response view gets the stream of the thread.
///
/// The ``SwiftUI/EnvironmentValues/messageFooter`` slot takes a message entry
/// of a session transcript, so a message of a thread shows no footer.
///
/// The text of the message is selectable, one message at a time
/// (``MessageActions/selectionMode``).
///
/// This view, and not the row, reads the thread. Thus a chunk evaluates only
/// this view, and the row stays equal. In a scroll view that is not a
/// ``ConversationView``, apply ``SwiftUI/View/lazyResponseParagraphs(_:)``
/// to the scroll view content.
///
/// The view goes away with the kit session model.
struct ThreadMessageItemView: View {
  /// The message to show.
  let message: Message

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  @Environment(\.agentThread) private var thread

  var body: some View {
    MessageBodyView(
      message: message, role: role, date: date, streaming: thread?.streaming[message.id])
  }
}

/// The layout of one message of a thread: the header and the content blocks,
/// in a ``MessageLayout``.
///
/// The caller gives the stream of the message. ``ThreadMessageItemView``
/// reads it from the thread.
struct MessageBodyView: View {
  /// The message to show.
  let message: Message

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// The stream of the message, or `nil` when the message does not stream.
  let streaming: StreamingMessage?

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
    let blocks = Array(message.blocks.enumerated())
    MessageLayout(id: message.id, role: role, date: date) {
      if let streaming {
        ResponseView(message: message, streaming: streaming)
        blockViews(blocks.filter { $0.element.kind != .text })
      } else {
        blockViews(blocks)
      }
    }
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
