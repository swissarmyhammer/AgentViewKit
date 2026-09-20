import AgentViewKit
import AgentViewKitACP
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Observation

/// The ACP session of the demo app's ACP tab.
///
/// The model connects a ``SwiftUIACPClient`` over a transport, sends
/// `initialize` and `session/new`, and binds an ``ACPThreadSource`` and an
/// ``ACPThreadActions`` to one ``AgentThread``. A selection in the session
/// sidebar resumes the selected session on a new thread.
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

  /// The session pages of the agent, or `nil` before the connection.
  public private(set) var sessionList: ACPSessionList?

  /// The id of the bound session, or `nil`.
  public private(set) var sessionID: SessionID?

  /// Whether the agent sends the `session/delete` capability.
  public private(set) var canDeleteSessions = false

  /// The authentication methods that the agent gave at `initialize`.
  public private(set) var authMethods: [AgentViewKit.AuthMethod] = []

  /// The store with the connection of the agent.
  public let connectionStore: ConnectionStore

  /// The client that holds the observable ACP state.
  @ObservationIgnored private let client = SwiftUIACPClient()

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
  /// ``DemoLaunchOptions/agentCommand`` as an `AgentProcess`. A program that
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
      let process = try AgentProcess(command: options.agentCommand)
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
    let connection = await client.connect(over: transport)
    self.connection = connection
    do {
      let response = try await connection.initialize(Self.initializeRequest)
      negotiatedVersion = response.protocolVersion
      authMethods = (response.authMethods ?? []).compactMap(SessionUpdateMapping.authMethod)
      canDeleteSessions = response.capabilities.session?.delete != nil
      sessionList = ACPSessionList(connection: connection, cwd: cwd)
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

  /// Resumes the session `id` and binds it to a new thread.
  ///
  /// - Parameter id: The id of the session to resume.
  public func selectSession(_ id: SessionID) async {
    guard let connection, id != sessionID else { return }
    let wireID = SessionId(rawValue: id.rawValue)
    do {
      let updates = connection.updates(for: wireID)
      let response = try await connection.resumeSession(
        ResumeSessionRequest(cwd: AbsolutePath(rawValue: cwd), sessionId: wireID))
      bind(wireID, updates: updates, configOptions: response.configOptions ?? [])
    } catch {
      fail(error)
    }
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
    guard let connection else { return }
    let response = try await connection.newSession(NewSessionRequest(cwd: AbsolutePath(rawValue: cwd)))
    let updates = connection.updates(for: response.sessionId)
    bind(response.sessionId, updates: updates, configOptions: response.configOptions ?? [])
  }

  /// Binds a session to a new thread.
  ///
  /// - Parameters:
  ///   - wireID: The id of the session.
  ///   - updates: The update stream of the session.
  ///   - configOptions: The config options that the agent gave for the
  ///     session.
  private func bind(_ wireID: SessionId, updates: AsyncStream<SessionUpdate>, configOptions: [SessionConfigOption]) {
    guard let connection else { return }
    stopBinding()
    let thread = AgentThread()
    let source = ACPThreadSource(thread: thread, updates: updates, agentName: agentName)
    let requested = Self.initializeRequest.protocolVersion
    source.acceptProtocolVersion(negotiatedVersion ?? requested, requested: requested)
    for change in SessionUpdateMapping.changes(for: .configOptionUpdate(ConfigOptionUpdate(configOptions: configOptions))) {
      thread.apply(change)
    }
    let client = client
    bindingTasks = [
      Task { await source.run() },
      Task { await source.mirrorPendingRequests(of: client.session(for: wireID), client: client, sessionId: wireID) },
    ]
    actions = ACPThreadActions(
      thread: thread,
      client: client,
      connection: connection,
      sessionId: wireID,
      connectionStore: connectionStore,
      agentProgram: agentProgram
    )
    self.thread = thread
    sessionID = SessionID(wireID.rawValue)
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
