import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog

/// The log of the composer requests of a session model.
private let sessionRequestLogger = Logger(subsystem: "AgentViewKit", category: "SessionModel")

/// The composer requests of a session model, and the shared start of the
/// other requests that a kit view sends (plan.md §3.2 "Prompt helper",
/// "Other requests", §3.8 "Composer").
extension SessionModel {
  /// Sends `input` as `session/prompt` with `prompt(_:meta:)`, and returns
  /// when the prompt returns.
  ///
  /// The blocks of the prompt follow the prompt capabilities of the agent
  /// (``PromptContent/makeBlocks(for:accepting:)``): an attachment that the
  /// agent does not accept does not go out.
  ///
  /// The model adds the local user message with the send state `pending`
  /// before the request goes out. It links the message to the `messageId` of
  /// the response or of the echo, in each order. When the request fails, the
  /// model marks the message as failed and adds the error entry. This
  /// function then writes the failure to the log, and does not throw it.
  ///
  /// - Parameters:
  ///   - input: The text and the attachments of the prompt.
  ///   - capabilities: The prompt capabilities of the agent, read from
  ///     `ConnectionModel.agentCapabilities` at the time of the call, or `nil`
  ///     when the agent advertises none.
  func sendPrompt(with input: UserInput, accepting capabilities: PromptCapabilities?) async {
    await sendPrompt(PromptContent.makeBlocks(for: input, accepting: capabilities))
  }

  /// Sends `content` as `session/prompt` with `prompt(_:meta:)`, and returns
  /// when the prompt returns.
  ///
  /// The model adds the local user message with the content, and on a
  /// failure marks it as failed and adds the error entry. This function then
  /// writes the failure to the log, and does not throw it.
  ///
  /// - Parameter content: The ACP content blocks of the prompt.
  func sendPrompt(_ content: [FoundationModelsACP.ContentBlock]) async {
    do {
      _ = try await prompt(content)
    } catch {
      sessionRequestLogger.error("session/prompt failed: \(String(describing: error), privacy: .public)")
    }
  }

  /// Starts a main-actor task that sends `content` as `session/prompt` with
  /// ``sendPrompt(_:)``.
  ///
  /// Retry uses this call to send the content of an earlier user message
  /// entry again, with no copy of the message.
  ///
  /// - Parameter content: The ACP content blocks of the prompt.
  func startPrompt(content: [FoundationModelsACP.ContentBlock]) {
    Task { @MainActor in await sendPrompt(content) }
  }

  /// Sends `text` as `session/prompt` with ``sendPrompt(with:accepting:)``,
  /// and returns when the prompt returns.
  ///
  /// The text has no attachment, so the prompt capabilities do not change
  /// its one text block.
  ///
  /// - Parameter text: The text of the prompt.
  func sendPrompt(text: String) async {
    await sendPrompt(with: UserInput(text: text), accepting: nil)
  }

  /// Starts a main-actor task that sends `input` as `session/prompt` with
  /// ``sendPrompt(with:accepting:)``.
  ///
  /// The composer calls this function at once for each submit, also while
  /// the agent runs a turn.
  ///
  /// - Parameters:
  ///   - input: The text and the attachments of the prompt.
  ///   - capabilities: The prompt capabilities of the agent, read from
  ///     `ConnectionModel.agentCapabilities` at the time of the submit, or
  ///     `nil` when the agent advertises none.
  func startPrompt(with input: UserInput, accepting capabilities: PromptCapabilities?) {
    Task { @MainActor in await sendPrompt(with: input, accepting: capabilities) }
  }

  /// Starts a main-actor task that sends `text` as `session/prompt` with
  /// ``sendPrompt(text:)``.
  ///
  /// - Parameter text: The text of the prompt.
  func startPrompt(text: String) {
    Task { @MainActor in await sendPrompt(text: text) }
  }

  /// Starts a main-actor task that selects an option of a pending permission
  /// request with `selectPermission(_:option:)`, then sends the comment of
  /// the user as the next prompt.
  ///
  /// ACP has no comment in the answer of a permission request, so the
  /// comment goes out after the answer, as one text prompt. The task awaits
  /// `selectPermission(_:option:)` before it sends the prompt. That call
  /// returns after the client writes the response frame, so the response
  /// frame goes out before the prompt frame.
  ///
  /// - Parameters:
  ///   - id: The local id of the pending request.
  ///   - optionID: The id of the option that the user selected.
  ///   - comment: The comment of the user, or `nil` for no prompt.
  func answerPermission(_ id: PendingPermissionRequest.ID, option optionID: PermissionOptionId, comment: String?) {
    Task { @MainActor in
      await selectPermission(id, option: optionID)
      guard let comment else { return }
      await sendPrompt(text: comment)
    }
  }

  /// Starts a main-actor task that selects an option of a pending permission
  /// request with `selectPermission(_:option:)`.
  ///
  /// - Parameters:
  ///   - id: The local id of the pending request.
  ///   - optionID: The id of the option that the user selected.
  func startSelectPermission(_ id: PendingPermissionRequest.ID, option optionID: PermissionOptionId) {
    Task { @MainActor in await selectPermission(id, option: optionID) }
  }

  /// Starts a main-actor task that cancels a pending permission request with
  /// `cancelPermission(_:)`.
  ///
  /// - Parameter id: The local id of the pending request.
  func startCancelPermission(_ id: PendingPermissionRequest.ID) {
    Task { @MainActor in await cancelPermission(id) }
  }

  /// Starts a main-actor task that sends `session/cancel` with
  /// `cancel(meta:)`.
  ///
  /// The `_meta` of the notification is ``promptTraceMeta``, so that the
  /// cancel joins the trace of the turn. A failure adds an error entry to the
  /// transcript.
  func startCancel() {
    startRequest("session/cancel") { try await self.cancel(meta: self.promptTraceMeta) }
  }

  /// Starts a main-actor task that sends one request of the session.
  ///
  /// A failure goes to the log and adds an error entry to the transcript
  /// with `appendError(reporting:)`.
  ///
  /// - Parameters:
  ///   - method: The ACP method of the request, for the log.
  ///   - send: The call that sends the request.
  func startRequest(_ method: String, _ send: @escaping @MainActor () async throws -> Void) {
    Task { @MainActor in
      do {
        try await send()
      } catch {
        sessionRequestLogger.error("\(method, privacy: .public) failed: \(String(describing: error), privacy: .public)")
        appendError(reporting: error)
      }
    }
  }
}
