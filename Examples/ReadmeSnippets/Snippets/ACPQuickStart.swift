// readme:compile ACPQuickStart
import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI

/// Connects a connection model to an ACP v2 agent and opens one session.
@MainActor
enum ACPQuickStart {
  /// The name and the version of the app in its `initialize` request.
  static let appInfo = Implementation(name: "MyApp", version: "1.0.0")

  /// Connects `connection` over `transport` and opens one session.
  static func connect(
    _ connection: ConnectionModel, over transport: any ACPTransport, cwd: AbsolutePath
  ) async throws -> SessionModel {
    _ = await connection.connect(over: transport)
    return try await openSession(on: connection, cwd: cwd)
  }

  /// Sends `initialize` and `session/new` on a connected model.
  static func openSession(on connection: ConnectionModel, cwd: AbsolutePath) async throws -> SessionModel {
    // The request advertises only the capabilities that the kit views show.
    // An agent that speaks ACP v1 makes this call throw. The kit speaks v2 only.
    _ = try await connection.initialize(InitializeRequest.makeAgentViewKitRequest(info: appInfo))
    return try await connection.newSession(NewSessionRequest(cwd: cwd))
  }
}

/// Shows one session. The view gets the two models and keeps nothing else.
struct ACPThread: View {
  let connection: ConnectionModel
  let session: SessionModel

  /// The text of the composer.
  @State private var draft = AttributedString()

  var body: some View {
    // The session views send the prompts, the cancel, and the answers to the
    // permission and elicitation cards through the two models. The host gives
    // only the work that no model does: a terminal sign-in runner with
    // `.terminalAuthRunner(_:)`, and a reconnect with `.agentReconnect(_:)`.
    // The composer slot shows in the bottom bar below the state banner and
    // the scroll-to-bottom pill, in one glass container, and the
    // conversation scrolls under the bar. The thread view gives the
    // slot its two models and its focus scope, so that the VoiceOver focus
    // goes from an answered card back to the composer. With no slot, the
    // thread view shows a default composer.
    AgentThreadView(session: session, connection: connection) {
      // The questions of the session, such as a permission request. The
      // thread view shows no card. The deck takes no space while no question
      // waits and no notice of a withdrawn question shows.
      RequestDeck(session: session)
      PromptInputView(text: $draft) {}
    }
  }
}
