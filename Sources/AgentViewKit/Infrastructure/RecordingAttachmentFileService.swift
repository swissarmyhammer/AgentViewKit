/// An ``AttachmentFileService`` that records each run and opens no system
/// service: no application, no Finder window, no share picker, no save panel
/// and no Quick Look panel.
///
/// The previews give it to their file actions, so that a press in the canvas
/// opens nothing (``PreviewFixtures/attachmentFileService``). The tests reach
/// it through `@testable import` and read what each command ran. A run on
/// several files records one call for each file, in order, through the
/// default run of the service.
final class RecordingAttachmentFileService: AttachmentFileService {
  /// One recorded run on one file: the verb and the file that the command
  /// acted on.
  struct Call: Equatable {
    /// The verb of the command.
    let verb: AgentAttachmentVerb
    /// A file of the command.
    let attachment: Attachment
  }

  /// Each run, in call order.
  private(set) var calls: [Call] = []

  /// What ``run(_:on:)`` returns: `true` for a service that starts each
  /// action, `false` for one that cannot start any, as when the workspace
  /// does not open a file.
  let startsAction: Bool

  /// Makes a service with no recorded run.
  ///
  /// - Parameter startsAction: What each run returns. The default is
  ///   `true`.
  init(startsAction: Bool = true) {
    self.startsAction = startsAction
  }

  /// Records the run, and opens nothing.
  ///
  /// - Parameters:
  ///   - verb: The verb of the command.
  ///   - attachment: A file of the command.
  /// - Returns: ``startsAction``.
  func run(_ verb: AgentAttachmentVerb, on attachment: Attachment) -> Bool {
    calls.append(Call(verb: verb, attachment: attachment))
    return startsAction
  }
}
