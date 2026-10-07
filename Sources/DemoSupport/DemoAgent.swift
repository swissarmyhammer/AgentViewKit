import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// The agent of the demo app, and the `ConnectionModel` that talks to it.
///
/// ``makeConnected(options:)`` starts the agent of the launch options and
/// sends `initialize`. The views of the demo app bind to ``connection`` and
/// to the `SessionModel` objects that it opens. This type keeps no copy of a
/// model value: the connection state, the auth state, the sessions, the auth
/// methods and the capability flags stay in the models.
///
/// - The in-memory agent runs in this process through ``InProcessAgent``,
///   with ``InMemoryDemoACPAgent``. It has no terminal sign-in.
/// - Each other agent runs as an `AgentProcess`, with the arguments of
///   ``DemoLaunchOptions/agentArguments(for:)``. The demo then gives a
///   ``TerminalAppAuthRunner`` and sends `auth.terminal` in `initialize`.
///
/// ACP v2 terminal sign-in: after a successful run of a `terminal` method,
/// the `authState` of the model is `.reconnectRequired`. Only the host can
/// make a transport, so ``reconnect()`` makes a new transport with the
/// transport factory, connects the model over it and sends the same
/// `initialize` request. The model then sets `.authenticated`. The model does
/// not retry the operation that failed with `-32000`, so ``perform(_:)`` keeps
/// that operation, and ``reconnect()`` runs it one more time.
public final class DemoAgent {
  /// Makes a new transport to the agent, for the first connection and for
  /// each reconnect.
  public typealias TransportFactory = () throws -> any ACPTransport

  /// An operation that can fail with `-32000` (authentication required).
  public typealias Operation = () async throws -> Void

  /// The `info` that the demo app sends in its `initialize` request.
  public static let clientInfo = Implementation(name: "AgentViewKitDemo", version: "1.0.0")

  /// The connection model of the client side. The views read its state
  /// directly.
  public let connection: ConnectionModel

  /// The working directory of each new session, from the launch options.
  public let workingDirectory: AbsolutePath

  /// The runner of the `terminal` auth methods, or `nil` for the in-memory
  /// agent. Give it to the `terminalAuthRunner` environment value of the kit
  /// views.
  public let terminalAuthRunner: (any TerminalAuthRunner)?

  /// The `initialize` request that the demo sends on each connection.
  public let initializeRequest: InitializeRequest

  /// The transport factory, or `nil` for the in-memory agent, which
  /// ``InProcessAgent`` connects.
  private let makeTransport: TransportFactory?

  /// The operation that failed with `-32000`, or `nil`. ``reconnect()`` runs
  /// it one more time after a terminal sign-in.
  private var failedOperation: Operation?

  /// Makes the agent from its connected parts.
  ///
  /// - Parameters:
  ///   - connection: The connected model.
  ///   - workingDirectory: The working directory of each new session.
  ///   - terminalAuthRunner: The runner of the `terminal` auth methods.
  ///   - makeTransport: The transport factory, or `nil`.
  private init(
    connection: ConnectionModel,
    workingDirectory: AbsolutePath,
    terminalAuthRunner: (any TerminalAuthRunner)?,
    makeTransport: TransportFactory?
  ) {
    self.connection = connection
    self.workingDirectory = workingDirectory
    self.terminalAuthRunner = terminalAuthRunner
    self.initializeRequest = Self.makeInitializeRequest(terminalAuthRunner: terminalAuthRunner)
    self.makeTransport = makeTransport
  }

  /// Makes the `initialize` request of the demo app. It advertises only the
  /// capabilities that the kit views show, and `auth.terminal` only with a
  /// runner.
  ///
  /// - Parameter terminalAuthRunner: The runner of the demo, or `nil`.
  /// - Returns: The request.
  public static func makeInitializeRequest(terminalAuthRunner: (any TerminalAuthRunner)?) -> InitializeRequest {
    InitializeRequest.makeAgentViewKitRequest(info: clientInfo, terminalAuthRunner: terminalAuthRunner)
  }

