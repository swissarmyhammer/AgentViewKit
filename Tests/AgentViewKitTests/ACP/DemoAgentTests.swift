import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Tests of ``DemoAgent``: the demo app starts its agent and binds its views
/// to the `ConnectionModel` and the `SessionModel` objects of the client.
///
/// Each test starts an agent in this process through ``InProcessAgent``, and
/// reads the state of the models directly. ``DemoAgent`` keeps no copy of a
/// model value. The tests over ``InProcessAgentFactory`` start each agent that
/// the demo runs: the in-memory demo agent, FoundationModelsACPAgent of the
/// ACP tab, and FoundationModelsACPAgent over the recorded sessions. No test
/// starts a program, and no test uses the live model: the agent of the ACP
/// tab runs with the stub model of the package.
@Suite struct DemoAgentTests {
  /// The working directory of each test session.
  static let workingDirectory = "/tmp/demo-agent"

  /// The launch options that start the in-memory agent in
  /// ``workingDirectory``.
  static let inMemoryOptions = DemoLaunchOptions(arguments: [
    "app", InMemoryDemoAgent.launchArgument, DemoLaunchOptions.cwdArgument, workingDirectory,
  ])

  /// Starts the in-memory agent.
  ///
  /// - Returns: The connected agent.
  /// - Throws: The error of ``DemoAgent/makeInProcess(options:environment:)``.
  private static func makeInMemoryAgent() async throws -> DemoAgent {
    try await DemoAgent.makeInProcess(options: inMemoryOptions)
  }

  /// The name of the configuration root of the ACP tab agent of a test,
  /// below its temporary working directory.
  static let configurationDirectoryName = "configuration"

  /// Starts FoundationModelsACPAgent as the ACP tab does, with the stub model
  /// in place of the live model, in a new temporary working directory. The
  /// configuration root of the agent is a directory below the temporary
  /// directory, so the agent writes nothing into the home directory.
  ///
  /// - Returns: The connected agent, and the temporary working directory.
  /// - Throws: The error of the directory or of the start.
  static func makeACPTabAgent() async throws -> (agent: DemoAgent, directory: TemporaryDirectory) {
    let directory = try TemporaryDirectory()
    var options = DemoLaunchOptions(arguments: [
      "app", DemoLaunchOptions.cwdArgument, directory.url.path(percentEncoded: false),
    ])
    options.acpAgent = .foundationModels(.stub)
    let configurationRoot = directory.url.appending(path: configurationDirectoryName, directoryHint: .isDirectory)
    let environment = [RecordedSessionsStageTests.configurationHomeKey: configurationRoot.path(percentEncoded: false)]
    return (try await DemoAgent.makeInProcess(options: options, environment: environment), directory)
  }

  @Test func anACPTabAgentOfATestLeavesTheProjectRegistryOfTheHomeDirectoryUnchanged() async throws {
    let homeRegistry = RecordedSessionsAgentTests.FileSnapshot(of: RecordedSessionsAgentTests.homeProjectRegistry)
    let started = try await Self.makeACPTabAgent()

    try await started.agent.openSession { _ in }
    await started.agent.stop()
    started.directory.remove()

    #expect(RecordedSessionsAgentTests.FileSnapshot(of: RecordedSessionsAgentTests.homeProjectRegistry) == homeRegistry)
  }

  /// The agents that the demo starts in this process. Each of them must pass
  /// the tests over this type.
  enum InProcessAgentFactory: CaseIterable {
    /// ``InMemoryDemoACPAgent`` with its script.
    case scriptedInMemory

    /// FoundationModelsACPAgent of the ACP tab, with the stub model.
    case acpTab

    /// FoundationModelsACPAgent over a stage of the recorded sessions.
    case recordedSessions

    /// Starts the agent.
    ///
    /// - Returns: The connected agent, and the removal of the files that the
    ///   start made.
    /// - Throws: The error of the start.
    func start() async throws -> (agent: DemoAgent, removeFiles: () -> Void) {
      switch self {
      case .scriptedInMemory:
        return (try await DemoAgentTests.makeInMemoryAgent(), {})
      case .acpTab:
        let started = try await DemoAgentTests.makeACPTabAgent()
        return (started.agent, started.directory.remove)
      case .recordedSessions:
        let scenario = try await RecordedSessionsAgentTests.start()
        return (scenario.agent, scenario.directory.remove)
      }
    }
  }

