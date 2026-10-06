import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Observation

/// The ACP session of the demo app's ACP tab.
///
/// The model connects a `ConnectionModel` over a transport, sends
/// `initialize` and `session/new`, and binds an ``ACPThreadSource`` and an
/// ``ACPThreadActions`` to one ``AgentThread``. The session sidebar shows the
/// session list of ``connectionModel``. It resumes a selected session with
/// the retained history of the agent, and ``open(_:)`` binds that session on
/// a new thread.
///
/// The model also keeps the values of the settings sheet: the
/// ``ConnectionStore`` with one connection for the agent, and the
/// authentication methods of the agent.
@Observable
public final class ACPDemoSession {
  /// The connection state of the model.
  public enum Phase: Equatable {
    /// No transport is connected.
    case idle
    /// The model sends `initialize` and `session/new`.
    case connecting
    /// A session is bound to ``ACPDemoSession/thread``.
    case ready
    /// The connection failed, with the text to show.
    case failed(String)
  }

  /// The id of the agent connection in ``connectionStore``.
  public static let agentConnectionID = ConnectionID("agent")

  /// The display name of the agent.
  public let agentName: String

  /// The working directory of each new or resumed session.
  public let cwd: String

  /// The connection state of the model.
  public private(set) var phase = Phase.idle

  /// The thread of the bound session.
  public private(set) var thread = AgentThread()

  /// The actions of the bound session, or `nil` before the first session.
  public private(set) var actions: ACPThreadActions?

  /// The model of the bound session, or `nil` before the first session. It
  /// holds the pending requests that the thread view shows.
  public private(set) var sessionModel: SessionModel?

  /// The id of the bound session, or `nil`.
  public private(set) var sessionID: SessionId?

  /// The authentication methods that the agent gave at `initialize`.
  public private(set) var authMethods: [AgentViewKit.AuthMethod] = []

  /// The store with the connection of the agent.
  public let connectionStore: ConnectionStore

  /// The connection model that holds the observable ACP state. The session
  /// sidebar shows its session list and its capability flags.
  @ObservationIgnored public let connectionModel = ConnectionModel()

  /// The connection to the agent, or `nil` before the connection.
  @ObservationIgnored private var connection: ClientSideConnection?

  /// The agent program that terminal authentication starts, or `nil`.
  @ObservationIgnored private var agentProgram: ACPAgentProgram?

  /// The protocol version of the `initialize` answer, or `nil` before the
  /// answer.
  @ObservationIgnored private var negotiatedVersion: ProtocolVersion?

  /// The tasks that fill the bound thread.
  @ObservationIgnored private var bindingTasks: [Task<Void, Never>] = []

  /// The in-memory agent that ``start(options:)`` started, or `nil`. The
  /// model keeps the agent, because the agent reads its frames only while it
  /// is alive.
  @ObservationIgnored private var inMemoryAgent: ScriptedWireAgent?

  /// The agent process that ``start(options:)`` started, or `nil`.
  @ObservationIgnored private var process: AgentProcess?

  /// Makes a model with no connection for the agent of `options`.
  ///
  /// - Parameter options: The launch options of the demo app.
  public convenience init(options: DemoLaunchOptions) {
    self.init(agentName: options.agentName, cwd: options.cwd)
  }

  /// Makes a model with no connection.
  ///
  /// - Parameters:
  ///   - agentName: The display name of the agent.
  ///   - cwd: The absolute path of the working directory of each session.
  public init(agentName: String, cwd: String) {
    self.agentName = agentName
    self.cwd = cwd
    connectionStore = ConnectionStore(connections: [
      Connection(id: Self.agentConnectionID, name: agentName)
    ])
  }

  /// The `initialize` request of the demo app.
  static var initializeRequest: InitializeRequest {
    InitializeRequest(
      info: Implementation(name: "AgentViewKitDemo", version: "1.0.0"),
      protocolVersion: ACPClient.supportedProtocolVersion,
      capabilities: ACPClient.advertisedCapabilities
    )
  }

  // MARK: - Connection

