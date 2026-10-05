import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// Shows the text of one transcript entry, with a view-owned
/// ``StreamingMessage`` while the entry streams (update.md §4.6).
///
/// The session model keeps the whole text of each entry. The entry streams
/// while it is the last entry of the transcript and the agent runs
/// (`SessionModel.isLastWhileRunning(_:)`). While it streams, this view gives
/// each new text to its stream, so that the paragraph split and the Markdown
/// balance work on the text of this one entry. The stream keeps no session
/// state, and it goes away when the entry stops streaming.
///
/// - When the new text starts with the text of the stream, the stream gets
///   the new end as one chunk, and flushes it at once. The split then reads
///   only the text after the settled paragraphs.
/// - Other text, for example after a whole-message update, replaces the text
///   of the stream.
///
/// The view notes ``ItemRow/contentCounterKey(for:)`` of its entry in the
/// ``BodyEvaluationCounter``, because it is the view that the content of the
/// entry evaluates again.
struct EntryTextStream<Content: View>: View {
  /// The identity of the entry.
  let id: TranscriptEntry.ID

  /// The whole text of the entry.
  let text: String

  /// Whether the entry can stream. An agent message and a thought can, and a
  /// user message cannot.
  let canStream: Bool

  /// Makes the view of the entry from the stream, or `nil` while the entry
  /// does not stream, and from whether the entry streams.
  @ViewBuilder let content: (StreamingMessage?, Bool) -> Content

  /// The stream of the entry, or `nil` while the entry does not stream.
  @State private var stream: StreamingMessage?

  @Environment(\.sessionModel) private var session

  var body: some View {
    let key = id.rowKey
    #if DEBUG
      BodyEvaluationCounter.note(ItemRow.contentCounterKey(for: key))
    #endif
    let isLive = canStream && session?.isLastWhileRunning(id) == true
    return content(isLive ? stream : nil, isLive)
      .onChange(of: isLive, initial: true) { _, live in liveDidChange(to: live, key: key) }
      .onChange(of: text) { textDidChange() }
  }

  /// Makes the stream when the entry starts to stream, and removes it when the
  /// entry stops.
  ///
  /// - Parameters:
  ///   - live: Whether the entry streams now.
  ///   - key: The text key of the entry, which is the id of the stream.
  private func liveDidChange(to live: Bool, key: String) {
    stream = live ? StreamingMessage(id: key, text: text, interval: .zero) : nil
  }

  /// Gives the new text of the entry to the stream.
  private func textDidChange() {
    guard let stream else { return }
    if text.hasPrefix(stream.text) {
      stream.append(String(text.dropFirst(stream.text.count)))
      stream.flush()
    } else {
      stream.replace(text)
    }
  }
}
