import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPAgent
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
/// - The agent of the recorded sessions of the Gallery tab is
///   FoundationModelsACPAgent. It runs in this process through
///   ``InProcessAgent`` over a ``RecordedSessionsStage``, with
///   ``makeInProcess(recordedSessions:)``. It has no terminal sign-in.
///
/// ACP v2 terminal sign-in: after a successful run of a `terminal` method,
/// the `authState` of the model is `.reconnectRequired`. Only the host can
/// make a transport, so ``reconnect(onOpen:)`` makes a new transport with the
/// transport factory, connects the model over it and sends the same
/// `initialize` request. The model then sets `.authenticated`. The model does
/// not retry the operation that failed with `-32000`, so
/// ``openSession(onOpen:)`` keeps that operation, and ``reconnect(onOpen:)``
/// runs it one more time. With no kept operation, ``reconnect(onOpen:)``
/// opens a new session, because the reconnect closed each open session.
///
/// ACP sign-in with an `agent` method: `ConnectionModel.login(_:)` sets
/// `authState` to `.authenticated` on the open connection. The host sees that
/// change and calls ``retryFailedOperation()``, which runs the kept operation
/// one more time.
public final class DemoAgent {
  /// Makes a new transport to the agent, for the first connection and for
  /// each reconnect.
  public typealias TransportFactory = () throws -> any ACPTransport

  /// Shows a session that ``openSession(onOpen:)`` or
  /// ``reconnect(onOpen:)`` opened.
  public typealias SessionHandler = (SessionModel) -> Void

  /// Waits until an agent in this process closed each open session, after
  /// the close of its connection.
  public typealias TeardownWait = @Sendable () async -> Void

  /// An operation that can fail with `-32000` (authentication required).
  private typealias Operation = () async throws -> Void

  /// The `info` that the demo app sends in its `initialize` request.
  public static let clientInfo = Implementation(name: "AgentViewKitDemo", version: "1.0.0")

  /// The dotfolder name of FoundationModelsACPAgent for the recorded
  /// sessions. It is not `acp-agent`, so the agent does not read the
  /// configuration of the `acp-agent` program of the user.
  static let recordedSessionsAgentName = "agentviewkit-demo"

  /// The connection model of the client side. The views read its state
  /// directly.
  public let connection: ConnectionModel

  /// The working directory of each new session and of the session list:
  /// from the launch options, or the working directory of a stage of
  /// recorded sessions.
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

  /// The wait of ``stop()`` for the teardown of an agent in this process, or
  /// `nil` when the agent needs no wait.
  private let waitForTeardown: TeardownWait?

  /// The operation that failed with `-32000`, or `nil`.
  /// ``retryFailedOperation()`` or ``reconnect(onOpen:)`` runs it one more
  /// time after a sign-in.
  private var failedOperation: Operation?

