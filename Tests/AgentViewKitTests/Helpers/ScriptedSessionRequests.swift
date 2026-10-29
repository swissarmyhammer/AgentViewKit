import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The shared request helpers of the hosted test suites.
///
/// The method names, the `session/update` values, the replay request and the
/// login helpers belong here, on `ScriptedSession`, and not on a test suite.
/// A suite refers to them as `ScriptedSession.<name>` and keeps no copy of
/// its own.
extension ScriptedSession {
  /// The method of a permission request.
  static let permissionMethod = "session/request_permission"

  /// The method of an elicitation request.
  static let elicitationMethod = "elicitation/create"

  /// The method of a prompt request.
  static let promptMethod = "session/prompt"

  /// The method of a cancel notification.
  static let cancelMethod = "session/cancel"

  /// The method of the notification that withdraws a request of the agent.
  static let cancelRequestMethod = "$/cancel_request"

  /// The `session/update` value that tells that the agent runs.
  static let runningState = #"{"sessionUpdate":"state_update","state":"running"}"#

  /// The `session/update` value that tells that the agent waits for the user.
  static let requiresActionState = #"{"sessionUpdate":"state_update","state":"requires_action"}"#

  /// The `session/update` value that tells that the agent is idle.
  static let idleState = #"{"sessionUpdate":"state_update","state":"idle"}"#

  /// The `session/update` value that tells that the agent is idle because
  /// the turn ended (`end_turn`).
  static let endTurnState = #"{"sessionUpdate":"state_update","state":"idle","stopReason":"end_turn"}"#

  /// The method of a resume request.
  ///
  /// `SessionStateBannersHostedTests` and `ThreadAccessibilityHostedTests`
  /// hold this method and find the resume messages of the agent with it.
  static let resumeMethod = "session/resume"

  /// The method of a login request.
  ///
  /// ``openWithLoginElicitation(id:)`` holds this method, and
  /// `PendingRequestsSessionModelHostedTests` compares the request method of
  /// the login elicitation with it.
  static let loginMethod = "auth/login"

  /// The agent auth method of ``loginInitializeResult``.
  static let loginAuthMethodID = AuthMethodId(rawValue: "agent-login")

