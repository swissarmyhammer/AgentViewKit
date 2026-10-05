import FoundationModelsACPClient
import SwiftUI

/// The default view of a user message item (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message
/// through ``ContentBlockView``, and the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot. While the message
/// streams, the text shows through ``ResponseView`` with the stream of the
/// thread of the environment.
///
/// The view shows a thread message or a `UserMessageEntry` of a
/// `SessionModel` (update.md §4.2). The view of an entry reads the content of
/// the entry, so a change to the entry evaluates only this view. Its
/// identifier uses the row key of the entry, which does not change when a
/// pending message gets its `messageId`.
///
/// The view is an accessibility container with the identifier
/// `user-message-<id>` and the label "You said".
public struct UserMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each user message.
  public static var identifierPrefix: String { MessageRole.user.messageIdentifierPrefix }

  /// The message that the view shows.
  private enum Source {
    /// A message of a thread.
    case message(Message)

    /// A user message entry of a session transcript.
    case entry(UserMessageEntry)
  }

  /// The message to show.
  private let source: Source

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// Makes the view of a user message.
  ///
  /// - Parameters:
  ///   - message: The message to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(message: Message, date: Date? = nil) {
    self.source = .message(message)
    self.date = date
  }

  /// Makes the view of a user message entry of a session transcript.
  ///
  /// - Parameters:
  ///   - entry: The entry to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(entry: UserMessageEntry, date: Date? = nil) {
    self.source = .entry(entry)
    self.date = date
  }

  public var body: some View {
    switch source {
    case .message(let message):
      MessageItemView(message: message, role: .user, date: date)
    case .entry(let entry):
      TranscriptMessageView(id: entry.id, content: entry.content, role: .user, date: date, canStream: false)
    }
  }
}