  /// Starts the agent of `options` and connects to it.
  ///
  /// With ``DemoLaunchOptions/usesInMemoryAgent``, the model starts
  /// ``InMemoryDemoAgent`` in this process. Otherwise it starts
  /// ``DemoLaunchOptions/agentCommand`` as an `AgentProcess`, with the
  /// arguments of ``DemoLaunchOptions/agentArguments(for:)``. A program that
  /// does not start moves ``phase`` to ``Phase/failed(_:)``.
  ///
  /// - Parameter options: The launch options of the demo app.
  public func start(options: DemoLaunchOptions) async {
    guard phase == .idle else { return }
    if options.usesInMemoryAgent {
      let (clientEnd, agentEnd) = InMemoryTransport.pair()
      inMemoryAgent = InMemoryDemoAgent.start(on: agentEnd)
      await connect(over: clientEnd)
      return
    }
    do {
      let process = try AgentProcess(
        command: options.agentCommand,
        arguments: DemoLaunchOptions.agentArguments(for: options.agentCommand)
      )
      self.process = process
      await connect(over: process.transport, agentProgram: ACPAgentProgram(path: options.agentCommand))
    } catch {
      fail(error)
    }
  }

  /// Connects over `transport`, sends `initialize`, and opens a new session.
  ///
  /// A failure moves ``phase`` to ``Phase/failed(_:)`` and the agent
  /// connection to ``ConnectionState/error(_:)``.
  ///
  /// - Parameters:
  ///   - transport: The transport to the agent.
  ///   - agentProgram: The agent program that terminal authentication
  ///     starts, or `nil`.
  public func connect(over transport: any ACPTransport, agentProgram: ACPAgentProgram? = nil) async {
    phase = .connecting
    self.agentProgram = agentProgram
    let connection = await connectionModel.connect(over: transport)
    self.connection = connection
    do {
      let response = try await connectionModel.initialize(Self.initializeRequest)
      negotiatedVersion = response.protocolVersion
      authMethods = connectionModel.authMethods.compactMap(SessionUpdateMapping.authMethod)
      connectionStore.transition(Self.agentConnectionID, to: .connected)
      try await openNewSession()
      phase = .ready
    } catch {
      fail(error)
    }
  }

  /// Opens a new session and binds it to a new thread.
  public func newSession() async {
    do {
      try await openNewSession()
    } catch {
      fail(error)
    }
  }

  /// Binds a session model that the session sidebar resumed to a new
  /// thread.
  ///
  /// The sidebar resumes the session with ``connectionModel`` and all its
  /// retained history, so the new thread starts with the replayed
  /// transcript.
  ///
  /// - Parameter session: The model of the resumed session.
  public func open(_ session: SessionModel) {
    bind(ACPThreadSource(thread: AgentThread(), session: session, agentName: agentName))
  }

  /// Closes the connection, stops the tasks of the bound thread, and stops
  /// the agent that ``start(options:)`` started.
  public func disconnect() async {
    stopBinding()
    await connection?.close()
    connection = nil
    inMemoryAgent?.stop()
    inMemoryAgent = nil
    process?.shutdown()
    process = nil
    phase = .idle
  }

  /// Sends `session/new` and binds the new session.
  private func openNewSession() async throws {
    guard connection != nil else { return }
    let source = try await ACPThreadSource.openNewSession(
      NewSessionRequest(cwd: AbsolutePath(rawValue: cwd)), on: connectionModel, thread: AgentThread(),
      agentName: agentName)
    bind(source)
  }

  /// Binds the session of a source and its thread.
  ///
  /// - Parameter source: The source of the session. The connection model
  ///   made its session model.
  private func bind(_ source: ACPThreadSource) {
    guard let session = source.session else { return }
    stopBinding()
    let requested = Self.initializeRequest.protocolVersion
    source.acceptProtocolVersion(negotiatedVersion ?? requested, requested: requested)
    bindingTasks = [Task { await source.run() }]
    actions = ACPThreadActions(
      thread: source.thread,
      session: session,
      connection: connectionModel,
      agentProgram: agentProgram
    )
    thread = source.thread
    sessionModel = session
    sessionID = session.sessionId
  }

  /// Cancels the tasks that fill the bound thread.
  private func stopBinding() {
    for task in bindingTasks {
      task.cancel()
    }
    bindingTasks = []
  }

  /// Records a failure in ``phase`` and in the agent connection.
  private func fail(_ error: any Error) {
    let message = String(describing: error)
    phase = .failed(message)
    connectionStore.transition(Self.agentConnectionID, to: .error(message))
  }
}
