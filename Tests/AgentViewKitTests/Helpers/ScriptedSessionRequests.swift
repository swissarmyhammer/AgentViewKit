import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI

extension ScriptedSession {
  /// The method of a permission request.
  static let permissionMethod = "session/request_permission"

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
}
