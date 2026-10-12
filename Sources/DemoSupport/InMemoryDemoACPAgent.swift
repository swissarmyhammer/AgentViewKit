import AgentViewKit
import Foundation
import FoundationModelsACP
import OSLog

/// The in-memory demo agent as an ACP `Agent`.
///
/// ``InMemoryDemoAgent`` writes the script of the demo agent as raw wire
/// frames. This type serves the same script through an
/// `AgentSideConnection`, so that a host can run the demo agent with
/// ``AgentViewKit/InProcessAgent``:
///
/// ```swift
/// let model = await InProcessAgent.makeConnection { connection in
///   InMemoryDemoACPAgent(connection: connection)
/// }
/// ```
///
/// Each answer decodes the scripted result of ``InMemoryDemoAgent``. Each
/// prompt echoes the user message with
/// `AgentSideConnection.insertUserMessage(_:messageId:)`, answers with its
/// `messageId`, and then sends the turn of
/// ``InMemoryDemoAgent/turnNotifications(for:turn:)``. A turn ends before
/// its prompt result goes out, so `session/cancel` has nothing to stop. A
/// `session/resume` with `replayFrom: .start` sends the saved history of
/// ``InMemoryDemoAgent/historyNotifications(sessionId:)`` before its result.
///
/// The ``InMemoryDemoScript`` of the agent adds scripted sessions and selects
/// the sign-in:
///
/// - `session/list` gives the scripted sessions after the session of
///   ``InMemoryDemoAgent``.
/// - A `session/resume` of a scripted session with `replayFrom: .start`
///   sends the history of ``DemoGallerySession`` before its result. After
///   the result of each resume of a scripted session, the agent sends the
///   requests of the session, which wait for the answer of the user.
/// - `initialize` gives the sign-in method only when the script advertises
///   it, and `auth/login` fails when the script rejects the sign-in.
///
/// The agent keeps its connection weakly, as `RoutedACPAgent` of
/// FoundationModelsACPAgent does: the connection keeps the agent, and the
/// caller of `AgentSideConnection.init` keeps the connection.
public actor InMemoryDemoACPAgent: Agent {
  /// Sends one request of a scripted session over a connection, and waits
  /// for its answer.
  private typealias RequestSender = @Sendable (AgentSideConnection) async throws -> Void

  /// The connection that the agent sends its updates through, or `nil`
  /// after the release of the connection.
  private weak var connection: AgentSideConnection?

  /// The script of the agent.
  private let script: InMemoryDemoScript

  /// The number of prompts that the agent got.
  private var promptCount = 0

  /// Makes the agent of a connection.
  ///
  /// Call this initializer in the factory of `AgentSideConnection`.
  ///
  /// - Parameters:
  ///   - connection: The connection around the agent.
  ///   - script: The script of the agent. The default is the script of the
  ///     ACP tab.
  public init(connection: AgentSideConnection, script: InMemoryDemoScript = .standard) {
    self.connection = connection
    self.script = script
  }

  public func initialize(_ params: InitializeRequest) async throws -> InitializeResponse {
    try Self.decoded(await InMemoryDemoAgent.initializeResult(advertisingSignIn: script.advertisesSignIn))
  }

  public func newSession(_ params: NewSessionRequest) async throws -> NewSessionResponse {
    try Self.decoded(await InMemoryDemoAgent.newSessionResult)
  }

  public func listSessions(_ params: ListSessionsRequest) async throws -> ListSessionsResponse {
    try Self.decoded(await InMemoryDemoAgent.listSessionsResult(adding: script.sessions))
  }

  public func resumeSession(_ params: ResumeSessionRequest) async throws -> ResumeSessionResponse {
    let replaysFromStart = if case .start = params.replayFrom { true } else { false }
    if let scripted = script.session(id: params.sessionId.rawValue) {
      try await resume(scripted, replayingHistory: replaysFromStart)
    } else if replaysFromStart {
      try await replayHistory(of: params.sessionId)
    }
    return try Self.decoded(await InMemoryDemoAgent.resumeSessionResult)
  }

  public func closeSession(_ params: CloseSessionRequest) async throws -> CloseSessionResponse {
    try Self.decoded(Self.emptyResult)
  }

  public func deleteSession(_ params: DeleteSessionRequest) async throws -> DeleteSessionResponse {
    try Self.decoded(Self.emptyResult)
  }

  public func loginAuth(_ params: LoginAuthRequest) async throws -> LoginAuthResponse {
    guard script.signIn != .rejected else {
      throw RequestError.internalError(detail: Self.rejectedSignInDetail)
    }
    return try Self.decoded(Self.emptyResult)
  }

  public func logoutAuth(_ params: LogoutAuthRequest) async throws -> LogoutAuthResponse {
    try Self.decoded(Self.emptyResult)
  }

  public func prompt(_ params: PromptRequest) async throws -> PromptResponse {
    let connection = try openConnection()
    promptCount += 1
    let updates = try await Self.turnUpdates(for: params, turn: promptCount)
    // The echo and the turn follow the response. Register them with no
    // suspension between the two calls, in the order that they go out.
    let messageId = connection.insertUserMessage(params)
    connection.afterRespondingToCurrentRequest {
      for update in updates {
        try? await connection.sessionUpdate(update)
      }
    }
    return PromptResponse(messageId: messageId)
  }

  public func sessionCancel(_ params: CancelSessionNotification) async {}

  // MARK: - Connection

  /// Gives the connection that serves the current request.
  ///
  /// - Returns: The connection.
  /// - Throws: `RequestError.internalError` after the release of the
  ///   connection.
  private func openConnection() throws -> AgentSideConnection {
    guard let connection else {
      // The connection serves each request, so a request with no
      // connection is a defect of the caller.
      assertionFailure(Self.closedConnectionDetail)
      Self.logger.error("\(Self.closedConnectionDetail, privacy: .public) The request gets an error.")
      throw RequestError.internalError(detail: Self.closedConnectionDetail)
    }
    return connection
  }

  /// Sends the saved history of a session, before the result of
  /// `session/resume` goes out.
  ///
  /// The client puts the marker of the resume after the last replayed
  /// update, so the history is in the transcript when the resume returns.
  ///
  /// - Parameter sessionId: The id of the resumed session.
  /// - Throws: The error of the connection, or of the decoder.
  private func replayHistory(of sessionId: SessionId) async throws {
    let connection = try openConnection()
    let notifications = await InMemoryDemoAgent.historyNotifications(sessionId: .string(sessionId.rawValue))
    for params in notifications {
      try await connection.sessionUpdate(Self.decoded(params))
    }
  }

  /// Resumes a scripted session.
  ///
  /// The call decodes each update and each request of the session first, so
  /// that a defect of the script fails the resume. With `replayingHistory`,
  /// it then sends the history before the result of `session/resume` goes
  /// out. After the result, it sends each request of the session at one
  /// time. Each request waits for the answer of the user, or for the close
  /// of the connection.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - replayingHistory: Whether the resume replays the history from the
  ///     start.
  /// - Throws: The error of the connection, or of the decoder.
  private func resume(_ session: DemoGallerySession, replayingHistory: Bool) async throws {
    let connection = try openConnection()
    let sessionId = SessionId(rawValue: session.id)
    let history = try session.history.map { text in
      UpdateSessionNotification(sessionId: sessionId, update: try Self.decoded(text: text))
    }
    let senders = try session.requests.map(Self.makeSender)
    if replayingHistory {
      for notification in history {
        try await connection.sessionUpdate(notification)
      }
    }
    connection.afterRespondingToCurrentRequest {
      await Self.send(senders, over: connection)
    }
  }

  /// Sends requests at one time, and waits for each answer.
  ///
  /// The demo agent does nothing with an answer. A request that fails, for
  /// example because the connection closed, only goes to the log.
  ///
  /// - Parameters:
  ///   - senders: The senders of the requests.
  ///   - connection: The connection of the requests.
  private static func send(_ senders: [RequestSender], over connection: AgentSideConnection) async {
    await withTaskGroup(of: Void.self) { group in
      for sender in senders {
        group.addTask {
          do {
            try await sender(connection)
          } catch {
            logger.info("A request of a scripted session ended with no answer: \(error, privacy: .public)")
          }
        }
      }
    }
  }

  /// Decodes the params of a request of a scripted session, and makes the
  /// sender of the request.
  ///
  /// - Parameter request: The request of the script.
  /// - Returns: The sender.
  /// - Throws: `DecodingError` when the JSON text of the params does not
  ///   match the type of the request.
  private static func makeSender(for request: DemoAgentRequest) throws -> RequestSender {
    switch request {
    case .permission(let text):
      let params: RequestPermissionRequest = try decoded(text: text)
      return { connection in _ = try await connection.requestPermission(params) }
    case .elicitation(let text):
      let params: CreateElicitationRequest = try decoded(text: text)
      return { connection in _ = try await connection.createElicitation(params) }
    }
  }

  // MARK: - Script

  /// The empty result object of each request that returns no data.
  private static let emptyResult = JSONValue.object([:])

  /// The detail of the error of a request that came after the release of the
  /// connection.
  private static let closedConnectionDetail = "The connection of the in-memory demo agent is gone."

  /// The detail of the error of `auth/login` when the script rejects the
  /// sign-in.
  private static let rejectedSignInDetail = "The in-memory demo agent rejects each sign-in."

  /// The log of the agent.
  private static let logger = Logger(subsystem: "DemoSupport", category: "InMemoryDemoACPAgent")

  /// The `session/update` notifications of one turn.
  ///
  /// - Parameters:
  ///   - request: The prompt request.
  ///   - turn: The number of the turn, from 1.
  /// - Returns: The notifications, in send order.
  /// - Throws: The error of the encoder or of the decoder.
  private static func turnUpdates(for request: PromptRequest, turn: Int) async throws -> [UpdateSessionNotification] {
    let frame = JSONValue.object(["params": try JSONValue(encoding: request)])
    return try await InMemoryDemoAgent.turnNotifications(for: frame, turn: turn).map(decoded)
  }

  /// Decodes a typed value from its JSON form.
  ///
  /// - Parameter json: The JSON form of the value.
  /// - Returns: The value.
  /// - Throws: `DecodingError` when the JSON form does not match the type.
  private static func decoded<Value: Decodable>(_ json: JSONValue) throws -> Value {
    try decoded(text: json.jsonString)
  }

  /// Decodes a typed value from its JSON text.
  ///
  /// - Parameter text: The JSON text of the value.
  /// - Returns: The value.
  /// - Throws: `DecodingError` when the text does not match the type.
  private static func decoded<Value: Decodable>(text: String) throws -> Value {
    try JSONDecoder().decode(Value.self, from: Data(text.utf8))
  }
}
