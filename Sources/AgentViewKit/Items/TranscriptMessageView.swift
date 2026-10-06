import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The shared body of ``UserMessageView`` and ``AssistantMessageView`` for a
/// transcript entry of a `SessionModel` (update.md §4.2).
///
/// The view shows the ACP content blocks of the entry in a
/// ``MessageLayout``, keyed by the
/// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey`` of the entry.
///
/// The view shows the content as the session model holds it in the entry,
/// through ``EntryContentView``. It keeps no copy of the content, makes no
/// kit record of it, and keeps no stream. It does not find from `agentState`
/// whether the entry streams. Each evaluation joins the text chunks and
/// splits the text into paragraphs again (``ParagraphSplitter``). A paragraph
/// that did not change keeps its view, so a chunk evaluates only the last
/// paragraph.
///
/// The ``SwiftUI/EnvironmentValues/messageFooter`` slot takes a kit message,
/// so an entry shows no footer.
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
    return MessageLayout(id: key, role: role, date: date) {
      EntryContentView(content: content, id: key)
    }
  }
}
