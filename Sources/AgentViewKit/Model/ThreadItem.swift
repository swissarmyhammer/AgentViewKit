/// One item that a thread shows (plan.md §3.2).
///
/// The set of cases is closed. Each case holds an `@Observable` record. An
/// item that an adapter does not know is ``unknown(_:)``. The kit shows it and
/// does not drop it.
public enum ThreadItem: Identifiable {
  /// A message from the user.
  case userMessage(Message)

  /// A message from the agent.
  case assistantMessage(Message)

  /// The reasoning of the agent.
  case reasoning(Reasoning)

  /// A tool call and its result.
  case toolCall(ToolCallRecord)

  /// An error that the user must see.
  case error(ThreadError)

  /// An item that the adapter did not know.
  case unknown(UnknownRecord)

  /// The record that the case holds.
  public var record: any ThreadRecord {
    switch self {
    case .userMessage(let record): record
    case .assistantMessage(let record): record
    case .reasoning(let record): record
    case .toolCall(let record): record
    case .error(let record): record
    case .unknown(let record): record
    }
  }

  /// The identifier of the record that the case holds.
  public var id: String {
    record.id
  }

  /// The stable name of the kind of the item.
  ///
  /// ``ThreadMinimapView`` puts this name in its tick identifiers. The
  /// values are `user`, `assistant`, `reasoning`, `tool-call`, `error`, and
  /// `unknown`.
  public var kindName: String {
    switch self {
    case .userMessage: "user"
    case .assistantMessage: "assistant"
    case .reasoning: "reasoning"
    case .toolCall: "tool-call"
    case .error: "error"
    case .unknown: "unknown"
    }
  }
}
