@testable import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Checks that the sign-in card of ``AgentAuthView`` is on the content
/// surface of the kit, and not on glass (D110 (b)). The card is a request
/// card in the thread, and the thread is content.
///
/// The tests use the method of ``ContentSurfaceHostedProbe``. Each test shows
/// the card one time with Reduce Transparency off and one time with it on.
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

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func theBackdropShowsWhenItIsInFrontOfTheCard(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.card, backdrop: .inFront, reducesTransparency: reducesTransparency, size: Self.size)
  }

  @Test(arguments: ContentSurfaceHostedProbe.reduceTransparencyValues)
  func noPixelOfTheBackdropShowsInsideTheCard(reducesTransparency: Bool) throws {
    try ContentSurfaceHostedProbe.expectBackdropShowsOnlyInFront(
      of: Self.card, backdrop: .behind, reducesTransparency: reducesTransparency, size: Self.size)
  }
}
