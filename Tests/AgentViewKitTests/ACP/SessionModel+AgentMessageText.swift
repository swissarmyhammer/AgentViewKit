import FoundationModelsACP
import FoundationModelsACPClient

extension SessionModel {
  /// The joined text blocks of an agent message in the transcript.
  ///
  /// The ACP tests read the reply of an agent with this function.
  ///
  /// - Parameter id: The `messageId` of the agent message.
  /// - Returns: The text, or `nil` when the transcript has no agent message
  ///   with `id`.
  func agentMessageText(id: String) -> String? {
    let messageId = MessageId(rawValue: id)
    for case .agentMessage(let message) in transcript where message.messageId == messageId {
      return message.content.compactMap { block in
        if case .text(let text) = block { text.text } else { nil }
      }.joined()
    }
    return nil
  }
}
