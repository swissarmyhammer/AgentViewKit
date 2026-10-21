@testable import AgentViewKit

/// An ``AttachmentFileService`` that records each run and opens no system
/// service: no workspace call, no share picker, no save panel and no Quick
/// Look panel.
final class RecordingAttachmentFileService: AttachmentFileService {
  /// One recorded run: the verb and the attachment that the command read.
  struct Call: Equatable {
    /// The verb of the command.
    let verb: AgentAttachmentVerb
    /// The attachment of the scope of the command.
    let attachment: AgentViewKit.Attachment
  }

  /// Each run, in call order.
  private(set) var calls: [Call] = []

  /// Records the run.
  ///
  /// - Parameters:
  ///   - verb: The verb of the command.
  ///   - attachment: The attachment of the scope of the command.
  /// - Returns: `true`, always.
  func run(_ verb: AgentAttachmentVerb, on attachment: AgentViewKit.Attachment) -> Bool {
    calls.append(Call(verb: verb, attachment: attachment))
    return true
  }
}
