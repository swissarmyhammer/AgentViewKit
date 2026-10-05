import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import OSLog
import UniformTypeIdentifiers

/// The errors of ``ACPThreadActions``.
public enum ACPThreadActionsError: Error, Equatable, Sendable {
  /// ``ACPThreadActions/runTerminalAuth(_:)`` has no agent program to start.
  case noAgentProgram

  /// The terminal authentication process stopped with a status that is not
  /// zero.
  case terminalAuthFailed(status: Int32)

  /// ``ACPThreadActions/writeTerminalLine(_:to:)`` found no running terminal
  /// authentication process for the terminal.
  case noRunningTerminal(TerminalID)
}

/// The agent program that terminal authentication starts again
/// (plan.md §12).
public nonisolated struct ACPAgentProgram: Sendable, Hashable {
  /// The absolute path of the agent executable.
  public var path: String

  /// The arguments of the agent. The arguments of an auth method come after
  /// these arguments.
  public var arguments: [String]

  /// Makes an agent program.
  ///
  /// - Parameters:
  ///   - path: The absolute path of the agent executable.
  ///   - arguments: The arguments of the agent.
  public init(path: String, arguments: [String] = []) {
    self.path = path
    self.arguments = arguments
  }
}

/// The verbs of a thread that an ACP v2 session fills (plan.md §3.4, §12).
///
/// The verbs send each request through the client models: the
/// `SessionModel` of the thread and the `ConnectionModel` of the agent.
/// Each verb has one behavior:
///
/// - ``send(_:)`` sends `session/prompt` with `SessionModel.prompt(_:meta:)`.
///   The text is a `text` block. An image attachment is an `image` block with
///   base64 data. Each other attachment is a `resource_link` block.
/// - ``cancel()`` sends `session/cancel` with `SessionModel.cancel(meta:)`.
/// - ``respond(to:_:)-(PermissionRequest,_)`` answers the pending permission
///   request of the session model. When the decision has a comment, the verb
///   then sends the comment as the next prompt, because the wire has no
///   comment field.
/// - ``respond(to:_:)-(ElicitationRequest,_)`` accepts, declines, or cancels
///   the pending elicitation of the session model.
/// - ``setConfigOption(_:_:)`` sends `session/set_config_option`. The agent
///   reports the new options in a `config_option_update`, which the source
///   puts on the thread.
/// - ``login(_:)`` sends `auth/login`. ``logout()`` sends `auth/logout`. The
///   connection model keeps the auth state.
/// - ``runTerminalAuth(_:)`` starts the agent program again with the extra
///   arguments and environment of the method, and shows the output in a
///   ``TerminalRecord``. The id of the record is
///   ``TerminalRecord/authID(for:)`` of the method. It never sends
///   `auth/login`.
/// - ``writeTerminalLine(_:to:)`` writes the line and a newline to the
///   standard input of the terminal authentication process that runs for the
///   record.
///
/// The kit keeps no error list (update.md §4.7 "Error rows"). A failed
/// `session/prompt` shows the error entry that `SessionModel.prompt(_:meta:)`
/// adds. Each other failed request adds an error entry to the session model
/// with `SessionModel.appendError(code:message:data:)`. A verb that throws
/// also throws the error again.
public final class ACPThreadActions: AgentThreadActions {
  /// The text that ``writeTerminalLine(_:to:)`` adds after each line.
  static let lineTerminator = "\n"

  /// The number of milliseconds in ``commentDelay``.
  static let commentDelayMilliseconds = 50

  /// The time that ``respond(to:_:)-(PermissionRequest,_)`` waits between
  /// the answer and the comment prompt.
  ///
  /// The connection writes the answer in its own task after the pending
  /// request resumes. The client side of the connection has no public hook
  /// that runs after the answer is written, so the verb waits this time.
  /// Then the answer is on the transport before the comment prompt.
  static let commentDelay = Duration.milliseconds(commentDelayMilliseconds)

  /// The MIME type of an attachment with no known type.
  static let defaultMimeType = "application/octet-stream"

  /// The thread that the actions change.
  public let thread: AgentThread

  /// The model of the session of the thread. It sends the session requests
  /// and holds the pending requests.
  private let session: SessionModel

  /// The connection model of the agent. It sends the auth requests.
  private let connection: ConnectionModel

  /// The launcher that starts the terminal authentication process.
  private let processLauncher: any ProcessLauncher

  /// The agent program that terminal authentication starts, or `nil`.
  private let agentProgram: ACPAgentProgram?

  /// The terminal authentication processes that run, keyed by the id of
  /// their terminal record.
  private var terminalProcesses: [TerminalID: any LaunchedProcess] = [:]

  /// The log of the actions.
  private let logger = Logger(subsystem: "AgentViewKit", category: "ACPThreadActions")

  /// Makes the actions.
  ///
  /// - Parameters:
  ///   - thread: The thread that the actions change.
  ///   - session: The model of the session of the thread.
  ///   - connection: The connection model of the agent.
  ///   - processLauncher: The launcher that starts the terminal
  ///     authentication process.
  ///   - agentProgram: The agent program that terminal authentication
  ///     starts.
  public init(
    thread: AgentThread,
    session: SessionModel,
    connection: ConnectionModel,
    processLauncher: any ProcessLauncher = AgentProcessLauncher(),
    agentProgram: ACPAgentProgram? = nil
  ) {
    self.thread = thread
    self.session = session
    self.connection = connection
    self.processLauncher = processLauncher
    self.agentProgram = agentProgram
  }

  // MARK: - Turn

  public func send(_ input: UserInput) async {
    do {
      _ = try await session.prompt(Self.promptBlocks(for: input))
    } catch {
      // The session model already added the error entry of the prompt.
      log(error, verb: "session/prompt")
    }
  }

