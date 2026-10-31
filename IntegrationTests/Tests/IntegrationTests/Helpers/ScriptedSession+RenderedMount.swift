import AgentViewKitTestSupport
import Foundation
import Testing

/// The request helper of `ScriptedSession` that renders a mount. The other
/// request helpers are in `AgentViewKitTestSupport`, which the unit tests
/// link too; this one takes a ``RenderedMount``, so it belongs to the hosted
/// tests.
extension ScriptedSession {
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
  ///     `HostedViewHarness`.
  /// - Returns: The local id of the pending request.
  /// - Throws: The error of the transport.
  func sendPermissionRequest(id: Int, rendering harness: some RenderedMount) async throws -> UUID {
    try await sendInOrder([.permission(id: id)])
    harness.render()
    return try #require(model.pendingPermissions.first?.id)
  }
}
