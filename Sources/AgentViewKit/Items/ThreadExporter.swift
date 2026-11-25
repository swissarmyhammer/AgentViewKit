import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// Writes the content of a message entry as Markdown, and reads the message
/// texts of a session transcript (plan.md §9 A).
///
/// ``MessageActions`` uses this type for Copy, the inspector for the text of
/// a message, and the item scope for the payload of a message. Export as
/// Markdown… (``AgentCommandVerb/exportMarkdown``) does not use it: its text
/// comes from `SessionModel.markdown(options:)` (``SessionMarkdownExport``).
/// The output is the same for equal entries, so a test can compare it with a
/// golden file.
///
/// The Stencil template `message-markdown` of the kit lays out the Markdown
/// of the content (`Docs/decisions/text-templates.md`). Copy Thread
/// (`AgentCommandTarget.plainText(of:)`) reads the message texts of a
/// transcript through ``messageTexts(in:)``, and its availability through
/// ``hasMessageText(in:)``.
public enum ThreadExporter {
  /// The Markdown of the content of a message entry.
  ///
  /// The text is each text block that is for the user, with each run of
  /// adjacent text chunks as one text, in content order (``texts(of:)``). A
  /// blank line separates two texts.
  ///
  /// - Parameter content: The ACP content blocks of the entry.
  /// - Returns: The Markdown, or an empty string when no block is text for
  ///   the user.
  public static func markdown(for content: [FoundationModelsACP.ContentBlock]) -> String {
    markdown(ofTexts: texts(of: content), templates: .bundled)
  }

  /// The Markdown of the texts of a message: the `message-markdown`
  /// template over the ``message(texts:heading:)`` value of the texts.
  ///
  /// - Parameters:
  ///   - texts: The texts of the message that are for the user, in content
  ///     order.
  ///   - templates: The templates of the Markdown.
  /// - Returns: The Markdown, or an empty string when `texts` is empty.
  static func markdown(ofTexts texts: [String], templates: TextTemplates) -> String {
    templates.render(.messageMarkdown, model: ["message": message(texts: texts)])
  }

  /// The text of one message entry: its sender and its texts for the user.
  struct MessageText: Equatable {
    /// The sender of the message.
    let role: MessageRole

    /// The texts of the message that are for the user, in content order.
    let texts: [String]
  }

  // MARK: - Template models

  /// The model of a text template that lists messages
  /// (`copy-text.stencil`): `messages`, the ``message(texts:heading:)``
  /// value of each message.
  ///
  /// The copy text heads each message with its role line.
  ///
  /// - Parameters:
  ///   - messages: The messages, in transcript order.
  ///   - heading: The catalog text that heads a message of a sender.
  /// - Returns: The model.
  static func sections(of messages: [MessageText], heading: (MessageRole) -> String) -> [String: Any] {
    ["messages": messages.map { message(texts: $0.texts, heading: heading($0.role)) }]
  }

  /// The template value of one message: `texts`, and `heading` when the
  /// message has one. Stencil reads the value by these keys, so this
  /// function is the one place that names them.
  ///
  /// - Parameters:
  ///   - texts: The texts of the message that are for the user, in content
  ///     order.
  ///   - heading: The catalog text that heads the message, or `nil` for the
  ///     content of a message alone.
  /// - Returns: The value.
  private static func message(texts: [String], heading: String? = nil) -> [String: Any] {
    var value: [String: Any] = ["texts": texts]
    value["heading"] = heading
    return value
  }

  /// The text of each message entry of a transcript that has text for the
  /// user, in transcript order.
  ///
  /// The copy command (`AgentCommandTarget.plainText(of:)`) reads the
  /// transcript through this function.
  ///
  /// - Parameter transcript: The entries of `SessionModel.transcript`.
  /// - Returns: One value for each `UserMessageEntry` and each
  ///   `AgentMessageEntry` with text. The other entries give none.
  static func messageTexts(in transcript: [TranscriptEntry]) -> [MessageText] {
    transcript.compactMap { entry -> MessageText? in
      guard let message = message(of: entry) else { return nil }
      let shown = texts(of: message.content)
      return shown.isEmpty ? nil : MessageText(role: message.role, texts: shown)
    }
  }

  /// Tells if a transcript has a message entry with text for the user.
  ///
  /// The answer is the same as for `!messageTexts(in:).isEmpty`, and thus
  /// the same as for a copy text (`AgentCommandTarget.plainText(of:)`) that
  /// is not empty. The function renders no template, and it stops at the
  /// first message entry with text. Copy Thread reads its availability
  /// through this function.
  ///
  /// - Parameter transcript: The entries of `SessionModel.transcript`.
  /// - Returns: `true` when a `UserMessageEntry` or an `AgentMessageEntry`
  ///   has a text block for the user.
  static func hasMessageText(in transcript: [TranscriptEntry]) -> Bool {
    transcript.contains { entry in
      guard let message = message(of: entry) else { return false }
      return !texts(of: message.content).isEmpty
    }
  }

  /// The sender and the content of a message entry.
  ///
  /// - Parameter entry: An entry of a session transcript.
  /// - Returns: The sender and the content of a `UserMessageEntry` or an
  ///   `AgentMessageEntry`, or `nil` for another entry.
  private static func message(
    of entry: TranscriptEntry
  ) -> (role: MessageRole, content: [FoundationModelsACP.ContentBlock])? {
    switch entry {
    case .userMessage(let user): (.user, user.content)
    case .agentMessage(let agent): (.assistant, agent.content)
    case .thought, .toolCall, .terminal, .plan, .unknown, .compaction, .error, .sessionMessage: nil
    }
  }

  /// The text blocks of the content of an entry that are for the user, with
  /// each run of adjacent text chunks as one text.
  ///
  /// The adjacent text chunks join as the view shows them
  /// (``EntryContentView/joiningAdjacentText(in:)``).
  ///
  /// - Parameter content: The ACP content blocks of an entry.
  /// - Returns: The texts, in order.
  static func texts(of content: [FoundationModelsACP.ContentBlock]) -> [String] {
    EntryContentView.joiningAdjacentText(in: content).compactMap { block -> String? in
      guard block.isVisibleToUser, case .text(let text) = block else { return nil }
      return text.text
    }
  }

  /// The name of the sender of a message, from the string catalog.
  ///
  /// The copy text starts the role line of each message with it.
  ///
  /// - Parameters:
  ///   - role: The sender of the message.
  ///   - locale: The locale of the name.
  /// - Returns: `User` or `Assistant`.
  static func senderName(of role: MessageRole, locale: Locale) -> String {
    switch role {
    case .user: String(localized: "User", bundle: .module, locale: locale)
    case .assistant: String(localized: "Assistant", bundle: .module, locale: locale)
    }
  }
}
