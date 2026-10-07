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
  /// The value does not set `auth`. Only a host can run the agent program in
  /// an interactive terminal, so the agent must not give a `terminal` auth
  /// method when the host has no runner.
  /// ``FoundationModelsACP/InitializeRequest/makeAgentViewKitRequest(info:terminalAuthRunner:)``
  /// adds `auth.terminal` when the host gives a runner.
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
  /// When the host gives a terminal auth runner, the request also advertises
  /// `auth.terminal`, so that the agent can give `terminal` auth methods.
  /// Give the same runner to the ``SwiftUI/EnvironmentValues/terminalAuthRunner``
  /// environment value, so that ``AgentAuthView`` shows the Run button of
  /// each `terminal` method.
  ///
  /// - Parameters:
  ///   - info: The name, the version and the optional title of the host.
  ///   - terminalAuthRunner: The runner that runs the agent program in an
  ///     interactive terminal, or `nil` when the host has none.
  /// - Returns: The request to give to `ConnectionModel.initialize(_:)`.
  public static func makeAgentViewKitRequest(
    info: Implementation,
    terminalAuthRunner: (any TerminalAuthRunner)? = nil
  ) -> InitializeRequest {
    var capabilities = ClientCapabilities.agentViewKit
    if terminalAuthRunner != nil {
      capabilities.auth = AuthCapabilities(terminal: TerminalAuthCapabilities())
    }
    return InitializeRequest(
      info: info,
      protocolVersion: ACPClient.supportedProtocolVersion,
      capabilities: capabilities
    )
  }
}
