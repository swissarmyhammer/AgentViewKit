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

  var body: some View {
    // The session views send the prompts, the cancel, and the answers to the
    // permission and elicitation cards through the two models. The logging
    // actions get only the verbs that no model has, such as a terminal
    // sign-in.
    AgentThreadView(session: session, connection: connection, actions: LoggingThreadActions())
      // The composer reads the two models from the environment.
      .environment(\.sessionModel, session)
      .environment(\.connectionModel, connection)
  }
}
