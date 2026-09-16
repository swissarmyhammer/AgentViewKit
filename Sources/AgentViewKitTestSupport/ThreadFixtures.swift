import AgentViewKit
import Foundation

/// Builders of sample thread records and requests for tests and previews
/// (plan.md §3.4).
///
/// Each builder gives the same value each time for the same arguments,
/// except that each call makes a new record object.
public enum ThreadFixtures {
  /// The time that the builders use as the start of a tool call.
  public static let startTime = Date(timeIntervalSince1970: sampleStartSeconds)

  /// The time that the builders use as the end of a tool call.
  public static let endTime = startTime.addingTimeInterval(sampleDurationSeconds)

  /// The start of a sample tool call, in seconds after 1970-01-01.
  private static let sampleStartSeconds: TimeInterval = 1_800_000_000

  /// The duration of a sample tool call, in seconds.
  private static let sampleDurationSeconds: TimeInterval = 2

  // MARK: - Records

  /// Makes a message with one text block.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - text: The text of the message.
  /// - Returns: The message.
  public static func message(id: String = "message-1", text: String = "Hello.") -> Message {
    Message(id: id, blocks: [ContentBlock(text: text)])
  }

  /// Makes a tool call that reads a file, with the status.
  ///
  /// A call that started has ``startTime``. A call that ended has
  /// ``endTime``. A completed call has one text block of output.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - status: The progress of the call.
  /// - Returns: The tool call.
  public static func toolCall(id: String = "tool-call-1", status: ToolCallStatus) -> ToolCallRecord {
    let started = status != .pending
    let ended = started && status != .inProgress
    let content: [ToolContent] = status == .completed ? [.block(ContentBlock(text: "Done."))] : []
    return ToolCallRecord(
      id: id,
      title: "Read README.md",
      kind: .read,
      status: status,
      content: content,
      locations: [ToolCallLocation(path: "/project/README.md")],
      rawInput: .object(["path": .string("/project/README.md")]),
      startedAt: started ? startTime : nil,
      endedAt: ended ? endTime : nil
    )
  }

  /// Makes one tool call for each known status, in the order of
  /// `ToolCallStatus.knownCases`.
  ///
  /// The id of each record is `tool-call-` and the wire value of its status.
  ///
  /// - Returns: The tool calls.
  public static func toolCallForEachStatus() -> [ToolCallRecord] {
    ToolCallStatus.knownCases.map { toolCall(id: "tool-call-\($0.wireValue)", status: $0) }
  }

  /// Makes a reasoning record with one text segment.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - text: The text of the reasoning.
  /// - Returns: The reasoning record.
  public static func reasoning(
    id: String = "reasoning-1",
    text: String = "I must read the file first."
  ) -> Reasoning {
    Reasoning(id: id, segments: [text])
  }

  // MARK: - Requests

  /// Makes a permission request for a tool call, with one option of each
  /// known kind, in the order of `PermissionOption.Kind.knownCases`.
  ///
  /// - Parameters:
  ///   - id: The identifier of the request.
  ///   - toolCallId: The identifier of the tool call that needs permission.
  /// - Returns: The permission request.
  public static func permissionRequest(
    id: String = "permission-1",
    toolCallId: String = "tool-call-1"
  ) -> PermissionRequest {
    PermissionRequest(
      id: PermissionRequestID(id),
      title: "Run the tool?",
      description: "The agent wants to read a file.",
      subject: .toolCall(id: toolCallId),
      options: PermissionOption.Kind.knownCases.map { kind in
        PermissionOption(id: PermissionOptionID(kind.wireValue), name: kind.wireValue, kind: kind)
      }
    )
  }

  /// Makes an elicitation request in form mode, with a schema that has one
  /// required string property, `name`.
  ///
  /// - Parameter id: The identifier of the request.
  /// - Returns: The elicitation request.
  public static func formElicitationRequest(id: String = "elicitation-form-1") -> ElicitationRequest {
    let schema = JSONValue.object([
      "type": .string("object"),
      "properties": .object([
        "name": .object(["type": .string("string"), "title": .string("Name")])
      ]),
      "required": .array([.string("name")]),
    ])
    return ElicitationRequest(
      id: ElicitationRequestID(id),
      server: "Files",
      message: "Type your name.",
      mode: .form(requestedSchema: schema)
    )
  }

  /// Makes an elicitation request in URL mode.
  ///
  /// - Parameter id: The identifier of the request. The elicitation id is
  ///   the same string.
  /// - Returns: The elicitation request.
  public static func urlElicitationRequest(id: String = "elicitation-url-1") -> ElicitationRequest {
    ElicitationRequest(
      id: ElicitationRequestID(id),
      server: "Files",
      message: "Open the page to continue.",
      mode: .url(sampleURL, elicitationId: id)
    )
  }

  /// The location that a URL mode request opens.
  private static let sampleURL = URL(string: "https://example.com/continue")!

  // MARK: - Threads

  /// Makes a thread with the number of items.
  ///
  /// The items repeat this order: a user message, a reasoning record, a
  /// completed tool call, and an assistant message. The id of each item is
  /// `item-` and its position.
  ///
  /// - Parameter count: The number of items. A value less than one gives an
  ///   empty thread.
  /// - Returns: The thread.
  public static func sampleThread(items count: Int) -> AgentThread {
    let thread = AgentThread()
    for position in 0..<max(count, 0) {
      thread.apply(.insert(sampleItem(at: position), after: nil))
    }
    return thread
  }

  /// The makers of the items of ``sampleThread(items:)``, in order.
  private static let sampleItemMakers: [(String) -> ThreadItem] = [
    { .userMessage(message(id: $0, text: "Read the README.")) },
    { .reasoning(reasoning(id: $0)) },
    { .toolCall(toolCall(id: $0, status: .completed)) },
    { .assistantMessage(message(id: $0, text: "The README tells how to build.")) },
  ]

  /// Makes the item of ``sampleThread(items:)`` at the position.
  ///
  /// - Parameter position: The position of the item.
  /// - Returns: The item.
  private static func sampleItem(at position: Int) -> ThreadItem {
    sampleItemMakers[position % sampleItemMakers.count]("item-\(position)")
  }
}
