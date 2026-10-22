/// An ``AttachmentFileService`` that records each run and opens no system
/// service: no application, no Finder window, no share picker, no save panel
/// and no Quick Look panel.
///
/// The previews give it to their file actions, so that a press in the canvas
/// opens nothing (``PreviewFixtures/attachmentFileService``). The tests reach
/// it through `@testable import` and read what each command ran.
final class RecordingAttachmentFileService: AttachmentFileService {
  /// One recorded run: the verb and the attachment that the command read.
  struct Call: Equatable {
    /// The verb of the command.
    let verb: AgentAttachmentVerb
    /// The attachment of the scope of the command.
    let attachment: Attachment
  }

  /// Each run, in call order.
  private(set) var calls: [Call] = []

  /// Records the run, and opens nothing.
  ///
  /// - Parameters:
  ///   - verb: The verb of the command.
  ///   - attachment: The attachment of the scope of the command.
  /// - Returns: `true`, always.
  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool {
    calls.append(Call(verb: verb, attachment: attachment))
    return true
  }
}
