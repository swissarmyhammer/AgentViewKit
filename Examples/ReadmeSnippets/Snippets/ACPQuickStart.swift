// readme:compile ACPQuickStart
import AgentViewKit
import AgentViewKitACP
import FoundationModelsACP
import FoundationModelsACPClient
import Observation
import SwiftUI

/// Connects to an ACP v2 agent, opens a session, and binds it to a thread.
@Observable
@MainActor
final class ACPQuickStart {
  let thread = AgentThread()
  private(set) var actions: ACPThreadActions?

  @ObservationIgnored private let client = SwiftUIACPClient()
  @ObservationIgnored private var tasks: [Task<Void, Never>] = []

  func connect(over transport: any ACPTransport, cwd: String) async throws {
    let connection = await client.connect(over: transport)
    let request = InitializeRequest(
      info: Implementation(name: "MyApp", version: "1.0.0"),
      protocolVersion: ACPClient.supportedProtocolVersion,
      capabilities: ACPClient.advertisedCapabilities)
    // An agent that speaks ACP v1 makes this call throw. The kit speaks v2 only.
    let response = try await connection.initialize(request)
    let session = try await connection.newSession(NewSessionRequest(cwd: AbsolutePath(rawValue: cwd)))
    let sessionId = session.sessionId

    let source = ACPThreadSource(
      thread: thread, updates: connection.updates(for: sessionId), agentName: "Agent")
    source.acceptProtocolVersion(response.protocolVersion, requested: request.protocolVersion)
    tasks = [
      Task { await source.run() },
      Task {
        await source.mirrorPendingRequests(
          of: client.session(for: sessionId), client: client, sessionId: sessionId)
      },
    ]
    actions = ACPThreadActions(thread: thread, client: client, connection: connection, sessionId: sessionId)
  }
}

struct ACPThread: View {
  let model: ACPQuickStart

  var body: some View {
    if let actions = model.actions {
      AgentThreadView(thread: model.thread, actions: actions)
    } else {
      ProgressView("Connecting")
    }
  }
}
