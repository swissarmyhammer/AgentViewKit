import FoundationModelsACPClient
import SwiftUI

/// The default view of an agent message entry (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message, and
/// the ``SwiftUI/EnvironmentValues/messageFooter`` slot with the entry
/// object.
///
/// The view shows an `AgentMessageEntry` of a `SessionModel` (update.md
/// §4.2). The view reads the content of the entry, so a streamed chunk
/// evaluates only this view. The view shows the text as the entry holds it,
/// with the same look while the agent runs and after it stops. Only the views
/// that read `agentState` show that the agent works.
///
/// The view is an accessibility container with the identifier
/// `assistant-message-<id>` and the label "Assistant said".
public struct AssistantMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each assistant message.
  public static var identifierPrefix: String { MessageRole.assistant.messageIdentifierPrefix }

  /// The agent message entry to show.
  let entry: AgentMessageEntry

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// Makes the view of an agent message entry of a session transcript.
  ///
  /// - Parameters:
  ///   - entry: The entry to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(entry: AgentMessageEntry, date: Date? = nil) {
    self.entry = entry
    self.date = date
  }

  public var body: some View {
    TranscriptMessageView(entry: .agent(entry), date: date)
  }
}
