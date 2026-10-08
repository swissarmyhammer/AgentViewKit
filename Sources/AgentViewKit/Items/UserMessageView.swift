import FoundationModelsACPClient
import SwiftUI

/// The default view of a user message entry (plan.md §9 A2).
///
/// The view shows a ``MessageHeader``, the content blocks of the message, and
/// the ``SwiftUI/EnvironmentValues/messageFooter`` slot with the entry
/// object.
///
/// The view shows a `UserMessageEntry` of a `SessionModel` (plan.md §3.2).
/// The view reads the content of the entry, so a change to the entry
/// evaluates only this view. Its identifier uses the row key of the entry,
/// which does not change when a pending message gets its `messageId`.
///
/// The view is an accessibility container with the identifier
/// `user-message-<id>` and the label "You said".
public struct UserMessageView: View, PrefixedAccessibilityIdentifier {
  /// The start of the accessibility identifier of each user message.
  public static var identifierPrefix: String { MessageRole.user.messageIdentifierPrefix }

  /// The user message entry to show.
  let entry: UserMessageEntry

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// Makes the view of a user message entry of a session transcript.
  ///
  /// - Parameters:
  ///   - entry: The entry to show.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(entry: UserMessageEntry, date: Date? = nil) {
    self.entry = entry
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
    VStack(alignment: .leading, spacing: theme.spacing.xs) {
      TranscriptMessageView(entry: .user(entry), date: date)
      SendStateLabel(state: entry.sendState)
        .accessibilityIdentifier(Self.sendStateIdentifier(for: entry.id.rowKey))
    }
  }

  /// The send state of a user message entry: pending, sent, or failed
  /// (plan.md §3.2 "Prompt helper").
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
