import FoundationModelsACP
import FoundationModelsACPClient

extension ClientCapabilities {
  /// The client capabilities that a kit host advertises at `initialize`.
  ///
  /// ACP v2 tells a client to advertise only the capabilities that it
  /// supports. This value gives each capability that a kit view shows, and
  /// no other capability:
  ///
  /// - `elicitation.form`: ``ElicitationView`` shows a form elicitation.
  /// - `elicitation.url`: ``ElicitationURLConsentView`` shows a URL
  ///   elicitation.
  ///
  /// The value does not set `auth`. The kit has no terminal runner, so the
  /// agent must not give a `terminal` auth method. A host that can run a
  /// terminal sign-in adds `auth.terminal` to its own copy of this value.
  public static let agentViewKit = ClientCapabilities(
    elicitation: ElicitationCapabilities(
      form: ElicitationFormCapabilities(),
      url: ElicitationUrlCapabilities()
    )
  )
}

extension InitializeRequest {
  /// Makes the `initialize` request of a kit host.
  ///
  /// The request has the protocol version that the client supports and the
  /// capabilities of ``FoundationModelsACP/ClientCapabilities/agentViewKit``.
  ///
  /// - Parameter info: The name, the version and the optional title of the
  ///   host.
  /// - Returns: The request to give to `ConnectionModel.initialize(_:)`.
  public static func makeAgentViewKitRequest(info: Implementation) -> InitializeRequest {
    InitializeRequest(
      info: info,
      protocolVersion: ACPClient.supportedProtocolVersion,
      capabilities: .agentViewKit
    )
  }
}
