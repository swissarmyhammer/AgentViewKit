/// One item that a thread shows (plan.md §3.2).
///
/// The set of cases is closed. Each case holds an `@Observable` record. An
/// item that an adapter does not know is ``unknown(_:)``. The kit shows it and
/// does not drop it.
public enum ThreadItem: Identifiable {
  /// The instructions of the session. The kit hides this item by default.
  case system(SystemPrompt)

  /// A message from the user.
  case userMessage(Message)

  /// A message from the agent.
  case assistantMessage(Message)

  /// The reasoning of the agent.
  case reasoning(Reasoning)

  /// A tool call and its result.
  case toolCall(ToolCallRecord)

  /// A structured segment that no mapping claimed, keyed by its schema name.
  case structured(StructuredRecord)

  /// The point where the source rewrote the thread to make it shorter.
  case compaction(CompactionMarker)

  /// An error that the user must see.
  case error(ThreadError)

  /// An item that the adapter did not know.
  case unknown(UnknownRecord)

  /// The record that the case holds.
  public var record: any ThreadRecord {
    switch self {
    case .system(let record): record
    case .userMessage(let record): record
    case .assistantMessage(let record): record
    case .reasoning(let record): record
    case .toolCall(let record): record
    case .structured(let record): record
    case .compaction(let record): record
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
  /// ``ThreadMinimapView`` puts this name in its tick identifiers, and
  /// ``CompactionMarker/removedKinds`` uses it as a key. The values are
  /// `system`, `user`, `assistant`, `reasoning`, `tool-call`, `structured`,
  /// `compaction`, `error`, and `unknown`.
  public var kindName: String {
    switch self {
    case .system: "system"
    case .userMessage: "user"
    case .assistantMessage: "assistant"
    case .reasoning: "reasoning"
    case .toolCall: "tool-call"
    case .structured: "structured"
    case .compaction: "compaction"
    case .error: "error"
    case .unknown: "unknown"
    }
  }
}