  @Test func theInMemoryAgentGivesAConnectedModelWithTheAnswerOfInitialize() async throws {
    let agent = try await Self.makeInMemoryAgent()

    #expect(agent.connection.state == .connected)
    #expect(agent.connection.initializeResponse?.info.name == InMemoryDemoAgent.name)
    #expect(agent.connection.canDeleteSessions)
    await agent.stop()
  }

  @Test func theACPTabAgentWorksInTheWorkingDirectoryOfTheOptions() async throws {
    let started = try await Self.makeACPTabAgent()
    let agent = started.agent

    #expect(agent.workingDirectory == AbsolutePath(rawValue: started.directory.url.path(percentEncoded: false)))
    #expect(agent.connection.initializeResponse?.info.name == DemoLaunchOptions.foundationModelsAgentName)
    await agent.stop()
    started.directory.remove()
  }

  @Test func openSessionOpensANewSessionInTheWorkingDirectoryOfTheOptions() async throws {
    let agent = try await Self.makeInMemoryAgent()

    let opened = DemoAgentSignInTests.OpenedSessions()

    try await agent.openSession { opened.sessions.append($0) }

    let session = try #require(opened.sessions.first)
    #expect(opened.sessions.count == 1)
    #expect(agent.workingDirectory == AbsolutePath(rawValue: Self.workingDirectory))
    #expect(session.sessionId == SessionId(rawValue: InMemoryDemoAgent.sessionID))
    #expect(agent.connection.session(for: session.sessionId) === session)
    await agent.stop()
  }

  @Test(arguments: InProcessAgentFactory.allCases)
  func stopMakesTheStateOfTheModelDisconnected(factory: InProcessAgentFactory) async throws {
    let started = try await factory.start()

    await started.agent.stop()

    #expect(await waitUntil { started.agent.connection.state == .disconnected })
    started.removeFiles()
  }

  @Test func aResumeFromTheStartReplaysTheSavedHistoryOfTheSession() async throws {
    let agent = try await Self.makeInMemoryAgent()
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: InMemoryDemoAgent.sessionID),
      replayFrom: .start(ReplayFromStart()))

    let session = try await agent.connection.resumeSession(request)

    #expect(session.agentMessageText(id: InMemoryDemoAgent.historyReplyID) == InMemoryDemoAgent.historyReply)
    await agent.stop()
  }

  @Test func aResumeWithNoReplayGivesNoHistory() async throws {
    let agent = try await Self.makeInMemoryAgent()
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: InMemoryDemoAgent.sessionID))

    let session = try await agent.connection.resumeSession(request)

    #expect(session.transcript.isEmpty)
    await agent.stop()
  }

  @Test(arguments: InProcessAgentFactory.allCases)
  func anAgentInThisProcessIsConnectedWithNoTerminalSignIn(factory: InProcessAgentFactory) async throws {
    let started = try await factory.start()
    let agent = started.agent

    #expect(agent.connection.state == .connected)
    #expect(agent.initializeRequest.capabilities.auth == nil)
    await agent.stop()
    started.removeFiles()
  }
}

/// Tests of the sign-in of ``DemoAgent`` with an `agent` method: the retry of
/// the operation that failed with `-32000`.
///
/// Each test connects the demo agent to a ``ScriptedWireAgent`` over an
/// `InMemoryTransport` pair. The scripted agent answers `session/new` with
/// `-32000` until the test lets it open the session.
@Suite struct DemoAgentSignInTests {
  /// The id of the agent method of the scripted agent.
  static let agentMethodID = AuthMethodId(rawValue: "agent-login")

  /// The `authMethods` of an agent with one agent method, which the agent
  /// runs through `auth/login`.
  static let agentMethods = #"[{"type": "agent", "methodId": "agent-login", "name": "Agent login"}]"#

