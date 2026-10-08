import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// The values of a `ToolCallEntry` that the tool call views show when the
/// agent did not send them (plan.md §3.8 "Tool call view").
///
/// Each property reads only its own field of the entry object, at the time
/// of the body. Thus the row of a ``ToolCallView``, which reads the title,
/// the kind and the status, does not observe the content, and the body,
/// which reads the content, does not observe the status. The properties keep
/// no copy of the entry.
extension ToolCallEntry {
  /// The kind of an entry with no kind.
  static let defaultKind = FoundationModelsACP.ToolKind.other

  /// The status of an entry with no status.
  static let defaultStatus = FoundationModelsACP.ToolCallStatus.pending

  /// The title of the call for a person to read, or an empty text when the
  /// entry has no title.
  var shownTitle: String {
    title ?? ""
  }

  /// The ACP kind of the call, or ``defaultKind`` when the entry has no kind.
  var shownKind: FoundationModelsACP.ToolKind {
    kind ?? Self.defaultKind
  }

  /// The ACP status of the call, or ``defaultStatus`` when the entry has no
  /// status.
  var shownStatus: FoundationModelsACP.ToolCallStatus {
    status ?? Self.defaultStatus
  }

  /// The output of the call, in order.
  var parts: [ToolCallPart] {
    content.map(ToolCallPart.init(content:))
  }
}

/// One part of the output of a tool call entry.
///
/// A part holds the ACP values of the entry, with no copy.
enum ToolCallPart {
  /// A content block, such as text or an image.
  case block(FoundationModelsACP.ContentBlock)

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
  ///   - raw: The content as the source gave it, as an ACP value.
  case unknown(kind: String, raw: FoundationModelsACP.JSONValue)

  /// Makes the part of one ACP content part of an entry. The part holds the
  /// ACP values of the entry.
  ///
  /// - Parameter content: The content part of the entry.
  init(content: ToolCallContent) {
    switch content {
    case .content(let wrapped): self = .block(wrapped.content)
    case .diff(let diff): self = .diff(diff)
    case .terminal(let terminal): self = .terminal(id: terminal.terminalId.rawValue)
    case .unknown(let kind, let raw): self = .unknown(kind: kind, raw: raw)
    }
  }

  /// Tells whether the part refers to a terminal.
  var isTerminal: Bool {
    if case .terminal = self { true } else { false }
  }
}