  /// Makes the agent from its parts.
  ///
  /// - Parameters:
  ///   - connection: The model.
  ///   - workingDirectory: The working directory of each new session.
  ///   - terminalAuthRunner: The runner of the `terminal` auth methods.
  ///   - makeTransport: The transport factory, or `nil`.
  ///   - waitForTeardown: The wait of ``stop()``, or `nil`.
  private init(
    connection: ConnectionModel,
    workingDirectory: AbsolutePath,
    terminalAuthRunner: (any TerminalAuthRunner)?,
    makeTransport: TransportFactory?,
    waitForTeardown: TeardownWait?
  ) {
    self.connection = connection
    self.workingDirectory = workingDirectory
    self.terminalAuthRunner = terminalAuthRunner
    self.initializeRequest = Self.makeInitializeRequest(terminalAuthRunner: terminalAuthRunner)
    self.makeTransport = makeTransport
    self.waitForTeardown = waitForTeardown
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

  /// Starts FoundationModelsACPAgent in this process over a stage of
  /// recorded sessions, through ``InProcessAgent``, and sends `initialize`.
  ///
  /// The agent uses the stub model of the package, so it loads no model and
  /// downloads nothing. Its transcript location is the copy in the stage,
  /// set in code: the agent needs no configuration file for it. The
  /// working directory of each session list is the empty working directory
  /// of the stage. The agent restores a recorded session on `session/resume`.
  /// When the recorded working directory of a session is missing, the agent
  /// replays the session with no tools and writes nothing.
  ///
  /// ``stop()`` waits until the agent closed each open session.
  ///
  /// - Parameter stage: The temporary copy of the recorded sessions.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the composition of the agent, or the error of
  ///   `initialize`.
  public static func makeInProcess(recordedSessions stage: RecordedSessionsStage) async throws -> DemoAgent {
    let composed = try await ComposedAgent.compose(
      name: try DotfolderName(recordedSessionsAgentName),
      workingDirectory: stage.workingDirectory,
      modelSource: .stub,
      transcriptLocation: .path(stage.transcriptsDirectory)
    )
    return try await makeInProcess(
      serving: { composed.agent(boundTo: $0) },
      workingDirectory: AbsolutePath(rawValue: stage.workingDirectory.path(percentEncoded: false)),
      waitForTeardown: composed.waitForConnectionTeardown
    )
  }

  /// Connects a new `ConnectionModel` over a transport of `makeTransport`,
  /// and sends `initialize`.
  ///
  /// When `initialize` fails, the function stops the agent.
  ///
  /// - Parameters:
  ///   - makeTransport: The transport factory. ``reconnect(onOpen:)`` calls it
  ///     again.
  ///   - terminalAuthRunner: The runner of the `terminal` auth methods.
  ///   - workingDirectory: The working directory of each new session.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the factory, or the error of `initialize`.
  static func makeConnected(
    makeTransport: @escaping TransportFactory,
    terminalAuthRunner: any TerminalAuthRunner,
    workingDirectory: AbsolutePath
  ) async throws -> DemoAgent {
    try await makeStarted(
      connection: ConnectionModel(),
      workingDirectory: workingDirectory,
      terminalAuthRunner: terminalAuthRunner,
      makeTransport: makeTransport
    )
  }

  /// Starts ``InMemoryDemoACPAgent`` in this process through
  /// ``InProcessAgent``, and sends `initialize`.
  ///
  /// The ACP tab starts the agent with the ``InMemoryDemoScript/standard``
  /// script. The Gallery tab starts it with the
  /// ``InMemoryDemoScript/gallery`` script, and ``DemoConnectionState``
  /// starts it with the script of each state.
  ///
  /// - Parameters:
  ///   - script: The script of the agent.
  ///   - workingDirectory: The working directory of each new session. The
  ///     default is ``InMemoryDemoAgent/sessionCwd``, the working directory
  ///     of the sessions that the agent lists.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of `initialize`.
  public static func makeInProcess(
    script: InMemoryDemoScript = .standard,
    workingDirectory: AbsolutePath = AbsolutePath(rawValue: InMemoryDemoAgent.sessionCwd)
  ) async throws -> DemoAgent {
    try await makeInProcess(
      serving: { InMemoryDemoACPAgent(connection: $0, script: script) },
      workingDirectory: workingDirectory
    )
  }

  /// Starts an agent in this process through ``InProcessAgent``, and sends
  /// `initialize`. The agent has no transport factory and no terminal
  /// sign-in.
  ///
  /// - Parameters:
  ///   - makeAgent: Makes the agent from the agent side of the connection.
  ///   - workingDirectory: The working directory of each new session.
  ///   - waitForTeardown: The wait of ``stop()`` for the teardown of the
  ///     agent, or `nil` when the agent needs no wait.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of `initialize`.
  private static func makeInProcess(
    serving makeAgent: @Sendable (AgentSideConnection) -> any Agent,
    workingDirectory: AbsolutePath,
    waitForTeardown: TeardownWait? = nil
  ) async throws -> DemoAgent {
    let connection = await InProcessAgent.makeConnection(serving: makeAgent)
    return try await makeStarted(
      connection: connection,
      workingDirectory: workingDirectory,
      terminalAuthRunner: nil,
      makeTransport: nil,
      waitForTeardown: waitForTeardown
    )
  }

  /// Makes the agent from its parts, and starts it with
  /// ``connectAndInitialize()``.
  ///
  /// - Parameters:
  ///   - connection: The model. It is connected already when `makeTransport`
  ///     is `nil`.
  ///   - workingDirectory: The working directory of each new session.
  ///   - terminalAuthRunner: The runner of the `terminal` auth methods, or
  ///     `nil`.
  ///   - makeTransport: The transport factory, or `nil`.
  ///   - waitForTeardown: The wait of ``stop()`` for the teardown of an agent
  ///     in this process, or `nil`.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the factory, or the error of `initialize`.
  private static func makeStarted(
    connection: ConnectionModel,
    workingDirectory: AbsolutePath,
    terminalAuthRunner: (any TerminalAuthRunner)?,
    makeTransport: TransportFactory?,
    waitForTeardown: TeardownWait? = nil
  ) async throws -> DemoAgent {
    let agent = DemoAgent(
      connection: connection,
      workingDirectory: workingDirectory,
      terminalAuthRunner: terminalAuthRunner,
      makeTransport: makeTransport,
      waitForTeardown: waitForTeardown
    )
    try await agent.connectAndInitialize()
    return agent
  }

  /// Connects ``connection`` over a new transport of the transport factory,
  /// and sends ``initializeRequest``. When the request fails, stops the agent.
  ///
  /// The in-memory agent has no transport factory: ``InProcessAgent``
  /// connected its model, so the call only sends `initialize`.
  ///
  /// - Throws: The error of the factory, or the error of `initialize`.
  private func connectAndInitialize() async throws {
    if let makeTransport {
      _ = await connection.connect(over: try makeTransport())
    }
    do {
      _ = try await connection.initialize(initializeRequest)
    } catch {
      await stop()
      throw error
    }
  }

  /// Whether ``reconnect(onOpen:)`` can make a new transport. Give
  /// ``reconnect(onOpen:)`` to the `agentReconnect` environment value of the
  /// kit views only when this is `true`.
  public var canReconnect: Bool {
    makeTransport != nil
  }

  /// Sends `session/new` in ``workingDirectory``, and gives the new session to
  /// `onOpen`.
  ///
  /// The call sends the request through ``perform(_:)``. When the agent
  /// answers `-32000`, the call throws, and this type keeps the request. After
  /// a sign-in, ``retryFailedOperation()`` or ``reconnect(onOpen:)`` sends it
  /// one more time, and gives that session to `onOpen`. Thus the first
  /// session and each New Session request get the same retry.
  ///
  /// - Parameter onOpen: Shows the new session. The connection model also
  ///   keeps it in `openSessions`.
  /// - Throws: The error of `session/new`.
  public func openSession(onOpen: @escaping SessionHandler) async throws {
    try await perform(makeOpenSessionOperation(onOpen: onOpen))
  }

  /// Makes the operation that sends `session/new` in ``workingDirectory``,
  /// and gives the new session to `onOpen`.
  ///
  /// - Parameter onOpen: Shows the new session.
  /// - Returns: The operation.
  private func makeOpenSessionOperation(onOpen: @escaping SessionHandler) -> Operation {
    let request = NewSessionRequest(cwd: workingDirectory)
    return { [connection] in onOpen(try await connection.newSession(request)) }
  }

  /// Runs an operation, and keeps it when it fails with `-32000`.
  ///
  /// After a sign-in, ``retryFailedOperation()`` or
  /// ``reconnect(onOpen:)`` runs the kept operation one more time.
  ///
  /// - Parameter operation: The operation.
  /// - Throws: The error of the operation.
  private func perform(_ operation: @escaping Operation) async throws {
    do {
      try await operation()
    } catch {
      if Self.isAuthenticationRequired(error) {
        failedOperation = operation
      }
      throw error
    }
  }

  /// Gives the kept operation and forgets it, so that it runs one time only.
  ///
  /// - Returns: The operation that failed with `-32000`, or `nil`.
  private func takeFailedOperation() -> Operation? {
    defer { failedOperation = nil }
    return failedOperation
  }

  /// Runs the operation that failed with `-32000` one more time, after a
  /// sign-in with an `agent` method.
  ///
  /// The kit sign-in card calls `ConnectionModel.login(_:)`, and the model
  /// then sets `authState` to `.authenticated`. The model does not retry the
  /// operation, so the host calls this method when it sees that change.
  /// When `authState` is not `.authenticated`, or when no operation is kept,
  /// the call does nothing. The call forgets the operation before it runs
  /// it, so a second call does not run it again. When the operation fails
  /// with `-32000` again, ``perform(_:)`` keeps it again.
  ///
  /// - Throws: The error of the retried operation.
  public func retryFailedOperation() async throws {
    guard case .authenticated = connection.authState, let operation = takeFailedOperation() else { return }
    try await perform(operation)
  }

  /// Connects to the agent again after a successful terminal sign-in, and
  /// shows a session of the new connection.
  ///
  /// When `authState` is not `.reconnectRequired`, the call does nothing.
  /// Otherwise the call closes the open connection, which closes each open
  /// session model, and starts it again with ``connectAndInitialize()``: a
  /// new transport, and the same `initialize` request. When `authState` is
  /// then `.authenticated`, the call runs one operation through
  /// ``perform(_:)``:
  ///
  /// - the kept operation that failed with `-32000`, which gives its session
  ///   to its own handler, or
  /// - when no operation is kept (for example after a prompt of an open
  ///   session failed with `-32000`), a new `session/new`, which gives the
  ///   new session to `onOpen`.
  ///
  /// In each other state, the call runs nothing.
  ///
  /// - Parameter onOpen: Shows the new session when no operation is kept.
  /// - Throws: The error of the factory, of `initialize` or of the
  ///   operation.
  public func reconnect(onOpen: @escaping SessionHandler) async throws {
    guard case .reconnectRequired = connection.authState, canReconnect else { return }
    await connection.disconnect()
    try await connectAndInitialize()
    guard case .authenticated = connection.authState else { return }
    try await perform(takeFailedOperation() ?? makeOpenSessionOperation(onOpen: onOpen))
  }

  /// Stops the agent with `ConnectionModel.disconnect()`. When the call
  /// returns, the state of ``connection`` is `.disconnected`.
  ///
  /// The disconnect stops the read of the transport. For the in-process
  /// agent, the `InMemoryTransport.pair()` of ``InProcessAgent`` then ends
  /// the input of the agent side, and the agent stops. An agent process gets
  /// a group kill when its transport stops. For FoundationModelsACPAgent in
  /// this process, the call then waits until the agent closed each open
  /// session.
  public func stop() async {
    await connection.disconnect()
    await waitForTeardown?()
  }
}
