import Foundation

/// Writes a thread or a message as a Markdown document (plan.md §9 A).
///
/// ``MessageActions`` uses this type for Copy and for Export. The output is
/// the same for equal records, so a test can compare it with a golden file.
///
/// The document has one section for each item that it shows, in thread
/// order. A blank line separates two sections:
///
/// - A user message or an assistant message: a level 2 heading with the
///   sender, a blank line, and the Markdown that the message form of
///   `markdown(for:)` gives.
/// - A reasoning item: the text as a quoted block.
/// - A tool call: a fenced JSON summary with the title, the kind, the status,
///   the locations, the input, and the output.
/// - A structured item: a fenced JSON value with the schema name and the
///   payload.
///
/// The document omits the system prompt, the compaction markers, the errors,
/// and the unknown items.
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

  /// The Markdown of one message.
  ///
  /// The text is each text block that is for the user, and each structured
  /// block as a fenced JSON value, in message order. A blank line separates
  /// two blocks. The text omits the other blocks.
  ///
  /// - Parameter message: The message.
  /// - Returns: The Markdown, or an empty string when the message has no
  ///   block that the text shows.
  public static func markdown(for message: Message) -> String {
    message.blocks.visible(to: .user).compactMap { block -> String? in
      switch block.content {
      case .text(let text):
        text
      case .structured(let schemaName, let payload):
        fenced(structuredValue(schemaName: schemaName, payload: payload).prettyPrinted)
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
    case .structured(let record):
      fenced(
        structuredValue(schemaName: record.schemaName, payload: record.payload).prettyPrinted)
    case .system, .compaction, .error, .unknown:
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

  /// The JSON value of a structured segment.
  ///
  /// - Parameters:
  ///   - schemaName: The schema name of the segment.
  ///   - payload: The content of the segment.
  /// - Returns: An object with the keys `schemaName` and `payload`.
  static func structuredValue(schemaName: String, payload: JSONValue) -> JSONValue {
    .object(["schemaName": .string(schemaName), "payload": payload])
  }
}