  public func cancel() async {
    do {
      try await session.cancel()
    } catch {
      report(error, verb: "session/cancel")
    }
  }

  // MARK: - Requests

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    if let pending = session.pendingPermissions.first(where: {
      $0.id.uuidString == request.id.rawValue
    }) {
      switch decision.outcome {
      case .selected(let optionId):
        session.selectPermission(pending.id, option: PermissionOptionId(rawValue: optionId.rawValue))
      case .cancelled:
        session.cancelPermission(pending.id)
      }
    } else {
      logger.error("No pending permission request \(request.id.rawValue, privacy: .public).")
    }
    thread.apply(.resolvePermission(request.id))
    guard let comment = decision.comment, !comment.isEmpty else { return }
    try? await Task.sleep(for: Self.commentDelay)
    await send(UserInput(text: comment))
  }

  public func respond(to request: AgentViewKit.ElicitationRequest, _ result: ElicitationResult) async {
    if let id = pendingElicitationID(matching: request.id.rawValue) {
      switch result {
      case .accept(let content):
        session.acceptElicitation(id, content: content.map(SessionUpdateMapping.wireJSON))
      case .decline:
        session.declineElicitation(id)
      case .cancel:
        session.cancelElicitation(id)
      }
    } else {
      logger.error("No pending elicitation \(request.id.rawValue, privacy: .public).")
    }
    thread.apply(.resolveElicitation(request.id))
  }

  public func setConfigOption(_ id: ConfigOptionID, _ value: ConfigValue) async {
    let wireValue: SetSessionConfigOptionRequest.Value =
      switch value {
      case .id(let valueId): .id(SessionConfigValueId(rawValue: valueId))
      case .boolean(let bool): .boolean(bool)
      }
    let request = SetSessionConfigOptionRequest(
      configId: SessionConfigId(rawValue: id.rawValue), sessionId: session.sessionId, value: wireValue)
    do {
      try await session.setConfigOption(request)
    } catch {
      report(error, verb: "session/set_config_option")
    }
  }

  // MARK: - Authorization

  public func login(_ methodId: AuthMethodID) async throws {
    do {
      try await connection.login(LoginAuthRequest(methodId: AuthMethodId(rawValue: methodId.rawValue)))
    } catch {
      report(error, verb: "auth/login")
      throw error
    }
  }

  public func runTerminalAuth(_ method: AgentViewKit.AuthMethod.Terminal) async throws {
    guard let agentProgram else { throw ACPThreadActionsError.noAgentProgram }
    let arguments = agentProgram.arguments + method.args
    let process = try processLauncher.launch(
      program: agentProgram.path, arguments: arguments, environment: method.env)
    let terminalID = TerminalRecord.authID(for: method.id)
    terminalProcesses[terminalID] = process
    defer {
      // A later run of the same method can replace the entry. Remove only
      // the entry of this run.
      if terminalProcesses[terminalID] === process {
        terminalProcesses[terminalID] = nil
      }
    }
    let command = ([agentProgram.path] + arguments).joined(separator: " ")
    thread.apply(.upsertTerminal(TerminalPatch(id: terminalID, command: .value(command), output: .value(Data()))))
    for await chunk in process.output {
      thread.apply(.upsertTerminal(TerminalPatch(id: terminalID, outputChunk: chunk)))
    }
    guard let status = process.exitStatus else { return }
    thread.apply(
      .upsertTerminal(
        TerminalPatch(id: terminalID, exitStatus: .value(TerminalRecord.ExitStatus(code: Int(status))))))
    guard status == 0 else { throw ACPThreadActionsError.terminalAuthFailed(status: status) }
  }

  public func writeTerminalLine(_ line: String, to terminal: TerminalID) async throws {
    guard let process = terminalProcesses[terminal] else {
      throw ACPThreadActionsError.noRunningTerminal(terminal)
    }
    try process.write(Data((line + Self.lineTerminator).utf8))
  }

  public func logout() async throws {
    do {
      try await connection.logout(LogoutAuthRequest())
    } catch {
      report(error, verb: "auth/logout")
      throw error
    }
  }

  // MARK: - Helpers

  /// The prompt blocks of a user input.
  ///
  /// - Parameter input: The text and the attachments.
  /// - Returns: A `text` block, then one block for each attachment. An image
  ///   file that the actions can read is an `image` block. Each other
  ///   attachment is a `resource_link` block.
  static func promptBlocks(for input: UserInput) -> [FoundationModelsACP.ContentBlock] {
    [.text(FoundationModelsACP.TextContent(text: input.text))] + input.attachments.map(attachmentBlock)
  }

  /// The prompt block of one attachment.
  private static func attachmentBlock(_ url: URL) -> FoundationModelsACP.ContentBlock {
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
        mimeType: MediaType(rawValue: mimeType ?? defaultMimeType)
      )
    )
  }

  /// The local id of the pending elicitation of the session that `id` names.
  ///
  /// - Parameter id: The local id as a string.
  /// - Returns: The local id, or `nil` when no pending elicitation matches.
  private func pendingElicitationID(matching id: String) -> UUID? {
    session.pendingElicitations.first { $0.id.uuidString == id }?.id
  }

  /// Writes a failed verb to the log and adds its error entry to the session
  /// model.
  ///
  /// - Parameters:
  ///   - error: The failure.
  ///   - verb: The wire method that failed.
  private func report(_ error: any Error, verb: String) {
    log(error, verb: verb)
    session.appendError(reporting: error)
  }

  /// Writes a failed verb to the log.
  ///
  /// - Parameters:
  ///   - error: The failure.
  ///   - verb: The wire method that failed.
  private func log(_ error: any Error, verb: String) {
    logger.error("\(verb, privacy: .public) failed: \(String(describing: error), privacy: .public)")
  }
}