  /// The `initialize` result of an agent with the one agent auth method
  /// ``loginAuthMethodID``.
  static let loginInitializeResult = makeInitializeResult(
    info: agentInfo, authMethods: #"[{"type": "agent", "methodId": "agent-login", "name": "Sign in"}]"#)

  /// The message of the form elicitation that the agent of
  /// ``openWithLoginElicitation(id:)`` sends during the login.
  static let loginElicitationMessage = "Your code?"

  /// The `session/resume` request of the scripted session that replays the
  /// history from the start.
  static var replayFromStartRequest: ResumeSessionRequest {
    ResumeSessionRequest(
      cwd: AbsolutePath(rawValue: workingDirectory),
      sessionId: SessionId(rawValue: sessionID),
      replayFrom: .start(ReplayFromStart()))
  }

  /// Opens a session whose agent holds its answer to `auth/login`. Before it
  /// holds the answer, the agent sends a form elicitation that names the
  /// login request, with the message ``loginElicitationMessage``. The
  /// connection model then holds the elicitation while the login runs.
  ///
  /// - Parameter id: The JSON-RPC id of the elicitation request.
  /// - Returns: The helper with the open session.
  /// - Throws: The error of `initialize` or of `session/new`.
  static func openWithLoginElicitation(id: Int) async throws -> ScriptedSession {
    try await open { agent in
      agent.results["initialize"] = loginInitializeResult
      agent.heldMethods = [loginMethod]
      agent.leadIns[loginMethod] = { request, _ in
        let loginID = request["id"]?.jsonString ?? "null"
        let params = #"""
          {"requestId": \#(loginID), "message": "\#(loginElicitationMessage)", "mode": "form",
           "requestedSchema": {"type": "object", "properties": {"code": {"type": "string"}}}}
          """#
        return [requestFrame(elicitationMethod, id: id, params: params)]
      }
    }
  }

  /// Starts the login with ``loginAuthMethodID``.
  ///
  /// - Returns: The task of the login. It ends when the agent answers.
  func startLogin() -> Task<Void, any Error> {
    let connection = connection
    return Task { try await connection.login(LoginAuthRequest(methodId: Self.loginAuthMethodID)) }
  }

  /// Sends one `tool_call_update` of the session from the agent. The title is
  /// also the `toolCallId`, so each title is one tool call.
  ///
  /// - Parameters:
  ///   - title: The title of the tool call.
  ///   - status: The new status of the tool call.
  /// - Throws: The error of the encoder or of the transport.
  func sendToolCallUpdate(title: String, status: FoundationModelsACP.ToolCallStatus) async throws {
    try await send(
      update: .toolCallUpdate(
        ToolCallUpdate(toolCallId: ToolCallId(rawValue: title), status: .value(status), title: .value(title))))
  }

  /// One request of the agent to the client.
  ///
  /// The factories read the main-actor values of ``ScriptedSession``, so the
  /// type has the same isolation.
  @MainActor struct AgentRequest {
    /// The JSON-RPC method of the request.
    let method: String

    /// The JSON-RPC id of the request.
    let id: Int

    /// The JSON text of the params.
    let params: String

    /// A form elicitation of the scripted session, with
    /// ``ScriptedSession/formElicitationParams``.
    ///
    /// The request is ``formElicitation(id:sessionId:)`` with
    /// ``ScriptedSession/sessionID``.
    ///
    /// - Parameter id: The JSON-RPC id of the request.
    /// - Returns: The request.
    static func formElicitation(id: Int) -> AgentRequest {
      formElicitation(id: id, sessionId: SessionId(rawValue: ScriptedSession.sessionID))
    }

    /// A form elicitation of a session, with the params of
    /// ``ScriptedSession/formElicitationParams``.
    ///
    /// - Parameters:
    ///   - id: The JSON-RPC id of the request.
    ///   - sessionId: The id of the session of the request.
    /// - Returns: The request.
    static func formElicitation(id: Int, sessionId: SessionId) -> AgentRequest {
      AgentRequest(
        method: ScriptedSession.elicitationMethod, id: id,
        params: ScriptedSession.makeFormElicitationParams(sessionId: sessionId.rawValue))
    }

    /// A permission request of the scripted session, with
    /// ``ScriptedSession/permissionParams``.
    ///
    /// The request is ``permission(id:sessionId:)`` with
    /// ``ScriptedSession/sessionID``.
    ///
    /// - Parameter id: The JSON-RPC id of the request.
    /// - Returns: The request.
    static func permission(id: Int) -> AgentRequest {
      permission(id: id, sessionId: SessionId(rawValue: ScriptedSession.sessionID))
    }

    /// A permission request of a session, with the params of
    /// ``ScriptedSession/permissionParams``.
    ///
    /// - Parameters:
    ///   - id: The JSON-RPC id of the request.
    ///   - sessionId: The id of the session of the request.
    /// - Returns: The request.
    static func permission(id: Int, sessionId: SessionId) -> AgentRequest {
      AgentRequest(
        method: ScriptedSession.permissionMethod, id: id,
        params: ScriptedSession.makePermissionParams(sessionId: sessionId.rawValue))
    }
  }

  /// Sends each of `requests` of the session from the agent, in order, and
  /// waits until the session model holds each one.
  ///
  /// The wait is ``sendInOrder(_:to:)`` on ``model``.
  ///
  /// - Parameter requests: The requests of the agent.
  /// - Throws: The error of the transport.
  func sendInOrder(_ requests: [AgentRequest]) async throws {
    try await sendInOrder(requests, to: model)
  }

  /// Sends each of `requests` from the agent, in order, and waits until
  /// `target` holds each one.
  ///
  /// The model keeps the wire order in `pendingRequests`. The function
  /// gives the point at which the model holds each request, so the test can
  /// read the request at that point. It sends a request only after the model
  /// holds the request before it. The wait is ``ObservationWait/until(_:)``
  /// on the count of the pending requests, with no clock: each request is
  /// certain to add one pending request. The caller makes the render pass.
  ///
  /// - Parameters:
  ///   - requests: The requests of the agent. The `sessionId` of each one
  ///     is the id of `target`.
  ///   - target: The open session model that gets the requests.
  /// - Throws: The error of the transport.
  func sendInOrder(_ requests: [AgentRequest], to target: SessionModel) async throws {
    for request in requests {
      let before = target.pendingRequests.count
      try await sendRequest(request.method, id: request.id, params: request.params)
      await ObservationWait.until { target.pendingRequests.count == before + 1 }
    }
  }

  /// Sends a permission request of the session from the agent, with
  /// ``ScriptedSession/permissionParams``, waits until the session model
  /// holds it, and then makes `harness` show it.
  ///
  /// The wait is ``sendInOrder(_:)``, with no clock: the model holds each
  /// request that the agent sends, so the request is certain to come. Then
  /// one render pass shows it.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - harness: The mount that renders the view after the wait: a
  ///     `HostedViewHarness` or a `CaptureMount`.
  /// - Returns: The local id of the pending request.
  /// - Throws: The error of the transport.
  func sendPermissionRequest(id: Int, rendering harness: some RenderedMount) async throws -> UUID {
    try await sendInOrder([.permission(id: id)])
    harness.render()
    return try #require(model.pendingPermissions.first?.id)
  }

  /// Sends a permission request of the session from the agent, and waits
  /// until the session model holds it.
  ///
  /// The test can then show the pending request in a view that it mounts.
  /// The wait is ``sendInOrder(_:)``, with no clock.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params.
  /// - Returns: The pending request that the session model holds.
  /// - Throws: The error of the transport.
  func receivePermissionRequest(id: Int, params: String = permissionParams) async throws
    -> PendingPermissionRequest
  {
    try await sendInOrder([AgentRequest(method: Self.permissionMethod, id: id, params: params)])
    return try #require(model.pendingPermissions.first)
  }

  /// Sends an elicitation request of the session from the agent, and waits
  /// until the session model holds it.
  ///
  /// The wait is ``sendInOrder(_:)``, with no clock.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params, such as
  ///     ``ScriptedSession/formElicitationParams``.
  /// - Returns: The pending elicitation that the session model holds.
  /// - Throws: The error of the transport.
  func receiveElicitation(id: Int, params: String) async throws -> PendingElicitation {
    try await sendInOrder([AgentRequest(method: Self.elicitationMethod, id: id, params: params)])
    return try #require(model.pendingElicitations.first)
  }

  /// Sends one `$/cancel_request` frame from the agent, which withdraws the
  /// request of the agent with `id`.
  ///
  /// The model removes the request from its pending requests, and its
  /// record comes into `withdrawnRequests` in a later main-actor step. The
  /// caller waits for the record.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request of the agent.
  ///   - reason: The reason in the `_meta` of the frame, under
  ///     `CancelRequestNotification.reasonMetaKey`, or `nil` for a frame with
  ///     no `_meta`.
  /// - Throws: The error of the transport.
  func sendCancelRequest(id: Int, reason: String?) async throws {
    var params: [String: JSONValue] = ["requestId": .number(Double(id))]
    if let reason {
      params["_meta"] = .object([CancelRequestNotification.reasonMetaKey: .string(reason)])
    }
    try await agent.send(#"{"jsonrpc":"2.0","method":"\#(Self.cancelRequestMethod)","params":\#(JSONValue.object(params).jsonString)}"#)
  }

  /// Waits until the agent has the response to its request with `id`.
  ///
  /// The wait is ``ObservationWait/until(_:)`` on the frames that the
  /// observable agent got, with no clock. Call it only after an action that
  /// answers the request.
  ///
  /// - Parameter id: The JSON-RPC id of the request of the agent.
  /// - Returns: The `result` member of the response, or `nil` when the
  ///   response has no `result` member.
  func result(ofRequest id: Int) async -> JSONValue? {
    await ObservationWait.until { agent.response(to: Double(id)) != nil }
    return agent.response(to: Double(id))?["result"]
  }

  /// Requires that the session model holds no pending elicitation, and then
  /// waits until the agent has the response to its request with `id`.
  ///
  /// The wait is ``result(ofRequest:)``. It starts only after the check.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request of the agent.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Returns: The `result` member of the response, or `nil` when the
  ///   response has no `result` member.
  /// - Throws: An issue when the session model holds a pending elicitation.
  func resultOfAnsweredElicitation(
    ofRequest id: Int, sourceLocation: SourceLocation = #_sourceLocation
  ) async throws -> JSONValue? {
    try #require(model.pendingElicitations.isEmpty, sourceLocation: sourceLocation)
    return await result(ofRequest: id)
  }

  /// The prompt blocks of each `session/prompt` frame that the agent got.
  var promptBlocks: [[JSONValue]] {
    agent.messages(method: Self.promptMethod).map { message in
      if case .array(let blocks) = message["params"]?["prompt"] { blocks } else { [] }
    }
  }

  /// The text of each `session/prompt` frame that the agent got, in arrival
  /// order.
  var promptTexts: [String] {
    agent.messages(method: Self.promptMethod).map(ScriptedWireAgent.promptText(of:))
  }
}
