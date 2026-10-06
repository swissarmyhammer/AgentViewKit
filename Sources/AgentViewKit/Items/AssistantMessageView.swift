import FoundationModelsACPClient
import SwiftUI

/// The default view of an assistant message item (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message
/// through ``ContentBlockView``, and the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot. While the message
/// streams, the text shows through ``ResponseView`` with the stream of the
/// thread of the environment.
///
/// The view shows a thread message or an `AgentMessageEntry` of a
/// `SessionModel` (update.md §4.2). The view of an entry reads the content of
/// the entry, so a streamed chunk evaluates only this view. The view shows the
/// text as the entry holds it, with the same look while the agent runs and
/// after it stops. Only the views that read `agentState` show that the agent
/// works.
///
/// ``ConversationView`` shows the turn summary above the first agent item of
/// a turn. Thus this view does not show the summary.
///
/// The view is an accessibility container with the identifier
/// `assistant-message-<id>` and the label "Assistant said".
public struct AssistantMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each assistant message.
  public static var identifierPrefix: String { MessageRole.assistant.messageIdentifierPrefix }

  /// The message that the view shows.
  private enum Source {
    /// A message of a thread.
    case message(Message)

    /// An agent message entry of a session transcript.
    case entry(AgentMessageEntry)
  }

  /// The message to show.
  private let source: Source

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// Makes the view of an assistant message.
  ///
  /// - Parameters:
  ///   - message: The message to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(message: Message, date: Date? = nil) {
    self.source = .message(message)
    self.date = date
  }

  /// Makes the view of an agent message entry of a session transcript.
  ///
  /// - Parameters:
  ///   - entry: The entry to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(entry: AgentMessageEntry, date: Date? = nil) {
    self.source = .entry(entry)
    self.date = date
  }

  public var body: some View {
    switch source {
    case .message(let message):
      MessageItemView(message: message, role: .assistant, date: date)
    case .entry(let entry):
      TranscriptMessageView(id: entry.id, content: entry.content, role: .assistant, date: date)
    }
  }
}
