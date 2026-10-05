import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

nonisolated extension TranscriptEntry.ID {
  /// The text form of the row identity (update.md §4.2 "Row identity").
  ///
  /// The view uses `TranscriptEntry.ID` as the row identity. The accessibility
  /// identifiers, the ``BodyEvaluationCounter`` keys and the
  /// ``ScrollAnchorManager`` use text, so they use this key. Two different
  /// identities give two different keys: each kind has its own start, so a
  /// thought and an agent message with the same `messageId` have two keys.
  /// The key of a local entry does not change when the entry gets its
  /// `messageId`.
  public var rowKey: String {
    switch self {
    case .wire(let id): id.rowKey
    case .local(let uuid): "local-\(uuid.uuidString)"
    }
  }
}

nonisolated extension SessionEntry.ID {
  /// The text form of an identity from the wire: the kind, then the wire
  /// value.
  fileprivate var rowKey: String {
    switch self {
    case .userMessage(let id): "user-message-\(id.rawValue)"
    case .agentMessage(let id): "agent-message-\(id.rawValue)"
    case .agentThought(let id): "thought-\(id.rawValue)"
    case .toolCall(let id): "tool-call-\(id.rawValue)"
    case .terminal(let id): "terminal-\(id.rawValue)"
    case .plan(let id): "plan-\(id.rawValue)"
    case .compaction(let id): "compaction-\(id.rawValue)"
    case .unidentified(let position): "entry-\(position)"
    }
  }
}

nonisolated extension TranscriptEntry {
  /// The text form of the row identity of the entry. See
  /// ``FoundationModelsACPClient/TranscriptEntry/ID/rowKey``.
  public var rowKey: String {
    id.rowKey
  }
}
