import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import SwiftUI
import UniformTypeIdentifiers

/// The calls that start a thread action from a synchronous view callback,
/// such as a button action.
extension AgentThreadActions {
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

/// The composer requests of a session model, and the shared start of the
/// other requests that a kit view sends (update.md §4.2 "Prompt helper",
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
/// send calls `SessionModel.prompt(_:meta:)` at once, and a stop calls
/// `SessionModel.cancel(meta:)`. A composer reads `agentState` only to show
/// the Stop control. Else each verb goes through the thread actions, and the
/// state of the thread tells whether the turn runs. No verb waits for a
/// prompt to return before it does a different step.
struct ComposerTurn {
  /// The session model of the environment, or `nil`.
  let session: SessionModel?

  /// The thread of the environment, or `nil`.
  let thread: AgentThread?

  /// The thread actions of the environment, or `nil`.
  let actions: (any AgentThreadActions)?

  /// Whether the agent runs a turn, for the Stop control.
  ///
  /// With a session model, the value reads `SessionModel.agentState`
  /// directly. Else it reads the state of the thread.
  var isRunning: Bool {
    guard let session else { return thread?.state == .running }
    return session.isRunning
  }

  /// Starts a main-actor task that sends `input` at once, also while the
  /// agent runs a turn.
  ///
  /// With a session model, the task calls `SessionModel.prompt(_:meta:)`.
  /// Else it calls ``AgentThreadActions/send(_:)``.
  ///
  /// - Parameter input: The text and the attachments.
  func startPrompt(with input: UserInput) {
    guard let session else {
      actions?.startSend(input)
      return
    }
    Task { @MainActor in await session.sendPrompt(with: input) }
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

/// The ``ComposerTurn`` of the environment of a composer view.
///
/// The wrapper reads the session model
/// (``SwiftUI/EnvironmentValues/sessionModel``), the thread
/// (``SwiftUI/EnvironmentValues/agentThread``), and the thread actions
/// (``SwiftUI/EnvironmentValues/threadActions``), and gives the turn of these
/// three values. Each composer view gets its turn here, so that the views make
/// the turn in one place:
///
/// ```swift
/// @EnvironmentComposerTurn private var turn
/// ```
@propertyWrapper
struct EnvironmentComposerTurn: DynamicProperty {
  @Environment(\.sessionModel) private var session
  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions

  /// The turn of the session model, the thread and the thread actions of the
  /// environment.
  var wrappedValue: ComposerTurn {
    ComposerTurn(session: session, thread: thread, actions: actions)
  }
}
