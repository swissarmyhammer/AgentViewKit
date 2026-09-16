import AgentViewKit
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
/// Each verb has one behavior:
///
/// - ``send(_:)`` sends `session/prompt`. The text is a `text` block. An
///   image attachment is an `image` block with base64 data. Each other
///   attachment is a `resource_link` block.
/// - ``cancel()`` sends `session/cancel`.
/// - ``respond(to:_:)-(PermissionRequest,_)`` answers the pending permission
///   request of the session. When the decision has a comment, the verb then
///   sends the comment as the next prompt, because the wire has no comment
///   field.
/// - ``respond(to:_:)-(ElicitationRequest,_)`` accepts, declines, or cancels
///   the pending elicitation of the client.
/// - ``setConfigOption(_:_:)`` sends `session/set_config_option` and puts the
///   full option list of the response on the thread.
/// - ``connect(_:)`` moves the connection of the server through
///   `authenticating`, opens the authorization URL, accepts the elicitation
///   that `meta["elicitationId"]` names, and moves the connection to
///   `connected`.
/// - ``login(_:)`` sends `auth/login`. ``logout()`` sends `auth/logout`.
/// - ``runTerminalAuth(_:)`` starts the agent program again with the extra
///   arguments and environment of the method, and shows the output in a
///   ``TerminalRecord``. The id of the record is
///   ``TerminalRecord/authID(for:)`` of the method. It never sends
///   `auth/login`.
/// - ``writeTerminalLine(_:to:)`` writes the line and a newline to the
///   standard input of the terminal authentication process that runs for the
///   record.
///
/// A verb that does not throw writes a failure to the thread as an error
/// record.
public final class ACPThreadActions: AgentThreadActions {
  /// The URL scheme of the callback when the request gives no scheme.
  public static let defaultCallbackScheme = "agentviewkit"

  /// The `meta` key of the elicitation id of an authorization request.
  public static let elicitationIdMetaKey = "elicitationId"

  /// The `meta` key of the callback scheme of an authorization request.
  public static let callbackSchemeMetaKey = "callbackScheme"

  /// The text that ``writeTerminalLine(_:to:)`` adds after each line.
  static let lineTerminator = "\n"

  /// The text before the count in the id of an error record.
  public static let errorIDPrefix = "acp-action-error-"

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

  /// The client that holds the pending requests.
  private let client: SwiftUIACPClient

  /// The connection that sends the requests to the agent.
  private let connection: ClientSideConnection

  /// The id of the session of the thread.
  private let sessionId: SessionId

  /// The presenter that opens each authorization URL.
  private let presenter: AuthorizationPresenter

  /// The launcher that starts the terminal authentication process.
  private let processLauncher: any ProcessLauncher

  /// The store of the server connections, or `nil` when the host shows no
  /// connections.
  private let connectionStore: ConnectionStore?

  /// The agent program that terminal authentication starts, or `nil`.
  private let agentProgram: ACPAgentProgram?

  /// The terminal authentication processes that run, keyed by the id of
  /// their terminal record.
  private var terminalProcesses: [TerminalID: any LaunchedProcess] = [:]

  /// The URL scheme of the callback when the request gives no scheme.
  private let callbackScheme: String

  /// Whether the browser must not share cookies with other sessions.
  private let ephemeral: Bool

  /// The number of error records that the actions wrote.
  private var errorCount = 0

  /// The log of the actions.
  private let logger = Logger(subsystem: "AgentViewKit", category: "ACPThreadActions")

  /// Makes the actions.
  ///
  /// - Parameters:
  ///   - thread: The thread that the actions change.
  ///   - client: The client that holds the pending requests.
  ///   - connection: The connection that sends the requests to the agent.
  ///   - sessionId: The id of the session of the thread.
  ///   - presenter: The presenter that opens each authorization URL.
  ///   - processLauncher: The launcher that starts the terminal
  ///     authentication process.
  ///   - connectionStore: The store of the server connections.
  ///   - agentProgram: The agent program that terminal authentication
  ///     starts.
  ///   - callbackScheme: The URL scheme of the callback when the request
  ///     gives no scheme in `meta["callbackScheme"]`.
  ///   - ephemeral: Whether the browser must not share cookies with other
  ///     sessions.
  public init(
    thread: AgentThread,
    client: SwiftUIACPClient,
    connection: ClientSideConnection,
    sessionId: SessionId,
    presenter: AuthorizationPresenter = AuthorizationPresenter(),
    processLauncher: any ProcessLauncher = AgentProcessLauncher(),
    connectionStore: ConnectionStore? = nil,
    agentProgram: ACPAgentProgram? = nil,
    callbackScheme: String = ACPThreadActions.defaultCallbackScheme,
    ephemeral: Bool = false
  ) {
    self.thread = thread
    self.client = client
    self.connection = connection
    self.sessionId = sessionId
    self.presenter = presenter
    self.processLauncher = processLauncher
    self.connectionStore = connectionStore
    self.agentProgram = agentProgram
    self.callbackScheme = callbackScheme
    self.ephemeral = ephemeral
  }

