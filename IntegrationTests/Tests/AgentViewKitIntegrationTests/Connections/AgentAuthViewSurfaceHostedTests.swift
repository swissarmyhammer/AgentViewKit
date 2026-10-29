@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the sign-in card of ``AgentAuthView`` has no fill and no
/// glass, and that the separator stroke of the content edge marks its edge
/// (D113). The card is a request card in the thread, and the thread is
/// content.
///
/// The tests use the edge check of ``ContentEdgeHostedProbe``, in light mode.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentAuthViewSurfaceHostedTests {
  /// The size of the window. The card fills the width and is shorter than
  /// the height.
  static let size = CGSize(width: 360, height: 200)

  /// The one agent auth method of the connection model.
  static let method = AuthMethod.agent(
    AuthMethodAgent(
      methodId: AuthMethodId(rawValue: "tests-agent-login"), name: "Sign in with the agent",
      description: "The agent opens its sign-in page."))

  /// A code-built connection model that asks for a sign-in with ``method``.
  static var connection: ConnectionModel {
    .preview(
      authState: .required([method]),
      initializeResponse: InitializeResponse(
        info: Implementation(name: "tests-agent", version: "1.0.0"),
        protocolVersion: ACPClient.supportedProtocolVersion, authMethods: [method]))
  }

  /// The sign-in card of ``connection``.
  static var card: AgentAuthView {
    AgentAuthView(connection: connection)
  }

  @Test func theBackdropShowsInsideTheEdgeOfTheCard() async throws {
    try await ContentEdgeHostedProbe.expectBackdropShowsInsideTheEdge(of: Self.card, size: Self.size)
  }
}
