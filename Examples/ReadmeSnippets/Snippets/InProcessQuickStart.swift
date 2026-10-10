// readme:compile InProcessQuickStart
import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// Runs an ACP agent in this process and opens one session on it.
@MainActor
enum InProcessQuickStart {
  /// Starts the agent that `makeAgent` makes, and opens one session.
  ///
  /// With FoundationModelsACPAgent, its public `ComposedAgent` gives the
  /// agent in three steps:
  ///
  /// ```swift
  /// // 1. Compose the agent one time, before the connection opens.
  /// let composed = try await ComposedAgent.compose(
  ///   name: try DotfolderName("my-host"), workingDirectory: projectDirectory)
  /// // 2. Bind the agent to the agent side of the connection.
  /// let (connection, session) = try await InProcessQuickStart.start(cwd: cwd) { agentConnection in
  ///   composed.agent(boundTo: agentConnection)
  /// }
  /// // 3. Close the connection. Then let the agent close its sessions.
  /// await connection.disconnect()
  /// await composed.waitForConnectionTeardown()
  /// ```
  ///
  /// The kit does not import FoundationModelsACPAgent, so this example is a
  /// comment and the snippet build does not compile it.
  ///
  /// Show the session with `ACPThread(connection:session:)` of the quick
  /// start above.
  static func start(
    cwd: AbsolutePath, serving makeAgent: @Sendable (AgentSideConnection) -> any Agent
  ) async throws -> (connection: ConnectionModel, session: SessionModel) {
    let connection = await InProcessAgent.makeConnection(serving: makeAgent)
    return (connection, try await ACPQuickStart.openSession(on: connection, cwd: cwd))
  }
}
