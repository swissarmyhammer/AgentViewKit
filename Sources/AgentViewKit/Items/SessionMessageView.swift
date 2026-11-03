import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// The default view of a message between two sessions of the same agent.
///
/// The view shows a line that names the sender and the recipient session, and
/// the content blocks of the message. It reads the entry object each time that
/// it draws, and it keeps no copy. A session that the agent did not name shows
/// as "another session".
///
/// The view is an accessibility container with the identifier
/// `session-message-<id>`.
public struct SessionMessageView: View {
  /// The start of the accessibility identifier of each session message.
  public static let identifierPrefix = "session-message-"

  /// The space between the line of the participants and the content.
  private static let spacing: CGFloat = 4

  /// The entry to show.
  let entry: SessionMessageEntry

  /// Makes the view of a session message entry.
  ///
  /// - Parameter entry: The entry to show.
  public init(entry: SessionMessageEntry) {
    self.entry = entry
  }

  /// The line that names the two sessions.
  ///
  /// - Parameters:
  ///   - sender: The id of the sender session, or `nil`.
  ///   - recipient: The id of the recipient session, or `nil`.
  /// - Returns: Text such as "From s1 to s2".
  static func participantsText(sender: SessionId?, recipient: SessionId?) -> String {
    let other = String(localized: "another session", bundle: .module)
    let from = sender?.rawValue ?? other
    let to = recipient?.rawValue ?? other
    return String(localized: "From \(from) to \(to)", bundle: .module)
  }

  /// The line of the participants, and the content of the message.
  public var body: some View {
    let participants = Self.participantsText(
      sender: entry.senderSessionId, recipient: entry.recipientSessionId)
    VStack(alignment: .leading, spacing: Self.spacing) {
      Text(participants)
        .font(.caption)
        .foregroundStyle(.secondary)
      EntryContentView(content: entry.content, id: "\(Self.identifierPrefix)\(entry.messageId.rawValue)")
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(participants)
    .accessibilityIdentifier("\(Self.identifierPrefix)\(entry.messageId.rawValue)")
  }
}
