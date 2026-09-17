import SwiftUI

/// The default view of one text block (plan.md §4.2, §9 A2).
///
/// The view shows the text in a ``ResponseView`` with a message of its own.
/// The id of that message is the id of the block view, not the id of the
/// message that holds the block. The code block cache and the evaluation
/// counters use the message id, so two text blocks of one message must not
/// use the same id.
struct TextBlockView: View {
  /// The Markdown text of the block.
  let text: String

  /// The id of the block view, such as `<message id>-<block index>`.
  let id: String

  var body: some View {
    ResponseView(message: Message(id: id, blocks: [ContentBlock(text: text)]), streaming: nil)
  }
}
