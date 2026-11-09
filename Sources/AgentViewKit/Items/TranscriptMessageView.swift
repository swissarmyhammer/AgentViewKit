import EditorStyle
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
/// Below the message, the view shows its accessory, such as the send state
/// of a user message.
///
/// In an agent command scope, the view is in the item scope
/// `agentMessage:<rowKey>`, with the context menu of that scope (AVK-1). The
/// scope gives the `TranscriptEntry` of the message as its live subject. The
/// scope holds the whole row: the header, the content, the footer and the
/// accessory, so the focus ring of the scope goes around all of them. The
/// row has an inner padding of ``ringInset`` in each state, so the ring
/// stands off the text, and the text of a focused row stands where the text
/// of a row with no focus stands. The padding is part of the frame of the
/// row, so the frame of the row holds its ring, and a move that puts the row
/// below a bar also puts its ring below the bar.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct TranscriptMessageView<Accessory: View>: View {
  /// The step of the spacing scale between the row and the area of its item
  /// scope, where the focus ring stands. It is less than the space between
  /// two rows of a thread (`tile.margin`), so the ring of a focused row does
  /// not touch the next row.
  static var ringInset: KeyPath<EditorStyle.Spacing, CGFloat> { \.xs }

  /// The message entry to show.
  let entry: MessageEntry

  /// The view below the message, in the item scope.
  @ViewBuilder let accessory: Accessory

  @Environment(\.messageFooter) private var footer
  @Environment(\.editorStyle) private var editorStyle

  /// Makes the view of a message entry, with an accessory below it.
  ///
  /// - Parameters:
  ///   - entry: The message entry to show.
  ///   - accessory: The view below the message.
  init(entry: MessageEntry, @ViewBuilder accessory: () -> Accessory) {
    self.entry = entry
    self.accessory = accessory()
  }

  var body: some View {
    let key = entry.id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    let inset = editorStyle.spacing[keyPath: Self.ringInset]
    return VStack(alignment: .leading, spacing: editorStyle.spacing.xs) {
      MessageLayout(id: key, role: entry.role) {
        EntryContentView(content: entry.content, id: key)
        if let footer {
          footer(entry)
        }
      }
      accessory
    }
    .padding(inset)
    .agentItemScope(AgentScopeKind.message(rowKey: key), subject: entry.transcriptEntry)
  }
}

extension TranscriptMessageView where Accessory == EmptyView {
  /// Makes the view of a message entry with no accessory.
  ///
  /// - Parameter entry: The message entry to show.
  init(entry: MessageEntry) {
    self.init(entry: entry) {}
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
