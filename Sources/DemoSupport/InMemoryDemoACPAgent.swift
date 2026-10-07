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
/// The agent keeps its connection weakly, as `RoutedACPAgent` of
/// FoundationModelsACPAgent does: the connection keeps the agent, and the
/// caller of `AgentSideConnection.init` keeps the connection.
public actor InMemoryDemoACPAgent: Agent {
  /// The connection that the agent sends its updates through, or `nil`
  /// after the release of the connection.
  private weak var connection: AgentSideConnection?

  /// The number of prompts that the agent got.
  private var promptCount = 0

  /// Makes the agent of a connection.
  ///
  /// Call this initializer in the factory of `AgentSideConnection`.
  ///
  /// - Parameter connection: The connection around the agent.
  public init(connection: AgentSideConnection) {
    self.connection = connection
  }

  public func initialize(_ params: InitializeRequest) async throws -> InitializeResponse {
    try Self.decoded(await InMemoryDemoAgent.initializeResult)
  }

  public func newSession(_ params: NewSessionRequest) async throws -> NewSessionResponse {
    try Self.decoded(await InMemoryDemoAgent.newSessionResult)
  }

  public func listSessions(_ params: ListSessionsRequest) async throws -> ListSessionsResponse {
    try Self.decoded(await InMemoryDemoAgent.listSessionsResult)
  }

  public func resumeSession(_ params: ResumeSessionRequest) async throws -> ResumeSessionResponse {
    if case .start = params.replayFrom {
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
    try Self.decoded(Self.emptyResult)
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

  // MARK: - Script

  /// The empty result object of each request that returns no data.
  private static let emptyResult = AgentViewKit.JSONValue.object([:])

  /// The detail of the error of a request that came after the release of the
  /// connection.
  private static let closedConnectionDetail = "The connection of the in-memory demo agent is gone."

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
    let frame = AgentViewKit.JSONValue.object(["params": try AgentViewKit.JSONValue(encoding: request)])
    return try await InMemoryDemoAgent.turnNotifications(for: frame, turn: turn).map(decoded)
  }

  /// Decodes a typed value from its JSON form.
  ///
  /// - Parameter json: The JSON form of the value.
  /// - Returns: The value.
  /// - Throws: `DecodingError` when the JSON form does not match the type.
  private static func decoded<Value: Decodable>(_ json: AgentViewKit.JSONValue) throws -> Value {
    try JSONDecoder().decode(Value.self, from: Data(json.jsonString.utf8))
  }
}
