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

  /// The name of the kind of the entry, as the `sessionUpdate` tag of ACP
  /// spells it. The placeholder view of a kind with no view shows it.
  var kindName: String {
    switch self {
    case .userMessage: "user_message"
    case .agentMessage: "agent_message"
    case .thought: "agent_thought"
    case .toolCall: "tool_call"
    case .terminal: "terminal"
    case .plan: "plan"
    case .unknown: "unknown"
    case .compaction: "compaction"
    case .error: "error"
    }
  }
}