  // MARK: - Turn

  public func send(_ input: UserInput) async {
    let request = PromptRequest(prompt: Self.promptBlocks(for: input), sessionId: sessionId)
    do {
      _ = try await connection.prompt(request)
    } catch {
      report(error, verb: "session/prompt")
    }
  }

  public func cancel() async {
    do {
      try await connection.sessionCancel(CancelSessionNotification(sessionId: sessionId))
    } catch {
      report(error, verb: "session/cancel")
    }
  }

  // MARK: - Requests

  public func respond(to request: PermissionRequest, _ decision: PermissionDecision) async {
    let session = client.session(for: sessionId)
    if let pending = session.pendingPermissionRequests.first(where: {
      $0.id.uuidString == request.id.rawValue
    }) {
      switch decision.outcome {
      case .selected(let optionId):
        session.answerPermissionRequest(pending.id, with: PermissionOptionId(rawValue: optionId.rawValue))
      case .cancelled:
        session.cancelPermissionRequest(pending.id)
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
        client.acceptElicitation(id, content: content.map(SessionUpdateMapping.wireJSON))
      case .decline:
        client.declineElicitation(id)
      case .cancel:
        client.cancelElicitation(id)
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
      configId: SessionConfigId(rawValue: id.rawValue), sessionId: sessionId, value: wireValue)
    do {
      let response = try await connection.setSessionConfigOption(request)
      thread.apply(.setConfigOptions(response.configOptions.map(SessionUpdateMapping.configOption)))
    } catch {
      report(error, verb: "session/set_config_option")
    }
  }

  // MARK: - Authorization

  public func connect(_ request: AuthorizationRequest) async throws {
    let connectionID = ConnectionID(request.serverName)
    connectionStore?.transition(connectionID, to: .authenticating)
    let scheme = request.meta?[Self.callbackSchemeMetaKey]?.stringValue ?? callbackScheme
    do {
      _ = try await presenter.present(
        url: request.authorizationURL, callbackScheme: scheme, ephemeral: ephemeral)
    } catch AuthorizationPresenterError.cancelled {
      connectionStore?.transition(connectionID, to: .needsAuth)
      throw AuthorizationPresenterError.cancelled
    } catch {
      connectionStore?.transition(connectionID, to: .error(error.localizedDescription))
      throw error
    }
    if let elicitationId = request.meta?[Self.elicitationIdMetaKey]?.stringValue {
      if let id = pendingElicitationID(matching: elicitationId) {
        client.acceptElicitation(id)
      } else {
        logger.error("No pending elicitation \(elicitationId, privacy: .public) for the connection.")
      }
    }
    connectionStore?.transition(connectionID, to: .connected)
    thread.apply(.resolveAuthorization(request.id))
  }

  public func login(_ methodId: AuthMethodID) async throws {
    _ = try await connection.loginAuth(LoginAuthRequest(methodId: AuthMethodId(rawValue: methodId.rawValue)))
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
    _ = try await connection.logoutAuth(LogoutAuthRequest())
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

  /// The local id of the pending elicitation that `id` names.
  ///
  /// The search includes the elicitations with no session, because a
  /// connection can complete an elicitation of a request.
  ///
  /// - Parameter id: The local id as a string, or the wire `elicitationId`
  ///   of a URL elicitation.
  /// - Returns: The local id, or `nil` when no pending elicitation matches.
  private func pendingElicitationID(matching id: String) -> UUID? {
    let pending = client.pendingElicitations
    return (pending.first { $0.id.uuidString == id } ?? pending.first { $0.elicitationId?.rawValue == id })?.id
  }

  /// Writes a failed verb to the log and to the thread as an error record.
  ///
  /// - Parameters:
  ///   - error: The failure.
  ///   - verb: The wire method that failed.
  private func report(_ error: any Error, verb: String) {
    errorCount += 1
    let message = String(describing: error)
    logger.error("\(verb, privacy: .public) failed: \(message, privacy: .public)")
    thread.apply(
      .patch(id: Self.errorIDPrefix + String(errorCount), .error(kind: .value(.unknown(message: message)))))
  }
}
