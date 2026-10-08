import FoundationModelsACPClient
import SwiftUI

/// The shared body of ``UserMessageView`` and ``AssistantMessageView`` for a
/// transcript entry of a `SessionModel` (plan.md §3.2).
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
/// Below the content, the view shows the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot with the entry object,
/// when the environment has a footer.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct TranscriptMessageView: View {
  /// The message entry to show.
  let entry: MessageEntry

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  @Environment(\.messageFooter) private var footer

  var body: some View {
    let key = entry.id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    return MessageLayout(id: key, role: entry.role, date: date) {
      EntryContentView(content: entry.content, id: key)
      if let footer {
        footer(entry)
      }
    }
  }
}
