import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
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

  /// Sends a permission request of the session from the agent, with
  /// ``ScriptedSession/permissionParams``, and pumps `harness` until the
  /// session model holds it.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - harness: The harness to pump while the test waits.
  ///   - timeout: The longest time to wait, in seconds.
  /// - Returns: The local id of the pending request, or `nil` when the model
  ///   holds no request at the timeout.
  /// - Throws: The error of the transport.
  func sendPermissionRequest(
    id: Int, pumping harness: HostedViewHarness<some View>, timeout: TimeInterval
  ) async throws -> UUID? {
    try await sendRequest(Self.permissionMethod, id: id, params: Self.permissionParams)
    await harness.pump(until: timeout) { !model.pendingPermissions.isEmpty }
    return model.pendingPermissions.first?.id
  }

  /// Sends a permission request of the session from the agent, and waits
  /// until the session model holds it.
  ///
  /// The test can then show the pending request in a view that it mounts.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params.
  /// - Returns: The pending request that the session model holds.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no request at the time limit.
  func receivePermissionRequest(id: Int, params: String = permissionParams) async throws
    -> PendingPermissionRequest
  {
    try await sendRequest(Self.permissionMethod, id: id, params: params)
    _ = await waitUntil { !model.pendingPermissions.isEmpty }
    return try #require(model.pendingPermissions.first)
  }

  /// Sends an elicitation request of the session from the agent, and waits
  /// until the session model holds it.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params, such as
  ///     ``ScriptedSession/formElicitationParams``.
  /// - Returns: The pending elicitation that the session model holds.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no elicitation at the time limit.
  func receiveElicitation(id: Int, params: String) async throws -> PendingElicitation {
    try await sendRequest(Self.elicitationMethod, id: id, params: params)
    _ = await waitUntil { !model.pendingElicitations.isEmpty }
    return try #require(model.pendingElicitations.first)
  }

  /// Waits until the agent has the response to its request with `id`.
  ///
  /// - Parameter id: The JSON-RPC id of the request of the agent.
  /// - Returns: The `result` member of the response, or `nil` when no response
  ///   came before the time limit.
  func result(ofRequest id: Int) async -> AgentViewKit.JSONValue? {
    _ = await waitUntil { agent.response(to: Double(id)) != nil }
    return agent.response(to: Double(id))?["result"]
  }
}
