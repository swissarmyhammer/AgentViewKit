// readme:compile InProcessQuickStart
import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// Runs an ACP agent in this process and opens one session on it.
@MainActor
enum InProcessQuickStart {
  /// Starts the agent that `makeAgent` makes, and opens one session.
  ///
  /// With FoundationModelsACPAgent, the closure binds a `RoutedACPAgent`:
  ///
  /// ```swift
  /// let agent = try await RoutedACPAgent(name: name, router: router)
  /// let (connection, session) = try await InProcessQuickStart.start(cwd: cwd) { connection in
  ///   agent.bind(connection: connection)
  ///   return agent
  /// }
  /// ```
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
