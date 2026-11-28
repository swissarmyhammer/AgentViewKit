import EditorStyle
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// A message entry of a session transcript: the observable entry object of a
/// user message or of an agent message (plan.md §3.2).
///
/// The value holds the object of the session model and no copy of its
/// values. The ``SwiftUI/EnvironmentValues/messageFooter`` slot gives it to
/// the footer of each message row, and ``MessageActions`` takes it.
public enum MessageEntry {
  /// A `UserMessageEntry` of the transcript.
  case user(UserMessageEntry)

  /// An `AgentMessageEntry` of the transcript.
  case agent(AgentMessageEntry)

  /// The message entry of a transcript entry, or `nil` for an entry that
  /// is not a message.
  ///
  /// - Parameter entry: The transcript entry.
  init?(_ entry: TranscriptEntry) {
    switch entry {
    case .userMessage(let message): self = .user(message)
    case .agentMessage(let message): self = .agent(message)
    case .thought, .toolCall, .terminal, .plan, .unknown, .error, .compaction, .sessionMessage: return nil
    }
  }

  /// The stable identity of the entry.
  public var id: TranscriptEntry.ID {
    switch self {
    case .user(let entry): entry.id
    case .agent(let entry): entry.id
    }
  }

  /// The transcript entry of the message: the case of `TranscriptEntry` that
  /// holds the same object.
  var transcriptEntry: TranscriptEntry {
    switch self {
    case .user(let entry): .userMessage(entry)
    case .agent(let entry): .agentMessage(entry)
    }
  }

  /// The sender of the message.
  var role: MessageRole {
    switch self {
    case .user: .user
    case .agent: .assistant
    }
  }

  /// The ACP `MessageId` of the message, or `nil` when the agent gave none
  /// yet, such as for a local user message before its echo.
  @MainActor var messageId: MessageId? {
    switch self {
    case .user(let entry): entry.messageId
    case .agent(let entry): entry.messageId
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

/// The footer of each message row, as ``SwiftUI/View/messageFooter(_:)``
/// sets it: the view of the footer of a message entry, and the kind of
/// that view (card ^grwk69d).
///
/// The kind sets the chrome rule of a message row in the height cache of a
/// thread (``TranscriptRowChrome``). A footer of ``MessageActions`` has a
/// rule: one line of buttons of a known height, which the flat form of a
/// static row draws as a chrome line. Each other footer is custom: the
/// cache cannot know its height, so it gives a message row with that
/// footer no height, and the row is not flat while the rows move.
public struct MessageFooter {
  /// The view of the footer of a message entry.
  let content: ItemViewRenderer<MessageEntry>

  /// The kind of the footer.
  let kind: MessageFooterKind

  /// Makes the footer of a function that makes a view of a message entry.
  ///
  /// The footer is a ``MessageFooterKind/messageActions`` footer when the
  /// function makes a ``MessageActions`` view and nothing else, else a
  /// ``MessageFooterKind/custom`` footer.
  ///
  /// - Parameter content: The function that makes the footer of a message
  ///   entry.
  init<Content: View>(@ViewBuilder _ content: @escaping @MainActor (MessageEntry) -> Content) {
    self.content = { entry in AnyView(content(entry)) }
    kind = Content.self == MessageActions.self ? .messageActions : .custom
  }
}

/// The kind of the footer of the message rows of a thread (card ^grwk69d).
nonisolated public enum MessageFooterKind: Hashable, Sendable {
  /// A ``MessageActions`` row: one line of buttons of a known height.
  case messageActions

  /// Another view, whose height no chrome rule knows.
  case custom
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
  @Entry public var messageFooter: MessageFooter? = nil
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
  /// A function that makes a ``MessageActions`` view and nothing else gives
  /// a footer of a known height, so the height cache of the thread covers
  /// the message rows (``MessageFooter``). With another footer, the message
  /// rows of the thread take the height of the last layout of their real
  /// rows while the rows move.
  ///
  /// - Parameter content: The function that makes the footer of a message
  ///   entry.
  /// - Returns: A view that gives the footer to its subtree.
  public func messageFooter<Content: View>(
    @ViewBuilder _ content: @escaping @MainActor (MessageEntry) -> Content
  ) -> some View {
    environment(\.messageFooter, MessageFooter(content))
  }
}

/// The layout of one message: the ``MessageHeader`` and then the content,
/// in one accessibility container.
///
/// ``TranscriptMessageView`` puts the ACP content and the footer of a
/// transcript entry in it.
///
/// Each paragraph of the message is in one linked reading group. The text of
/// the message is selectable through its content views, as part of the one
/// selection of the thread (Docs/decisions/text-selection.md).
struct MessageLayout<Content: View>: View {
  /// The id of the message, such as the row key of a transcript entry.
  let id: String

  /// The sender of the message.
  let role: MessageRole

  /// The content below the header.
  @ViewBuilder let content: Content

  @Environment(\.editorStyle) private var editorStyle

  var body: some View {
    VStack(alignment: .leading, spacing: editorStyle.spacing.s) {
      MessageHeader(role: role)
      content
    }
    // Each paragraph of the message is in one linked reading group, also
    // when the paragraphs are in more than one text block (plan.md §6).
    .environment(\.accessibilityMessageGroupID, id)
    .accessibilityReadingScope()
    .contentContainer(identifier: role.messageIdentifier(for: id))
    .accessibilityLabel(role.accessibilityLabel)
    // The row is a container with this view as its one child. The second
    // hidden child keeps SwiftUI from merging this view into the row, so
    // this view keeps its identifier. See `contentContainer(identifier:)`.
    .background { Color.clear.accessibilityHidden(true) }
  }
}

// MARK: - Previews

/// The layout of one message of the previews, with the content of its entry,
/// in a narrow column that wraps its text.
private struct MessageLayoutSample: View {
  /// The state of the message.
  let sample: PreviewFixtures.MessageSample

  var body: some View {
    if let entry = sample.entry {
      let key = entry.id.rowKey
      MessageLayout(id: key, role: entry.role) {
        EntryContentView(content: entry.content, id: key)
      }
      .frame(width: PreviewFixtures.narrowWidth)
      .padding()
    }
  }
}

#Preview("A user message") {
  MessageLayoutSample(sample: .user)
}

#Preview("An agent message") {
  MessageLayoutSample(sample: .agent)
}

#Preview("An agent message that streams") {
  MessageLayoutSample(sample: .streaming)
}

#Preview("An agent message that reports an error") {
  MessageLayoutSample(sample: .failure)
}

#Preview("A very long agent message") {
  EditorScrollView {
    MessageLayoutSample(sample: .long)
  }
}
