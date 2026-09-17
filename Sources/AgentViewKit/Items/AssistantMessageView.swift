import SwiftUI

/// The default view of an assistant message item (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message
/// through ``ContentBlockView``, and the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot. While the message
/// streams, the text shows through ``ResponseView`` with the stream of the
/// thread of the environment.
///
/// ``ConversationView`` shows the turn summary above the first agent item of
/// a turn. Thus this view does not show the summary.
///
/// The view is an accessibility container with the identifier
/// `assistant-message-<id>` and the label "Assistant said".
public struct AssistantMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each assistant message.
  public static var identifierPrefix: String { MessageRole.assistant.messageIdentifierPrefix }

  /// The message to show.
  let message: Message

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// Makes the view of an assistant message.
  ///
  /// - Parameters:
  ///   - message: The message to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(message: Message, date: Date? = nil) {
    self.message = message
    self.date = date
  }

  public var body: some View {
    MessageItemView(message: message, role: .assistant, date: date)
  }
}