  /// The JSON-RPC code of an answer that requires authentication.
  static let authenticationRequiredCode = -32000

  /// The method of the operation that needs the sign-in.
  static let newSessionMethod = "session/new"

  /// The number of `session/new` requests of one failed request and one
  /// retry.
  static let failedAndRetriedRequestCount = 2

  /// The method of the initialize request.
  static let initializeMethod = "initialize"

  /// The id of the session that the scripted agent opens after the sign-in.
  static let signedInSessionID = "signed-in-session"

  /// The demo agent and the scripted agent of one test.
  struct Scenario {
    /// The demo agent over the transport of the scripted agent.
    let agent: DemoAgent

    /// The scripted agent. It answers `session/new` with `-32000`.
    let scripted: ScriptedWireAgent

    /// Stops the demo agent and the scripted agent.
    func stop() async {
      await agent.stop()
      scripted.stop()
    }
  }

  /// Connects a demo agent to a scripted agent with one agent method, which
  /// answers `session/new` with `-32000`.
  ///
  /// - Returns: The scenario.
  /// - Throws: The error of `initialize`.
  static func makeScenario() async throws -> Scenario {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let scripted = ScriptedWireAgent(transport: agentEnd)
    scripted.results[initializeMethod] = ScriptedSession.makeInitializeResult(
      info: ScriptedSession.agentInfo, authMethods: agentMethods)
    scripted.failingMethods = [newSessionMethod]
    scripted.errorCodes[newSessionMethod] = authenticationRequiredCode
    scripted.start()
    let connection = ConnectionModel()
    _ = await connection.connect(over: clientEnd)
    let agent = try await DemoAgent.makeStarted(
      connection: connection, workingDirectory: AbsolutePath(rawValue: DemoAgentTests.workingDirectory))
    return Scenario(agent: agent, scripted: scripted)
  }

  /// Opens a session with ``DemoAgent/openSession(onOpen:)``, expects the
  /// `-32000` answer of the scripted agent, and records the session that
  /// each run of the operation opens.
  ///
  /// - Parameter scenario: The scenario.
  /// - Returns: The box that gets the session of each run.
  static func openSessionExpectingSignIn(in scenario: Scenario) async -> OpenedSessions {
    let opened = OpenedSessions()
    let agent = scenario.agent
    let error = await #expect(throws: RequestError.self) {
      try await agent.openSession { opened.sessions.append($0) }
    }
    #expect(error?.code == .authenticationRequired)
    return opened
  }

  /// The sessions that the operation of a test opened, in open order.
  final class OpenedSessions {
    /// The sessions, in open order.
    var sessions: [SessionModel] = []
  }

  @Test func anAgentLoginAfterAnAnswerWithCode32000RunsTheKeptNewSessionOneTime() async throws {
    let scenario = try await Self.makeScenario()
    let opened = await Self.openSessionExpectingSignIn(in: scenario)
    let scripted = scenario.scripted
    scripted.failingMethods = []
    scripted.results[Self.newSessionMethod] = #"{"sessionId": "\#(Self.signedInSessionID)"}"#
    let agent = scenario.agent

    try await agent.connection.login(LoginAuthRequest(methodId: Self.agentMethodID))
    try await agent.retryFailedOperation()
    try await agent.retryFailedOperation()

    #expect(agent.connection.authState == .authenticated(Self.agentMethodID))
    #expect(opened.sessions.map(\.sessionId) == [SessionId(rawValue: Self.signedInSessionID)])
    #expect(scripted.messages(method: Self.newSessionMethod).count == Self.failedAndRetriedRequestCount)
    await scenario.stop()
  }

  @Test func aRetryBeforeASignInSendsNoRequest() async throws {
    let scenario = try await Self.makeScenario()
    let opened = await Self.openSessionExpectingSignIn(in: scenario)

    try await scenario.agent.retryFailedOperation()

    #expect(opened.sessions.isEmpty)
    #expect(scenario.scripted.messages(method: Self.newSessionMethod).count == 1)
    await scenario.stop()
  }
}
