import SwiftUI

/// The sender of a message item (plan.md §9 A2).
public enum MessageRole: Sendable, Hashable, CaseIterable {
  /// A message from the user.
  case user

  /// A message from the agent.
  case assistant

  /// The start of the accessibility identifier of each message of the role.
  public var messageIdentifierPrefix: String {
    switch self {
    case .user: "user-message-"
    case .assistant: "assistant-message-"
    }
  }

  /// The accessibility identifier of the message of `id`.
  ///
  /// - Parameter id: The identifier of the message record.
  /// - Returns: `user-message-<id>` or `assistant-message-<id>`.
  public func messageIdentifier(for id: String) -> String {
    AccessibilityIdentifier.make(prefix: messageIdentifierPrefix, value: id)
  }

  /// The name of the sender that the header shows.
  public var title: String {
    switch self {
    case .user: String(localized: "You")
    case .assistant: String(localized: "Assistant")
    }
  }

  /// The accessibility label of a message of the role.
  public var accessibilityLabel: String {
    switch self {
    case .user: String(localized: "You said")
    case .assistant: String(localized: "Assistant said")
    }
  }
}

/// The header of a message item: the name of the sender and a relative time
/// (plan.md §9 A2).
///
/// When the date is `nil`, the header shows only the name.
public struct MessageHeader: View {
  /// The accessibility identifier of the name of the sender.
  public static let roleIdentifier = "message-header-role"

  /// The accessibility identifier of the relative time.
  public static let dateIdentifier = "message-header-date"

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  @Environment(\.agentTheme) private var theme

  /// Makes the header of a message.
  ///
  /// - Parameters:
  ///   - role: The sender of the message.
  ///   - date: The time of the message, or `nil` when it is not known.
  public init(role: MessageRole, date: Date? = nil) {
    self.role = role
    self.date = date
  }

  /// The relative time that the header shows for `date`.
  ///
  /// - Parameters:
  ///   - date: The time of the message.
  ///   - now: The time to compare with.
  /// - Returns: A named relative time, such as "2 minutes ago".
  public static func relativeText(for date: Date, now: Date = .now) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.dateTimeStyle = .named
    return formatter.localizedString(for: date, relativeTo: now)
  }

  public var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: theme.spacing.s) {
      Text(role.title)
        .font(theme.proseFont.weight(.semibold))
        .accessibilityIdentifier(Self.roleIdentifier)
      if let date {
        Text(Self.relativeText(for: date))
          .font(theme.proseFont)
          .foregroundStyle(.secondary)
          .accessibilityIdentifier(Self.dateIdentifier)
      }
    }
  }
}
