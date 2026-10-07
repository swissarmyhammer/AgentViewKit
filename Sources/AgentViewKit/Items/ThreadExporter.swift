import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// Writes a thread, a session transcript or a message as a Markdown document
/// (plan.md §9 A).
///
/// ``MessageActions`` uses this type for Copy and for Export. The output is
/// the same for equal records, so a test can compare it with a golden file.
///
/// The document of a session transcript has only the message entries (the
/// transcript form of `markdown(for:)`). The document of a deprecated
/// thread has one section for each item that it shows, in thread order. A
/// blank line separates two sections:
///
/// - A user message or an assistant message: a level 2 heading with the
///   sender, a blank line, and the Markdown that the message form of
///   `markdown(for:)` gives.
/// - A reasoning item: the text as a quoted block.
/// - A tool call: a fenced JSON summary with the title, the kind, the status,
///   the locations, the input, and the output.
///
/// The document omits the errors and the unknown items.
public enum ThreadExporter {
  /// The language of each fenced JSON block.
  static let jsonLanguage = "json"

  /// The shortest fence of a code block.
  static let minimumFenceLength = 3

  /// The Markdown document of a thread.
  ///
  /// - Parameter thread: The thread.
  /// - Returns: The document, with a line break at the end. The document is
  ///   empty when the thread has no item that the document shows.
  public static func markdown(for thread: AgentThread) -> String {
    let sections = thread.items.compactMap(section(for:))
    guard !sections.isEmpty else { return "" }
    return sections.joined(separator: "\n\n") + "\n"
  }

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

  /// The Markdown document of the model of a conversation.
  ///
  /// Export and Copy thread of ``MessageActions`` take the model in the same
  /// form: Export calls this function, and Copy thread calls
  /// `AgentCommandTarget.plainText(of:)`.
  ///
  /// - Parameter source: The model: a session model or a deprecated thread.
  /// - Returns: The transcript form of `markdown(for:)` for the transcript of
  ///   a session model, or the thread form for a thread.
  static func markdown(for source: ConversationSource) -> String {
    switch source {
    case .session(let session): markdown(for: session.transcript)
    case .thread(let thread): markdown(for: thread)
    }
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

  /// The Markdown of one message.
  ///
  /// The text is each text block that is for the user, in message order. A
  /// blank line separates two blocks. The text omits the other blocks.
  ///
  /// - Parameter message: The message.
  /// - Returns: The Markdown, or an empty string when the message has no
  ///   block that the text shows.
  public static func markdown(for message: Message) -> String {
    message.blocks.visible(to: .user).compactMap { block -> String? in
      switch block.content {
      case .text(let text):
        text
      case .image, .audio, .resourceLink, .resource, .attachment, .unknown:
        nil
      }
    }
    .joined(separator: "\n\n")
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

  /// The section of one item.
  ///
  /// - Parameter item: The item.
  /// - Returns: The section, or `nil` when the document does not show the
  ///   item.
  private static func section(for item: ThreadItem) -> String? {
    switch item {
    case .userMessage(let message):
      messageSection(message, role: .user)
    case .assistantMessage(let message):
      messageSection(message, role: .assistant)
    case .reasoning(let reasoning):
      quoted(reasoning.text)
    case .toolCall(let call):
      fenced(toolCallSummary(call).prettyPrinted)
    case .error, .unknown:
      nil
    }
  }

  /// The section of a message: the heading, then the Markdown of the
  /// message.
  ///
  /// - Parameters:
  ///   - message: The message.
  ///   - role: The sender of the message.
  /// - Returns: The section, or `nil` when the message has no Markdown.
  private static func messageSection(_ message: Message, role: MessageRole) -> String? {
    let body = markdown(for: message)
    guard !body.isEmpty else { return nil }
    return heading(for: role) + "\n\n" + body
  }

  /// The text as a Markdown quoted block.
  ///
  /// - Parameter text: The text.
  /// - Returns: Each line with `> ` at the start, or `>` for an empty line.
  ///   `nil` when the text is empty.
  static func quoted(_ text: String) -> String? {
    guard !text.isEmpty else { return nil }
    return text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.isEmpty ? ">" : "> " + $0 }
      .joined(separator: "\n")
  }

  /// The text as a fenced JSON block.
  ///
  /// The fence is longer than each run of backticks in the text, so that
  /// the text cannot close the block.
  ///
  /// - Parameter text: The JSON text.
  /// - Returns: The fenced block.
  static func fenced(_ text: String) -> String {
    let length = max(minimumFenceLength, longestBacktickRun(in: text) + 1)
    let fence = String(repeating: "`", count: length)
    return fence + jsonLanguage + "\n" + text + "\n" + fence
  }

  /// The length of the longest run of backticks in `text`.
  ///
  /// - Parameter text: The text to examine.
  /// - Returns: The length, or zero when the text has no backtick.
  private static func longestBacktickRun(in text: String) -> Int {
    var longest = 0
    var current = 0
    for character in text {
      current = character == "`" ? current + 1 : 0
      longest = max(longest, current)
    }
    return longest
  }

  /// The JSON summary of a tool call.
  ///
  /// The summary omits the input and the output when the call has none, and
  /// the locations when the list is empty.
  ///
  /// - Parameter call: The tool call.
  /// - Returns: An object with the keys `title`, `kind`, `status`, and, when
  ///   present, `locations`, `input`, and `output`.
  static func toolCallSummary(_ call: ToolCallRecord) -> JSONValue {
    var summary: [String: JSONValue] = [
      "title": .string(call.title),
      "kind": .string(call.kind.wireValue),
      "status": .string(call.status.wireValue),
    ]
    if !call.locations.isEmpty {
      summary["locations"] = .array(call.locations.map { .string(locationText($0)) })
    }
    if let rawInput = call.rawInput {
      summary["input"] = rawInput
    }
    if let rawOutput = call.rawOutput {
      summary["output"] = rawOutput
    }
    return .object(summary)
  }

  /// The text of a location: the path, with `:<line>` when the line is
  /// known.
  ///
  /// - Parameter location: The location.
  /// - Returns: The text.
  private static func locationText(_ location: ToolCallLocation) -> String {
    guard let line = location.line else { return location.path }
    return "\(location.path):\(line)"
  }
}
