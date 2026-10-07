import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// The agent of the demo app, and the `ConnectionModel` that talks to it.
///
/// ``makeConnected(options:)`` starts the agent of the launch options and
/// sends `initialize`. The views of the demo app bind to ``connection`` and
/// to the `SessionModel` objects that it opens. This type keeps no copy of a
/// model value: the connection state, the sessions, the auth methods and the
/// capability flags stay in the models.
///
/// - The in-memory agent runs in this process through ``InProcessAgent``,
///   with ``InMemoryDemoACPAgent``.
/// - Each other agent runs as an `AgentProcess`, with the arguments of
///   ``DemoLaunchOptions/agentArguments(for:)``.
public struct DemoAgent {
  /// The `info` that the demo app sends in its `initialize` request.
  public static let clientInfo = Implementation(name: "AgentViewKitDemo", version: "1.0.0")

  /// The `initialize` request of the demo app. It advertises only the
  /// capabilities that the kit views show.
  public static var initializeRequest: InitializeRequest {
    InitializeRequest.makeAgentViewKitRequest(info: clientInfo)
  }

  /// The connection model of the client side. The views read its state
  /// directly.
  public let connection: ConnectionModel

  /// The working directory of each new session, from the launch options.
  public let workingDirectory: AbsolutePath

  /// The agent process, or `nil` for the in-process agent. The value keeps
  /// the process while the demo app uses it.
  private let process: AgentProcess?

  /// Starts the agent of `options`, connects a new `ConnectionModel`, and
  /// sends `initialize` with ``initializeRequest``.
  ///
  /// When `initialize` fails, the function stops the agent.
  ///
  /// - Parameter options: The launch options of the demo app.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The `AgentProcessError` of a program that does not start, or
  ///   the error of `initialize`.
  public static func makeConnected(options: DemoLaunchOptions) async throws -> DemoAgent {
    let agent = try await makeStarted(options: options)
    do {
      _ = try await agent.connection.initialize(initializeRequest)
    } catch {
      await agent.stop()
      throw error
    }
    return agent
  }

  /// Starts the agent of `options` and connects a new `ConnectionModel`.
  ///
  /// - Parameter options: The launch options of the demo app.
  /// - Returns: The agent, with a connected model.
  /// - Throws: The `AgentProcessError` of a program that does not start.
  private static func makeStarted(options: DemoLaunchOptions) async throws -> DemoAgent {
    let workingDirectory = AbsolutePath(rawValue: options.cwd)
    if options.usesInMemoryAgent {
      return await makeInProcess(workingDirectory: workingDirectory)
    }
    return try await makeProcess(command: options.agentCommand, workingDirectory: workingDirectory)
  }

  /// Starts ``InMemoryDemoACPAgent`` in this process through
  /// ``InProcessAgent``.
  ///
  /// - Parameter workingDirectory: The working directory of each new session.
  /// - Returns: The agent, with a connected model.
  private static func makeInProcess(workingDirectory: AbsolutePath) async -> DemoAgent {
    let connection = await InProcessAgent.makeConnection { agentConnection in
      InMemoryDemoACPAgent(connection: agentConnection)
    }
    return DemoAgent(connection: connection, workingDirectory: workingDirectory, process: nil)
  }

  /// Starts an agent program as an `AgentProcess`, and connects a new
  /// `ConnectionModel` over its standard input and output.
  ///
  /// - Parameters:
  ///   - command: The absolute path of the agent program.
  ///   - workingDirectory: The working directory of each new session.
  /// - Returns: The agent, with a connected model.
  /// - Throws: The `AgentProcessError` of a program that does not start.
  private static func makeProcess(command: String, workingDirectory: AbsolutePath) async throws -> DemoAgent {
    let process = try AgentProcess(command: command, arguments: DemoLaunchOptions.agentArguments(for: command))
    let connection = ConnectionModel()
    _ = await connection.connect(over: process.transport)
    return DemoAgent(connection: connection, workingDirectory: workingDirectory, process: process)
  }

  /// Sends `session/new` in ``workingDirectory``.
  ///
  /// - Returns: The model of the new session. The connection model keeps it
  ///   in `openSessions`.
  /// - Throws: The error of `session/new`.
  public func openSession() async throws -> SessionModel {
    try await connection.newSession(NewSessionRequest(cwd: workingDirectory))
  }

  /// Stops the agent with `ConnectionModel.disconnect()`. When the call
  /// returns, the state of ``connection`` is `.disconnected`.
  ///
  /// The disconnect stops the read of the transport. For the in-process
  /// agent, ``InProcessAgent`` then closes the input of the agent side, and
  /// the agent stops. An agent process gets a group kill when its transport
  /// stops.
  public func stop() async {
    await connection.disconnect()
  }
}
