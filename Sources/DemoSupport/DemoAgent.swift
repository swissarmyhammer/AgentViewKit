import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPAgent
import FoundationModelsACPClient

/// The agent of the demo app, and the `ConnectionModel` that talks to it.
///
/// Each agent of the demo app runs in the app process through
/// ``InProcessAgent``. The demo app starts no agent program. The views of the
/// demo app bind to ``connection`` and to the `SessionModel` objects that it
/// opens. This type keeps no copy of a model value: the connection state, the
/// auth state, the sessions, the auth methods and the capability flags stay
/// in the models.
///
/// - The ACP tab starts the agent of the launch options with
///   ``makeInProcess(options:)``: FoundationModelsACPAgent with the live
///   model, or ``InMemoryDemoACPAgent`` for `--in-memory-agent`.
/// - The Gallery tab starts FoundationModelsACPAgent with the stub model over
///   a ``RecordedSessionsStage``, with ``makeInProcess(recordedSessions:)``,
///   and the in-memory agent with each script of its sidebar.
///
/// No agent has a terminal sign-in, because no agent runs as a program that
/// a terminal can start.
///
/// ACP sign-in with an `agent` method: `ConnectionModel.login(_:)` sets
/// `authState` to `.authenticated` on the open connection. The model does not
/// retry the operation that failed with `-32000`, so
/// ``openSession(onOpen:)`` keeps that operation. The host sees the change of
/// `authState` and calls ``retryFailedOperation()``, which runs the kept
/// operation one more time.
public final class DemoAgent {
  /// Shows a session that ``openSession(onOpen:)`` or
  /// ``retryFailedOperation()`` opened.
  public typealias SessionHandler = (SessionModel) -> Void

  /// Waits until an agent in this process closed each open session, after
  /// the close of its connection.
  public typealias TeardownWait = @Sendable () async -> Void

  /// An operation that can fail with `-32000` (authentication required).
  private typealias Operation = () async throws -> Void

  /// The `info` that the demo app sends in its `initialize` request.
  public static let clientInfo = Implementation(name: "AgentViewKitDemo", version: "1.0.0")

  /// The dotfolder name of FoundationModelsACPAgent in the demo app. It is
  /// not `acp-agent`, so the agent does not read the configuration of the
  /// `acp-agent` program of the user.
  static let agentDotfolderName = "agentviewkit-demo"

  /// The connection model of the client side. The views read its state
  /// directly.
  public let connection: ConnectionModel

  /// The working directory of each new session and of the session list:
  /// from the launch options, or the working directory of a stage of
  /// recorded sessions.
  public let workingDirectory: AbsolutePath

  /// The `initialize` request that the demo sends.
  public let initializeRequest = DemoAgent.makeInitializeRequest()

  /// The wait of ``stop()`` for the teardown of an agent in this process, or
  /// `nil` when the agent needs no wait.
  private let waitForTeardown: TeardownWait?

  /// The operation that failed with `-32000`, or `nil`.
  /// ``retryFailedOperation()`` runs it one more time after a sign-in.
  private var failedOperation: Operation?

  /// Makes the agent from its parts.
  ///
  /// - Parameters:
  ///   - connection: The connected model.
  ///   - workingDirectory: The working directory of each new session.
  ///   - waitForTeardown: The wait of ``stop()``, or `nil`.
  private init(connection: ConnectionModel, workingDirectory: AbsolutePath, waitForTeardown: TeardownWait?) {
    self.connection = connection
    self.workingDirectory = workingDirectory
    self.waitForTeardown = waitForTeardown
  }