  /// Tells whether an error is the `-32000` answer of the agent: the agent
  /// requires a sign-in before the request.
  ///
  /// - Parameter error: The error of a request.
  /// - Returns: `true` for a `RequestError` with the code
  ///   `authenticationRequired`.
  public static func isAuthenticationRequired(_ error: any Error) -> Bool {
    (error as? RequestError)?.code == .authenticationRequired
  }

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
    let workingDirectory = AbsolutePath(rawValue: options.cwd)
    guard !options.usesInMemoryAgent else {
      return try await makeInProcess(workingDirectory: workingDirectory)
    }
    let command = options.agentCommand
    let arguments = DemoLaunchOptions.agentArguments(for: command)
    return try await makeConnected(
      makeTransport: { try AgentProcess(command: command, arguments: arguments).transport },
      terminalAuthRunner: TerminalAppAuthRunner(command: command, arguments: arguments),
      workingDirectory: workingDirectory
    )
  }

  /// Connects a new `ConnectionModel` over a transport of `makeTransport`,
  /// and sends `initialize`.
  ///
  /// When `initialize` fails, the function stops the agent.
  ///
  /// - Parameters:
  ///   - makeTransport: The transport factory. ``reconnect()`` calls it again.
  ///   - terminalAuthRunner: The runner of the `terminal` auth methods.
  ///   - workingDirectory: The working directory of each new session.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the factory, or the error of `initialize`.
  static func makeConnected(
    makeTransport: @escaping TransportFactory,
    terminalAuthRunner: any TerminalAuthRunner,
    workingDirectory: AbsolutePath
  ) async throws -> DemoAgent {
    let connection = ConnectionModel()
    _ = await connection.connect(over: try makeTransport())
    let agent = DemoAgent(
      connection: connection,
      workingDirectory: workingDirectory,
      terminalAuthRunner: terminalAuthRunner,
      makeTransport: makeTransport
    )
    try await agent.initialize()
    return agent
  }

  /// Starts ``InMemoryDemoACPAgent`` in this process through
  /// ``InProcessAgent``, and sends `initialize`.
  ///
  /// - Parameter workingDirectory: The working directory of each new session.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of `initialize`.
  private static func makeInProcess(workingDirectory: AbsolutePath) async throws -> DemoAgent {
    let connection = await InProcessAgent.makeConnection { agentConnection in
      InMemoryDemoACPAgent(connection: agentConnection)
    }
    let agent = DemoAgent(
      connection: connection,
      workingDirectory: workingDirectory,
      terminalAuthRunner: nil,
      makeTransport: nil
    )
    try await agent.initialize()
    return agent
  }

  /// Sends ``initializeRequest``. When the request fails, stops the agent.
  ///
  /// - Throws: The error of `initialize`.
  private func initialize() async throws {
    do {
      _ = try await connection.initialize(initializeRequest)
    } catch {
      await stop()
      throw error
    }
  }

  /// Whether ``reconnect()`` can make a new transport. Give ``reconnect()``
  /// to the `agentReconnect` environment value of the kit views only when
  /// this is `true`.
  public var canReconnect: Bool {
    makeTransport != nil
  }

  /// Runs an operation, and keeps it when it fails with `-32000`.
  ///
  /// After a terminal sign-in, ``reconnect()`` runs the kept operation one
  /// more time.
  ///
  /// - Parameter operation: The operation, for example a `session/new`
  ///   request that shows its session.
  /// - Throws: The error of the operation.
  public func perform(_ operation: @escaping Operation) async throws {
    do {
      try await operation()
    } catch {
      if Self.isAuthenticationRequired(error) {
        failedOperation = operation
      }
      throw error
    }
  }

  /// Connects to the agent again after a successful terminal sign-in, and
  /// retries the operation that failed with `-32000`.
  ///
  /// When `authState` is not `.reconnectRequired`, the call does nothing.
  /// Otherwise the call closes the open connection, makes a new transport,
  /// connects the model over it, and sends the same `initialize` request.
  /// When `authState` is then `.authenticated`, the call runs the kept
  /// operation one more time through ``perform(_:)``. In each other state, the
  /// call retries nothing.
  ///
  /// - Throws: The error of the factory, of `initialize` or of the retried
  ///   operation.
  public func reconnect() async throws {
    guard case .reconnectRequired = connection.authState, let makeTransport else { return }
    await connection.disconnect()
    _ = await connection.connect(over: try makeTransport())
    try await initialize()
    guard case .authenticated = connection.authState, let operation = failedOperation else { return }
    failedOperation = nil
    try await perform(operation)
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
