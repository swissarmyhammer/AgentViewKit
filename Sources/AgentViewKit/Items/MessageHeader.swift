import EditorSwiftUI
import EditorTheme
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
    case .user: String(localized: "You", bundle: .module)
    case .assistant: String(localized: "Assistant", bundle: .module)
    }
  }

  /// The accessibility label of a message of the role.
  public var accessibilityLabel: String {
    switch self {
    case .user: String(localized: "You said", bundle: .module)
    case .assistant: String(localized: "Assistant said", bundle: .module)
    }
  }
}

/// The header of a message item: the name of the sender (plan.md §9 A2).
///
/// The header shows no time. The timing decorator shows the time of an entry:
/// ``SwiftUI/View/transcriptTiming(_:)`` on each row, or
/// ``SwiftUI/View/entryTiming(_:)`` on one view (``EntryTimingView``).
public struct MessageHeader: View {
  /// The accessibility identifier of the name of the sender.
  public static let roleIdentifier = "message-header-role"

  /// The sender of the message.
  let role: MessageRole

  @Environment(\.editorTheme) private var editorTheme

  /// Makes the header of a message.
  ///
  /// - Parameter role: The sender of the message.
  public init(role: MessageRole) {
    self.role = role
  }

  public var body: some View {
    Text(role.title)
      .font(editorTheme.proseFont.weight(.semibold))
      .accessibilityIdentifier(Self.roleIdentifier)
  }
}

#Preview("Message headers") {
  VStack(alignment: .leading) {
    ForEach(MessageRole.allCases, id: \.self) { role in
      MessageHeader(role: role)
    }
  }
}
