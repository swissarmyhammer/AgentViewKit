import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// Writes a session transcript or the content of a message entry as a
/// Markdown document (plan.md §9 A).
///
/// ``MessageActions`` uses this type for Copy and for Export. The output is
/// the same for equal entries, so a test can compare it with a golden file.
///
/// The document of a session transcript has only the message entries (the
/// transcript form of `markdown(for:)`).
public enum ThreadExporter {
  /// The Markdown document of the message entries of a session transcript.
  ///
  /// The document has one section for each `UserMessageEntry` and each
  /// `AgentMessageEntry` that has text for the user, in transcript order: a
  /// level 2 heading with the sender, a blank line, and the Markdown of the
  /// content (the content form of `markdown(for:)`). A blank line separates
  /// two sections. The document omits the other entries. The function reads
  /// the entries each time, so a new entry of the model is in the next
  /// document.
  ///
  /// - Parameter transcript: The entries of `SessionModel.transcript`.
  /// - Returns: The document, with a line break at the end. The document is
  ///   empty when no entry has text for the user.
  public static func markdown(for transcript: [TranscriptEntry]) -> String {
    let sections = messageTexts(in: transcript).map { message in
      heading(for: message.role) + "\n\n" + message.texts.joined(separator: "\n\n")
    }
    guard !sections.isEmpty else { return "" }
    return sections.joined(separator: "\n\n") + "\n"
  }

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
    texts(of: content).joined(separator: "\n\n")
  }

  /// The text of one message entry: its sender and its texts for the user.
  struct MessageText: Equatable {
    /// The sender of the message.
    let role: MessageRole

    /// The texts of the message that are for the user, in content order.
    let texts: [String]
  }

  /// The text of each message entry of a transcript that has text for the
  /// user, in transcript order.
  ///
  /// The export and the copy command (`AgentCommandTarget.plainText(of:)`)
  /// read the transcript through this one function.
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
    case .thought, .toolCall, .terminal, .plan, .unknown, .compaction, .error: nil
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

  /// The heading of a message section.
  ///
  /// - Parameter role: The sender of the message.
  /// - Returns: `## User` or `## Assistant`.
  static func heading(for role: MessageRole) -> String {
    let title =
      switch role {
      case .user: String(localized: "User")
      case .assistant: String(localized: "Assistant")
      }
    return "## " + title
  }
}
