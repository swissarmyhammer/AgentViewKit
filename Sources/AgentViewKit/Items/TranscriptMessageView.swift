import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The shared body of ``UserMessageView`` and ``AssistantMessageView`` for a
/// transcript entry of a `SessionModel` (update.md §4.2).
///
/// The view shows the content of the entry as one message, keyed by the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of the entry.
///
/// The view shows the text as the session model holds it in the entry. It
/// keeps no copy of the text and no stream, and it does not find from
/// `agentState` whether the entry streams. Each evaluation splits the text of
/// the entry into paragraphs again (``ParagraphSplitter``). A paragraph that
/// did not change keeps its view, so a chunk evaluates only the last
/// paragraph.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct TranscriptMessageView: View {
  /// The identity of the entry.
  let id: TranscriptEntry.ID

  /// The content blocks of the entry.
  let content: [FoundationModelsACP.ContentBlock]

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  var body: some View {
    let key = id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    return MessageBodyView(
      message: Message(id: key, blocks: Self.messageBlocks(of: content)), role: role, date: date, streaming: nil)
  }

  /// The kit blocks of the content of an entry.
  ///
  /// The session model adds each streamed chunk of a message as one block.
  /// Thus each run of adjacent text blocks with the same annotations becomes
  /// one text block, with the texts joined with no separator. The message
  /// then shows the streamed text as one text, and not as one paragraph for
  /// each chunk.
  ///
  /// - Parameter content: The content blocks of the entry.
  /// - Returns: The kit blocks, in order.
  static func messageBlocks(
    of content: [FoundationModelsACP.ContentBlock]
  ) -> [AgentViewKit.ContentBlock] {
    content.map(SessionUpdateMapping.contentBlock).reduce(into: []) { append($1, to: &$0) }
  }

  /// Adds a block to the end of a list. A text block joins the last block
  /// when that block is text with the same annotations.
  ///
  /// - Parameters:
  ///   - block: The block to add.
  ///   - blocks: The list.
  private static func append(_ block: AgentViewKit.ContentBlock, to blocks: inout [AgentViewKit.ContentBlock]) {
    if let last = blocks.last, let joined = joinedText(last, block) {
      blocks[blocks.index(before: blocks.endIndex)] = joined
    } else {
      blocks.append(block)
    }
  }

  /// One text block with the text of two text blocks.
  ///
  /// - Parameters:
  ///   - first: The earlier block.
  ///   - second: The later block.
  /// - Returns: The joined block, or `nil` when a block is not text or the
  ///   annotations are different.
  private static func joinedText(
    _ first: AgentViewKit.ContentBlock, _ second: AgentViewKit.ContentBlock
  ) -> AgentViewKit.ContentBlock? {
    guard case .text(let firstText) = first.content, case .text(let secondText) = second.content,
      first.annotations == second.annotations
    else { return nil }
    return AgentViewKit.ContentBlock(content: .text(firstText + secondText), annotations: first.annotations)
  }
}
