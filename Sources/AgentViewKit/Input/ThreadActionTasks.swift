import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import UniformTypeIdentifiers

/// The calls that start a thread action from a synchronous view callback,
/// such as a button action.
extension AgentThreadActions {
  /// Starts a main-actor task that sends the answer of the user to an
  /// elicitation request.
  ///
  /// - Parameters:
  ///   - request: The request to answer.
  ///   - result: The answer of the user.
  func startRespond(to request: ElicitationRequest, _ result: ElicitationResult) {
    Task { @MainActor in await respond(to: request, result) }
  }

  /// Starts a main-actor task that sends `input` to the agent.
  ///
  /// - Parameter input: The text and the attachments.
  func startSend(_ input: UserInput) {
    Task { @MainActor in await send(input) }
  }

  /// Starts a main-actor task that stops the current turn.
  func startCancel() {
    Task { @MainActor in await cancel() }
  }
}

/// The log of the composer requests of a session model.
private let sessionRequestLogger = Logger(subsystem: "AgentViewKit", category: "SessionModel")

/// The composer requests of a session model (update.md §4.2 "Prompt helper",
/// "Other requests", §4.7 "Composer").
extension SessionModel {
  /// The MIME type of an attachment with no known type.
  private static let defaultAttachmentMimeType = "application/octet-stream"

  /// Sends `input` as `session/prompt` with `prompt(_:meta:)`, and returns
  /// when the prompt returns.
  ///
  /// The model adds the local user message with the send state `pending`
  /// before the request goes out. It links the message to the `messageId` of
  /// the response or of the echo, in each order. When the request fails, the
  /// model marks the message as failed and adds the error entry. This
  /// function then writes the failure to the log, and does not throw it.
  ///
  /// - Parameter input: The text and the attachments of the prompt.
  func sendPrompt(with input: UserInput) async {
    do {
      _ = try await prompt(Self.promptBlocks(for: input))
    } catch {
      sessionRequestLogger.error("session/prompt failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// Starts a main-actor task that sends `session/cancel` with
  /// `cancel(meta:)`.
  ///
  /// The `_meta` of the notification is ``promptTraceMeta``, so that the
  /// cancel joins the trace of the turn. A failure adds an error entry to the
  /// transcript.
  func startCancel() {
    Task { @MainActor in
      do {
        try await cancel(meta: promptTraceMeta)
      } catch {
        sessionRequestLogger.error("session/cancel failed: \(String(describing: error), privacy: .public)")
        appendError(reporting: error)
      }
    }
  }

  /// The prompt blocks of a user input.
  ///
  /// - Parameter input: The text and the attachments.
  /// - Returns: A `text` block, then one block for each attachment. An image
  ///   file that the model can read is an `image` block. Each other
  ///   attachment is a `resource_link` block.
  private static func promptBlocks(for input: UserInput) -> [FoundationModelsACP.ContentBlock] {
    [.text(FoundationModelsACP.TextContent(text: input.text))] + input.attachments.map(attachmentBlock(for:))
  }

  /// The prompt block of one attachment.
  ///
  /// - Parameter url: The location of the attached file.
  /// - Returns: An `image` block with base64 data for an image file that can
  ///   be read, else a `resource_link` block.
  private static func attachmentBlock(for url: URL) -> FoundationModelsACP.ContentBlock {
    let type = UTType(filenameExtension: url.pathExtension)
    let mimeType = type?.preferredMIMEType
    if let type, type.conforms(to: .image), let mimeType, let data = try? Data(contentsOf: url) {
      return .image(
        FoundationModelsACP.ImageContent(
          data: data.base64EncodedString(), mimeType: MediaType(rawValue: mimeType), uri: url.absoluteString))
    }
    return .resourceLink(
      FoundationModelsACP.ResourceLink(
        name: url.lastPathComponent,
        uri: url.absoluteString,
        mimeType: MediaType(rawValue: mimeType ?? defaultAttachmentMimeType)
      )
    )
  }
}

/// The turn verbs of a composer view (update.md §4.7 "Composer").
///
/// When the environment has a session model, each verb goes through it: a
/// send calls `SessionModel.prompt(_:meta:)`, a stop calls
/// `SessionModel.cancel(meta:)`, and the turn runs while `agentState` is
/// `running`. Else each verb goes through the thread actions, and the state
/// of the thread tells whether the turn runs.
struct ComposerTurn {
  /// The session model of the environment, or `nil`.
  let session: SessionModel?

  /// The thread of the environment, or `nil`.
  let thread: AgentThread?

  /// The thread actions of the environment, or `nil`.
  let actions: (any AgentThreadActions)?

  /// Whether the agent runs a turn.
  var isRunning: Bool {
    guard let session else { return thread?.state == .running }
    return session.isRunning
  }

  /// Starts a main-actor task that sends `input`, then calls `onReturn`.
  ///
  /// With a session model, `onReturn` runs after the prompt returns or
  /// fails. With the thread actions, it runs after
  /// ``AgentThreadActions/send(_:)`` returns.
  ///
  /// - Parameters:
  ///   - input: The text and the attachments.
  ///   - onReturn: The closure that runs after the send.
  func startPrompt(with input: UserInput, then onReturn: @escaping @MainActor () -> Void = {}) {
    Task { @MainActor in
      if let session {
        await session.sendPrompt(with: input)
      } else {
        await actions?.send(input)
      }
      onReturn()
    }
  }

  /// Starts a main-actor task that stops the current turn.
  func startCancel() {
    guard let session else {
      actions?.startCancel()
      return
    }
    session.startCancel()
  }
}
