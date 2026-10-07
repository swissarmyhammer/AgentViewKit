import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Textual

/// A message entry of a session transcript: the observable entry object of a
/// user message or of an agent message (update.md §4.2).
///
/// The value holds the object of the session model and no copy of its
/// values. The ``SwiftUI/EnvironmentValues/messageFooter`` slot gives it to
/// the footer of each message row, and ``MessageActions`` takes it.
public enum MessageEntry {
  /// A `UserMessageEntry` of the transcript.
  case user(UserMessageEntry)

  /// An `AgentMessageEntry` of the transcript.
  case agent(AgentMessageEntry)

  /// The stable identity of the entry.
  public var id: TranscriptEntry.ID {
    switch self {
    case .user(let entry): entry.id
    case .agent(let entry): entry.id
    }
  }

  /// The sender of the message.
  var role: MessageRole {
    switch self {
    case .user: .user
    case .agent: .assistant
    }
  }

  /// The ACP content blocks of the entry, as the session model holds them.
  @MainActor var content: [FoundationModelsACP.ContentBlock] {
    switch self {
    case .user(let entry): entry.content
    case .agent(let entry): entry.content
    }
  }
}

extension EnvironmentValues {
  /// The footer of each message row: the `messageFooter` slot
  /// (plan.md §9 A2).
  ///
  /// ``UserMessageView`` and ``AssistantMessageView`` show the footer of a
  /// message entry below the content. The footer gets the entry object, so
  /// it reads the model directly. The value is `nil` by default, and the
  /// views then show no footer. Set the value with
  /// ``SwiftUI/View/messageFooter(_:)``.
  @Entry public var messageFooter: ItemViewRenderer<MessageEntry>? = nil
}

extension View {
  /// Sets the footer of each message row in this view.
  ///
  /// Give ``MessageActions`` for the message actions:
  ///
  /// ```swift
  /// AgentThreadView(session: session)
  ///   .messageFooter { entry in MessageActions(entry: entry) }
  /// ```
  ///
  /// - Parameter content: The function that makes the footer of a message
  ///   entry.
  /// - Returns: A view that gives the footer to its subtree.
  public func messageFooter<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (MessageEntry) -> Content
  ) -> some View {
    environment(\.messageFooter) { entry in AnyView(content(entry)) }
  }
}

/// The layout of one message: the ``MessageHeader`` and then the content,
/// in one accessibility container.
///
/// ``TranscriptMessageView`` puts the ACP content and the footer of a
/// transcript entry in it. ``MessageBodyView`` puts the blocks of a message of
/// the deprecated thread path in it.
///
/// The text of the message is selectable, one message at a time, and each
/// paragraph of the message is in one linked reading group.
struct MessageLayout<Content: View>: View {
  /// The id of the message, such as the row key of a transcript entry.
  let id: String

  /// The sender of the message.
  let role: MessageRole

  /// The time of the message, or `nil` when it is not known.
  let date: Date?

  /// The content below the header.
  @ViewBuilder let content: Content

  @Environment(\.agentTheme) private var theme

  var body: some View {
    VStack(alignment: .leading, spacing: theme.spacing.s) {
      MessageHeader(role: role, date: date)
      content
    }
    // Each paragraph of the message is in one linked reading group, also
    // when the paragraphs are in more than one text block (plan.md §6).
    .environment(\.accessibilityMessageGroupID, id)
    .accessibilityReadingScope()
    // The text of one message is selectable. A selection does not go into
    // the next message (Docs/decisions/text-selection.md).
    .textual.textSelection(.enabled)
    .contentContainer(identifier: role.messageIdentifier(for: id))
    .accessibilityLabel(role.accessibilityLabel)
    // The row is a container with this view as its one child. The second
    // hidden child keeps SwiftUI from merging this view into the row, so
    // this view keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }
}
