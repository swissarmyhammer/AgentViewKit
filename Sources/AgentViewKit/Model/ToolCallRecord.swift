import Foundation
import Observation

/// A tool call and its result (plan.md §3.2).
///
/// The fields follow the ACP v2 tool call. The host measures ``startedAt``
/// and ``endedAt``, because no source gives a time.
@Observable
public final class ToolCallRecord: ThreadRecord {
  /// The identifier of the record. For ACP, this is the `toolCallId`.
  public nonisolated let id: String

  /// The number of patches on the record.
  public private(set) var revision = 0

  /// The `_meta` value of the source, unchanged.
  public var meta: JSONValue?

  /// The text that tells what the tool does.
  public var title: String

  /// The type of the tool.
  public var kind: ToolKind

  /// The progress of the call.
  public var status: ToolCallStatus

  /// The output of the call, in order.
  public var content: [ToolContent]

  /// The files that the call reads or changes.
  public var locations: [ToolCallLocation]

  /// The input that the agent sent to the tool.
  public var rawInput: JSONValue?

  /// The output that the tool sent back.
  public var rawOutput: JSONValue?

  /// The time when the host saw the call start.
  public var startedAt: Date?

  /// The time when the host saw the call end.
  public var endedAt: Date?

  /// Makes a tool call record.
  ///
  /// - Parameters:
  ///   - id: The identifier of the record.
  ///   - title: The text that tells what the tool does.
  ///   - kind: The type of the tool.
  ///   - status: The progress of the call.
  ///   - content: The output of the call, in order.
  ///   - locations: The files that the call reads or changes.
  ///   - rawInput: The input that the agent sent to the tool.
  ///   - rawOutput: The output that the tool sent back.
  ///   - startedAt: The time when the host saw the call start.
  ///   - endedAt: The time when the host saw the call end.
  ///   - meta: The `_meta` value of the source.
  public init(
    id: String,
    title: String,
    kind: ToolKind = .other,
    status: ToolCallStatus = .pending,
    content: [ToolContent] = [],
    locations: [ToolCallLocation] = [],
    rawInput: JSONValue? = nil,
    rawOutput: JSONValue? = nil,
    startedAt: Date? = nil,
    endedAt: Date? = nil,
    meta: JSONValue? = nil
  ) {
    self.id = id
    self.title = title
    self.kind = kind
    self.status = status
    self.content = content
    self.locations = locations
    self.rawInput = rawInput
    self.rawOutput = rawOutput
    self.startedAt = startedAt
    self.endedAt = endedAt
    self.meta = meta
  }

  /// Increments ``revision`` by one.
  public func bump() {
    revision += 1
  }
}

/// The type of a tool (plan.md §3.2).
///
/// The wire values are the ACP v2 `ToolKind` strings. The view uses the type
/// to select an icon.
public nonisolated enum ToolKind: WireValueEnum, Codable {
  /// The tool reads files or data.
  case read

  /// The tool changes files or content.
  case edit

  /// The tool removes files or data.
  case delete

  /// The tool moves or renames files.
  case move

  /// The tool searches for information.
  case search

  /// The tool runs commands or code.
  case execute

  /// The tool reasons or plans.
  case think

  /// The tool gets external data.
  case fetch

  /// The tool changes the mode of the session.
  case switchMode

  /// A tool of a different type.
  case other

  /// A tool type that the kit does not know, with its wire string.
  case unknown(String)

  /// Each case of the enum, but not ``unknown(_:)``.
  public static let knownCases: [ToolKind] = [
    .read, .edit, .delete, .move, .search, .execute, .think, .fetch, .switchMode, .other,
  ]

  /// The ACP wire string of the case.
  public var wireValue: String {
    switch self {
    case .read: "read"
    case .edit: "edit"
    case .delete: "delete"
    case .move: "move"
    case .search: "search"
    case .execute: "execute"
    case .think: "think"
    case .fetch: "fetch"
    case .switchMode: "switch_mode"
    case .other: "other"
    case .unknown(let wireValue): wireValue
    }
  }
}

/// The progress of a tool call (plan.md §3.2).
///
/// The wire values are the ACP v2 `ToolCallStatus` strings. An ACP agent
/// sends the custom status `_lost` when the result of a call is lost. That
/// status gives ``lost``. Other custom statuses give ``unknown(_:)``.
public nonisolated enum ToolCallStatus: WireValueEnum, Codable {
  /// The call did not start. The input streams, or the call waits for
  /// permission.
  case pending

  /// The call runs.
  case inProgress

  /// The call is complete.
  case completed

  /// The call failed.
  case failed

  /// The call stopped before it was complete.
  case cancelled

  /// The result of the call is lost.
  case lost

  /// A status that the kit does not know, with its wire string.
  case unknown(String)

  /// Each case of the enum, but not ``unknown(_:)``.
  public static let knownCases: [ToolCallStatus] = [
    .pending, .inProgress, .completed, .failed, .cancelled, .lost,
  ]

  /// The ACP wire string of the case.
  public var wireValue: String {
    switch self {
    case .pending: "pending"
    case .inProgress: "in_progress"
    case .completed: "completed"
    case .failed: "failed"
    case .cancelled: "cancelled"
    case .lost: "_lost"
    case .unknown(let wireValue): wireValue
    }
  }
}

/// One part of the output of a tool call (plan.md §3.2).
public nonisolated enum ToolContent: Sendable, Hashable {
  /// A content block, such as text or an image.
  case block(ContentBlock)

  /// A change to files, as unified diff text.
  ///
  /// - Parameter patch: The unified diff text.
  case diff(patch: String)

  /// A reference to a terminal that the agent owns.
  ///
  /// - Parameter id: The identifier of the terminal.
  case terminal(id: String)

  /// Tool content that the kit does not know.
  ///
  /// - Parameters:
  ///   - kind: The type name that the source gave.
  ///   - raw: The content as the source gave it.
  case unknown(kind: String, raw: JSONValue)
}

/// A file that a tool call reads or changes (plan.md §3.2).
public nonisolated struct ToolCallLocation: Sendable, Hashable {
  /// The absolute path of the file.
  public var path: String

  /// The line in the file, if the source gave one.
  public var line: Int?

  /// Makes a tool call location.
  ///
  /// - Parameters:
  ///   - path: The absolute path of the file.
  ///   - line: The line in the file.
  public init(path: String, line: Int? = nil) {
    self.path = path
    self.line = line
  }
}
