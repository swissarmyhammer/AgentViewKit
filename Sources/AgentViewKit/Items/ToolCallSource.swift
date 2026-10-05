import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// The tool call that a ``ToolCallView`` shows: a record of the kit model, or
/// a `ToolCallEntry` of a `SessionModel` (update.md §4.7 "Tool call view").
///
/// The properties give the fields in the ACP kind and status types, so the
/// view does not use the kit `ToolKind` and `ToolCallStatus`. Each property
/// reads only its own fields of the observable object. Thus the row of the
/// view, which reads the title, the kind and the status, does not observe the
/// content, and the body, which reads the content, does not observe the
/// status.
enum ToolCallSource {
  /// A tool call record of an ``AgentThread``.
  case record(ToolCallRecord)

  /// A tool call entry of the transcript of a `SessionModel`.
  case entry(ToolCallEntry)

  /// The kind of an entry with no kind. It is the default kind of a record.
  static let defaultKind = FoundationModelsACP.ToolKind.other

  /// The status of an entry with no status. It is the default status of a
  /// record.
  static let defaultStatus = FoundationModelsACP.ToolCallStatus.pending

  /// The text identity of the call: the record id, or the row key of the
  /// entry.
  var id: String {
    switch self {
    case .record(let record): record.id
    case .entry(let entry): entry.id.rowKey
    }
  }

  /// The title of the call for a person to read. An entry with no title
  /// gives an empty text.
  var title: String {
    switch self {
    case .record(let record): record.title
    case .entry(let entry): entry.title ?? ""
    }
  }

  /// The ACP kind of the call, or ``defaultKind`` for an entry with no kind.
  var kind: FoundationModelsACP.ToolKind {
    switch self {
    case .record(let record): record.kind.acpKind
    case .entry(let entry): entry.kind ?? Self.defaultKind
    }
  }

  /// The ACP status of the call, or ``defaultStatus`` for an entry with no
  /// status.
  var status: FoundationModelsACP.ToolCallStatus {
    switch self {
    case .record(let record): record.status.acpStatus
    case .entry(let entry): entry.status ?? Self.defaultStatus
    }
  }

  /// The time when the host saw the call start. Only a record has a time.
  var startedAt: Date? {
    switch self {
    case .record(let record): record.startedAt
    case .entry: nil
    }
  }

  /// The time when the host saw the call end. Only a record has a time.
  var endedAt: Date? {
    switch self {
    case .record(let record): record.endedAt
    case .entry: nil
    }
  }

  /// The files that the call reads or changes.
  var locations: [ToolCallLocation] {
    switch self {
    case .record(let record):
      record.locations
    case .entry(let entry):
      entry.locations.map { ToolCallLocation(path: $0.path.rawValue, line: $0.line) }
    }
  }

  /// The input that the agent sent to the tool.
  var rawInput: AgentViewKit.JSONValue? {
    switch self {
    case .record(let record): record.rawInput
    case .entry(let entry): entry.rawInput.map(SessionUpdateMapping.json)
    }
  }

  /// The output that the tool sent back.
  var rawOutput: AgentViewKit.JSONValue? {
    switch self {
    case .record(let record): record.rawOutput
    case .entry(let entry): entry.rawOutput.map(SessionUpdateMapping.json)
    }
  }

  /// The output of the call, in order.
  var parts: [ToolCallPart] {
    switch self {
    case .record(let record): record.content.map(ToolCallPart.init(content:))
    case .entry(let entry): entry.content.map(ToolCallPart.init(content:))
    }
  }

  /// Tells if the call is expanded.
  ///
  /// - Parameter store: The store of the user decisions.
  /// - Returns: The user decision. With no decision, a record uses the
  ///   ``ExpandedBlocksStore/defaultExpanded`` policy of the store, and an
  ///   entry is collapsed: the policy reads a ``ThreadItem``, and an entry
  ///   has none.
  func isExpanded(in store: ExpandedBlocksStore) -> Bool {
    switch self {
    case .record(let record): store.decision(for: record.id) ?? store.defaultExpanded(.toolCall(record))
    case .entry(let entry): store.decision(for: entry.id.rowKey) ?? false
    }
  }
}

/// One part of the output of a tool call, from a record or from an entry.
enum ToolCallPart {
  /// A content block, such as text or an image.
  case block(AgentViewKit.ContentBlock)

  /// A change to files, as unified diff text. Only a record gives it.
  case patch(String)

  /// An ACP diff, with `git_patch` text or with structured changes only.
  case diff(FoundationModelsACP.Diff)

  /// A reference to a terminal that the agent owns.
  ///
  /// - Parameter id: The identifier of the terminal.
  case terminal(id: String)

  /// Content that the kit does not know.
  ///
  /// - Parameters:
  ///   - kind: The type name that the source gave.
  ///   - raw: The content as the source gave it.
  case unknown(kind: String, raw: AgentViewKit.JSONValue)

  /// Makes the part of one content part of a record.
  ///
  /// - Parameter content: The content part of the record.
  init(content: ToolContent) {
    switch content {
    case .block(let block): self = .block(block)
    case .diff(let patch): self = .patch(patch)
    case .terminal(let id): self = .terminal(id: id)
    case .unknown(let kind, let raw): self = .unknown(kind: kind, raw: raw)
    }
  }

  /// Makes the part of one ACP content part of an entry.
  ///
  /// - Parameter content: The content part of the entry.
  init(content: ToolCallContent) {
    switch content {
    case .content(let wrapped): self = .block(SessionUpdateMapping.contentBlock(wrapped.content))
    case .diff(let diff): self = .diff(diff)
    case .terminal(let terminal): self = .terminal(id: terminal.terminalId.rawValue)
    case .unknown(let kind, let raw): self = .unknown(kind: kind, raw: SessionUpdateMapping.json(raw))
    }
  }

  /// Tells whether the part refers to a terminal.
  var isTerminal: Bool {
    if case .terminal = self { true } else { false }
  }
}
