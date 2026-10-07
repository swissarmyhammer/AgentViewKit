import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

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
