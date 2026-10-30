import FoundationModelsACPClient

/// Finds the agent message entries of a transcript.
///
/// The unit tests and the integration tests share these lookups.
public enum AgentMessageLookup {
  /// The agent message object of an entry.
  ///
  /// - Parameter entry: A transcript entry.
  /// - Returns: The object, or `nil` when the entry is not an agent message.
  public static func agentMessage(of entry: TranscriptEntry) -> AgentMessageEntry? {
    if case .agentMessage(let message) = entry { message } else { nil }
  }

  /// The agent message entry of `model` with the message ID `messageID`.
  ///
  /// - Parameters:
  ///   - messageID: The `messageId` of the agent message.
  ///   - model: The session model.
  /// - Returns: The entry, or `nil` when the transcript has no such entry.
  public static func agentMessage(messageID: String, in model: SessionModel) -> AgentMessageEntry? {
    model.transcript.lazy.compactMap(agentMessage(of:)).first { $0.messageId?.rawValue == messageID }
  }
}
