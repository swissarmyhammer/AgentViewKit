import FoundationModelsACPClient
import SwiftUI

/// The reasoning block of one thought entry of a session transcript
/// (update.md §4.2). See ``ReasoningView``.
///
/// The view reads the ACP content blocks of the entry, so a streamed chunk
/// evaluates only this view. The open block shows the content through
/// ``EntryContentView``, and the row key of the entry is the id of the
/// block. The view keeps no copy of the content, makes no kit record of it,
/// and keeps no stream. The block has the complete look. With no user
/// decision, it uses the ``ExpandedBlocksStore/defaultExpanded`` policy of
/// the store for the thought entry.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct ThoughtEntryBlock: View {
  /// The thought to show.
  let entry: ThoughtEntry

  var body: some View {
    let key = entry.id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    // The body reads the content of the entry also while the block is
    // closed, so that each chunk evaluates this view.
    let content = entry.content
    return ReasoningBlock(id: key, policyEntry: .thought(entry)) {
      EntryContentView(content: content, id: key)
    }
  }
}