  /// Makes the `initialize` request of the demo app. It advertises only the
  /// capabilities that the kit views show. It advertises no terminal
  /// sign-in, because the demo has no terminal auth runner.
  ///
  /// - Returns: The request.
  public static func makeInitializeRequest() -> InitializeRequest {
    InitializeRequest.makeAgentViewKitRequest(info: clientInfo, terminalAuthRunner: nil)
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

  /// Starts the agent of the ACP tab in this process, and sends `initialize`.
  ///
  /// The agent is ``DemoLaunchOptions/acpAgent``:
  ///
  /// - ``DemoACPAgent/inMemory``: ``InMemoryDemoACPAgent`` with the
  ///   ``InMemoryDemoScript/standard`` script.
  /// - ``DemoACPAgent/foundationModels(_:)``: FoundationModelsACPAgent
  ///   through the package, with the model of the model source. The live
  ///   model can download and load the model of the agent profile before
  ///   the call returns.
  ///
  /// The working directory of each session is ``DemoLaunchOptions/cwd``.
  ///
  /// - Parameter options: The launch options of the demo app.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the composition of FoundationModelsACPAgent, or
  ///   the error of `initialize`.
  public static func makeInProcess(options: DemoLaunchOptions) async throws -> DemoAgent {
    let workingDirectory = AbsolutePath(rawValue: options.cwd)
    switch options.acpAgent {
    case .inMemory:
      return try await makeInProcess(workingDirectory: workingDirectory)
    case .foundationModels(let modelSource):
      return try await makeInProcess(foundationModelsIn: workingDirectory, modelSource: modelSource)
    }
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
    try await makeInProcess(
      foundationModelsIn: AbsolutePath(rawValue: stage.workingDirectory.path(percentEncoded: false)),
      modelSource: .stub,
      transcriptLocation: .path(stage.transcriptsDirectory)
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

  /// Composes FoundationModelsACPAgent with the dotfolder name of the demo,
  /// starts it in this process through ``InProcessAgent``, and sends
  /// `initialize`.
  ///
  /// ``stop()`` waits until the agent closed each open session.
  ///
  /// - Parameters:
  ///   - workingDirectory: The working directory of the start-up
  ///     configuration and of each new session.
  ///   - modelSource: The model path of the agent.
  ///   - transcriptLocation: The transcript location that wins over each
  ///     configuration layer, or `nil` for the location of the agent
  ///     configuration.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of the composition of the agent, or the error of
  ///   `initialize`.
  private static func makeInProcess(
    foundationModelsIn workingDirectory: AbsolutePath,
    modelSource: ComposedAgent.ModelSource,
    transcriptLocation: TranscriptLocation? = nil
  ) async throws -> DemoAgent {
    let composed = try await ComposedAgent.compose(
      name: try DotfolderName(agentDotfolderName),
      workingDirectory: URL(filePath: workingDirectory.rawValue),
      modelSource: modelSource,
      transcriptLocation: transcriptLocation
    )
    return try await makeInProcess(
      serving: { composed.agent(boundTo: $0) },
      workingDirectory: workingDirectory,
      waitForTeardown: composed.waitForConnectionTeardown
    )
  }

  /// Starts an agent in this process through ``InProcessAgent``, and sends
  /// `initialize`.
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
      waitForTeardown: waitForTeardown
    )
  }

  /// Makes the agent over a connected model, and sends ``initializeRequest``.
  /// When the request fails, the function stops the agent.
  ///
  /// - Parameters:
  ///   - connection: The connected model.
  ///   - workingDirectory: The working directory of each new session.
  ///   - waitForTeardown: The wait of ``stop()`` for the teardown of an agent
  ///     in this process, or `nil`.
  /// - Returns: The agent, with a connected and initialized model.
  /// - Throws: The error of `initialize`.
  static func makeStarted(
    connection: ConnectionModel,
    workingDirectory: AbsolutePath,
    waitForTeardown: TeardownWait? = nil
  ) async throws -> DemoAgent {
    let agent = DemoAgent(
      connection: connection,
      workingDirectory: workingDirectory,
      waitForTeardown: waitForTeardown
    )
    do {
      _ = try await connection.initialize(agent.initializeRequest)
    } catch {
      await agent.stop()
      throw error
    }
    return agent
  }

  /// Sends `session/new` in ``workingDirectory``, and gives the new session to
  /// `onOpen`.
  ///
  /// The call sends the request through ``perform(_:)``. When the agent
  /// answers `-32000`, the call throws, and this type keeps the request. After
  /// a sign-in, ``retryFailedOperation()`` sends it one more time, and gives
  /// that session to `onOpen`. Thus the first session and each New Session
  /// request get the same retry.
  ///
  /// - Parameter onOpen: Shows the new session. The connection model also
  ///   keeps it in `openSessions`.
  /// - Throws: The error of `session/new`.
  public func openSession(onOpen: @escaping SessionHandler) async throws {
    let request = NewSessionRequest(cwd: workingDirectory)
    try await perform { [connection] in onOpen(try await connection.newSession(request)) }
  }

  /// Runs an operation, and keeps it when it fails with `-32000`.
  ///
  /// After a sign-in, ``retryFailedOperation()`` runs the kept operation one
  /// more time.
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

  /// Stops the agent with `ConnectionModel.disconnect()`. When the call
  /// returns, the state of ``connection`` is `.disconnected`.
  ///
  /// The disconnect stops the read of the transport. The
  /// `InMemoryTransport.pair()` of ``InProcessAgent`` then ends the input of
  /// the agent side, and the agent stops. For FoundationModelsACPAgent, the
  /// call then waits until the agent closed each open session.
  public func stop() async {
    await connection.disconnect()
    await waitForTeardown?()
  }
}
