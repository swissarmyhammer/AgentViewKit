import FoundationModelsACPClient
import SwiftUI

/// The default view of a user message item (plan.md §9 A2).
///
/// The view shows a ``MessageHeader`` and the content blocks of the message.
/// The view of an entry also shows the
/// ``SwiftUI/EnvironmentValues/messageFooter`` slot with the entry object.
/// While a thread message streams, the text shows through ``ResponseView``
/// with the stream of the thread of the environment.
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

  /// The end of the accessibility identifier of the send state of an entry.
  private static let sendStateSuffix = "-send-state"

  /// The accessibility identifier of the send state of a user message entry.
  ///
  /// - Parameter id: The row key of the entry.
  /// - Returns: `user-message-<id>-send-state`.
  public static func sendStateIdentifier(for id: String) -> String {
    identifier(for: id) + sendStateSuffix
  }

  @Environment(\.agentTheme) private var theme

  public var body: some View {
    switch source {
    case .message(let message):
      ThreadMessageItemView(message: message, role: .user, date: date)
    case .entry(let entry):
      VStack(alignment: .leading, spacing: theme.spacing.xs) {
        TranscriptMessageView(entry: .user(entry), date: date)
        SendStateLabel(state: entry.sendState)
          .accessibilityIdentifier(Self.sendStateIdentifier(for: entry.id.rowKey))
      }
    }
  }

  /// The send state of a user message entry: pending, sent, or failed
  /// (update.md §4.2 "Prompt helper").
  ///
  /// The label is one accessibility element. Its label is the title of the
  /// state.
  private struct SendStateLabel: View {
    /// The send state to show.
    let state: SendState

    @Environment(\.agentTheme) private var theme

    /// The text of a send state.
    ///
    /// - Parameter state: The send state.
    /// - Returns: "Sending", "Sent", or "Not sent".
    static func title(of state: SendState) -> String {
      switch state {
      case .pending: String(localized: "Sending")
      case .sent: String(localized: "Sent")
      case .failed: String(localized: "Not sent")
      }
    }

    /// The SF Symbol of a send state.
    ///
    /// - Parameter state: The send state.
    /// - Returns: A clock, a check mark, or a warning sign.
    static func symbol(of state: SendState) -> String {
      switch state {
      case .pending: "clock"
      case .sent: "checkmark"
      case .failed: "exclamationmark.triangle"
      }
    }

    var body: some View {
      Label(Self.title(of: state), systemImage: Self.symbol(of: state))
        .font(.caption)
        .fontWeight(theme.symbolWeight)
        .foregroundStyle(theme.statusColors.color(for: state))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Self.title(of: state))
    }
  }
}
