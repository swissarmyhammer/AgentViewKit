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
/// In an agent command scope, the view is in the item scope
/// `agentMessage:<rowKey>`, with the context menu of that scope (AVK-1). The
/// scope gives the `TranscriptEntry` of the message as its live subject.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct TranscriptMessageView: View {
  /// The message entry to show.
  let entry: MessageEntry

  @Environment(\.messageFooter) private var footer

  var body: some View {
    let key = entry.id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    return MessageLayout(id: key, role: entry.role) {
      EntryContentView(content: entry.content, id: key)
      if let footer {
        footer(entry)
      }
    }
    .agentItemScope(AgentScopeKind.message(rowKey: key), subject: entry.transcriptEntry)
  }
}

// MARK: - Previews

/// One message of the previews, in a narrow column that wraps its text.
private struct TranscriptMessageSample: View {
  /// The state of the message.
  let sample: PreviewFixtures.MessageSample

  var body: some View {
    if let entry = sample.entry {
      TranscriptMessageView(entry: entry)
        .frame(width: PreviewFixtures.narrowWidth)
        .padding()
    }
  }
}

#Preview("A user message") {
  TranscriptMessageSample(sample: .user)
}

#Preview("An agent message") {
  TranscriptMessageSample(sample: .agent)
}

#Preview("An agent message that streams") {
  TranscriptMessageSample(sample: .streaming)
}

#Preview("An agent message that reports an error") {
  TranscriptMessageSample(sample: .failure)
}

#Preview("A very long agent message") {
  ScrollView {
    TranscriptMessageSample(sample: .long)
  }
}
