import FoundationModelsACPClient

extension TranscriptEntry {
  /// The observable object that the entry holds.
  ///
  /// The object keeps its identity for the life of the entry, so two rows
  /// with the same object show the same entry.
  var object: AnyObject {
    switch self {
    case .userMessage(let object): object
    case .agentMessage(let object): object
    case .thought(let object): object
    case .toolCall(let object): object
    case .terminal(let object): object
    case .plan(let object): object
    case .unknown(let object): object
    case .compaction(let object): object
    case .error(let object): object
    }
  }

  /// The stable name of the case of the entry.
  ///
  /// ``ThreadMinimapView`` puts this name in its tick identifiers. The
  /// values are `user-message`, `agent-message`, `thought`, `tool-call`,
  /// `terminal`, `plan`, `unknown`, `compaction` and `error`.
  var kindName: String {
    switch self {
    case .userMessage: "user-message"
    case .agentMessage: "agent-message"
    case .thought: "thought"
    case .toolCall: "tool-call"
    case .terminal: "terminal"
    case .plan: "plan"
    case .unknown: "unknown"
    case .compaction: "compaction"
    case .error: "error"
    }
  }

  /// The tool call object of the entry, or `nil` when the entry is not a
  /// tool call.
  var toolCall: ToolCallEntry? {
    guard case .toolCall(let toolCall) = self else { return nil }
    return toolCall
  }
}
