import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Tests of ``DemoAgent``: the demo app starts its agent and binds its views
/// to the `ConnectionModel` and the `SessionModel` objects of the client.
///
/// Each test starts the in-memory demo agent through ``InProcessAgent``, and
/// reads the state of the models directly. ``DemoAgent`` keeps no copy of a
/// model value.
@Suite struct DemoAgentTests {
  /// The working directory of each test session.
  static let workingDirectory = "/tmp/demo-agent"

  /// The launch options that start the in-memory agent in
  /// ``workingDirectory``.
  static let inMemoryOptions = DemoLaunchOptions(arguments: [
    "app", InMemoryDemoAgent.launchArgument, DemoLaunchOptions.cwdArgument, workingDirectory,
  ])

  /// An agent program that is not an absolute path, so that `AgentProcess`
  /// does not start it.
  static let relativeProgram = "relative-agent"

  /// Starts the in-memory agent with the time limit of the ACP tests.
  ///
  /// - Returns: The connected agent.
  /// - Throws: The error of ``DemoAgent/makeConnected(options:)``.
  private static func makeInMemoryAgent() async throws -> DemoAgent {
    try await ACPTestTimeLimit.run(stopping: {}) {
      try await DemoAgent.makeConnected(options: inMemoryOptions)
    }
  }

  @Test func theInMemoryAgentGivesAConnectedModelWithTheAnswerOfInitialize() async throws {
    let agent = try await Self.makeInMemoryAgent()

    #expect(agent.connection.state == .connected)
    #expect(agent.connection.initializeResponse?.info.name == InMemoryDemoAgent.name)
    #expect(agent.connection.canDeleteSessions)
    await agent.stop()
  }

  @Test func openSessionOpensANewSessionInTheWorkingDirectoryOfTheOptions() async throws {
    let agent = try await Self.makeInMemoryAgent()

    let opened = DemoAgentTerminalSignInTests.OpenedSessions()

    try await ACPTestTimeLimit.run(stopping: agent.stop) {
      try await agent.openSession { opened.sessions.append($0) }
    }

    let session = try #require(opened.sessions.first)
    #expect(opened.sessions.count == 1)
    #expect(agent.workingDirectory == AbsolutePath(rawValue: Self.workingDirectory))
    #expect(session.sessionId == SessionId(rawValue: InMemoryDemoAgent.sessionID))
    #expect(agent.connection.session(for: session.sessionId) === session)
    await agent.stop()
  }

  @Test func stopMakesTheStateOfTheModelDisconnected() async throws {
    let agent = try await Self.makeInMemoryAgent()

    await agent.stop()

    #expect(await waitUntil { agent.connection.state == .disconnected })
  }

  @Test func aProgramThatIsNotAnAbsolutePathDoesNotStart() async {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.agentCommandArgument, Self.relativeProgram])

    await #expect(throws: AgentProcessError.commandNotAbsolute(Self.relativeProgram)) {
      try await DemoAgent.makeConnected(options: options)
    }
  }

  @Test func aResumeFromTheStartReplaysTheSavedHistoryOfTheSession() async throws {
    let agent = try await Self.makeInMemoryAgent()
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: InMemoryDemoAgent.sessionID),
      replayFrom: .start(ReplayFromStart()))

    let session = try await ACPTestTimeLimit.run(stopping: agent.stop) {
      try await agent.connection.resumeSession(request)
    }

    #expect(session.agentMessageText(id: InMemoryDemoAgent.historyReplyID) == InMemoryDemoAgent.historyReply)
    await agent.stop()
  }

  @Test func aResumeWithNoReplayGivesNoHistory() async throws {
    let agent = try await Self.makeInMemoryAgent()
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: InMemoryDemoAgent.sessionID))

    let session = try await ACPTestTimeLimit.run(stopping: agent.stop) {
      try await agent.connection.resumeSession(request)
    }

    #expect(session.transcript.isEmpty)
    await agent.stop()
  }

  @Test func theInMemoryAgentHasNoTerminalSignIn() async throws {
    let agent = try await Self.makeInMemoryAgent()

    #expect(agent.terminalAuthRunner == nil)
    #expect(!agent.canReconnect)
    #expect(agent.initializeRequest.capabilities.auth == nil)
    await agent.stop()
  }
}

/// Tests of the terminal sign-in of ``DemoAgent``: the runner, the
/// reconnect over a new transport, and the retry of the operation that
/// failed with `-32000`.
///
/// Each test gives two ``ScriptedWireAgent`` transports to the transport
/// factory of the demo agent. The first agent answers `session/new` with
/// `-32000`. The second agent opens the session.
@Suite struct DemoAgentTerminalSignInTests {
  /// The id of the terminal method of the scripted agents.
  static let terminalMethodID = AuthMethodId(rawValue: "terminal-login")

  /// The `authMethods` of an agent with one terminal method.
  static let terminalMethods =
    #"[{"type": "terminal", "methodId": "terminal-login", "name": "Terminal login", "args": ["--login"]}]"#

  /// The `authMethods` of an agent with no auth method.
  static let noMethods = "[]"

  /// The JSON-RPC code of an answer that requires authentication.
  static let authenticationRequiredCode = -32000

  /// The exit status of a terminal process that succeeded.
  static let successStatus: Int32 = 0

  /// The method of the operation that needs the sign-in.
  static let newSessionMethod = "session/new"

  /// The method of the initialize request.
  static let initializeMethod = "initialize"

  /// The id of the session that the second agent opens.
  static let signedInSessionID = "signed-in-session"

  /// The id of the session that the first agent opens before it asks for a
  /// sign-in.
  static let firstSessionID = "first-session"

  /// The JSON value of an empty capability object, `{}`.
  static let emptyCapability = AgentViewKit.JSONValue.object([:])

  /// The demo agent and the two scripted agents of one test.
  struct Scenario {
    /// The demo agent over the transports of the scripted agents.
    let agent: DemoAgent

    /// The agent of the first transport. It answers `session/new` with
    /// `-32000`.
    let first: ScriptedWireAgent

    /// The agent of the second transport.
    let second: ScriptedWireAgent

    /// Stops the demo agent and the two scripted agents.
    func stop() async {
      await agent.stop()
      first.stop()
      second.stop()
    }
  }

  /// Starts a scripted agent on a new transport pair.
  ///
  /// - Parameter authMethods: The `authMethods` of the `initialize` result.
  /// - Returns: The client end of the pair and the started agent.
  static func makeScriptedAgent(authMethods: String) -> (InMemoryTransport, ScriptedWireAgent) {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agent = ScriptedWireAgent(transport: agentEnd)
    agent.results[initializeMethod] = ScriptedSession.makeInitializeResult(
      info: ScriptedSession.agentInfo, authMethods: authMethods)
    agent.start()
    return (clientEnd, agent)
  }

  /// Connects a demo agent to the first of two scripted agents.
  ///
  /// - Parameters:
  ///   - runner: The terminal auth runner of the demo agent.
  ///   - secondAuthMethods: The `authMethods` of the second agent.
  /// - Returns: The scenario.
  /// - Throws: The error of `initialize`.
  static func makeScenario(
    runner: any TerminalAuthRunner, secondAuthMethods: String = terminalMethods
  ) async throws -> Scenario {
    let (firstEnd, first) = makeScriptedAgent(authMethods: terminalMethods)
    first.failingMethods = [newSessionMethod]
    first.errorCodes[newSessionMethod] = authenticationRequiredCode
    let (secondEnd, second) = makeScriptedAgent(authMethods: secondAuthMethods)
    second.results[newSessionMethod] = #"{"sessionId": "\#(signedInSessionID)"}"#
    var transports = [firstEnd, secondEnd]
    let agent = try await ACPTestTimeLimit.run(stopping: { first.stop() }) {
      try await DemoAgent.makeConnected(
        makeTransport: { transports.removeFirst() },
        terminalAuthRunner: runner,
        workingDirectory: AbsolutePath(rawValue: DemoAgentTests.workingDirectory)
      )
    }
    return Scenario(agent: agent, first: first, second: second)
  }

  /// Opens a session with ``DemoAgent/openSession(onOpen:)``, expects the
  /// `-32000` answer of the first agent, and records the session that each
  /// run of the operation opens.
  ///
  /// - Parameters:
  ///   - scenario: The scenario.
  ///   - opened: The box that gets the session of each run.
  /// - Returns: `opened`.
  @discardableResult
  static func openSessionExpectingSignIn(
    in scenario: Scenario, recordingInto opened: OpenedSessions = OpenedSessions()
  ) async -> OpenedSessions {
    let agent = scenario.agent
    let error = await ACPTestTimeLimit.run(stopping: scenario.stop) {
      await #expect(throws: RequestError.self) {
        try await agent.openSession { opened.sessions.append($0) }
      }
    }
    #expect(error?.code == .authenticationRequired)
    return opened
  }

  /// Runs the terminal method with `runner`, and ignores its error.
  ///
  /// - Parameters:
  ///   - scenario: The scenario.
  ///   - runner: The runner.
  static func runTerminalSignIn(in scenario: Scenario, with runner: any TerminalAuthRunner) async {
    try? await scenario.agent.connection.loginWithTerminal(terminalMethodID, runner: runner)
  }

  /// The sessions that the operation of a test opened, in open order.
  final class OpenedSessions {
    /// The sessions, in open order.
    var sessions: [SessionModel] = []
  }

  @Test func theInitializeFrameOfAProcessAgentAdvertisesTerminalAuth() async throws {
    let scenario = try await Self.makeScenario(runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))

    let frame = try #require(scenario.first.messages(method: Self.initializeMethod).first)

    #expect(frame["params"]?["capabilities"]?["auth"]?["terminal"] == Self.emptyCapability)
    #expect(scenario.agent.canReconnect)
    await scenario.stop()
  }

  @Test func aTerminalSignInAfterAnAnswerWithCode32000AsksForAReconnect() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let scenario = try await Self.makeScenario(runner: runner)
    await Self.openSessionExpectingSignIn(in: scenario)

    await Self.runTerminalSignIn(in: scenario, with: runner)

    #expect(scenario.agent.connection.authState == .reconnectRequired(Self.terminalMethodID))
    await scenario.stop()
  }

  @Test func reconnectSendsInitializeOnANewTransportAndThenRetriesTheFailedOperation() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let scenario = try await Self.makeScenario(runner: runner)
    let opened = await Self.openSessionExpectingSignIn(in: scenario)
    await Self.runTerminalSignIn(in: scenario, with: runner)

    try await ACPTestTimeLimit.run(stopping: scenario.stop) { try await scenario.agent.reconnect() }

    let second = scenario.second
    let initialize = try #require(second.messages(method: Self.initializeMethod).first)
    #expect(initialize["params"]?["capabilities"]?["auth"]?["terminal"] == Self.emptyCapability)
    let initializeIndex = try #require(second.index(ofMethod: Self.initializeMethod))
    let newSessionIndex = try #require(second.index(ofMethod: Self.newSessionMethod))
    #expect(initializeIndex < newSessionIndex)
    #expect(second.messages(method: Self.newSessionMethod).count == 1)
    #expect(opened.sessions.map(\.sessionId) == [SessionId(rawValue: Self.signedInSessionID)])
    #expect(scenario.agent.connection.authState == .authenticated(Self.terminalMethodID))
    await scenario.stop()
  }

  @Test func aNewSessionThatFailsWithCode32000OpensItsSessionAfterASignInAndAReconnect() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let scenario = try await Self.makeScenario(runner: runner)
    let first = scenario.first
    first.failingMethods = []
    first.results[Self.newSessionMethod] = #"{"sessionId": "\#(Self.firstSessionID)"}"#
    let agent = scenario.agent
    let opened = OpenedSessions()
    try await ACPTestTimeLimit.run(stopping: scenario.stop) {
      try await agent.openSession { opened.sessions.append($0) }
    }
    first.failingMethods = [Self.newSessionMethod]
    await Self.openSessionExpectingSignIn(in: scenario, recordingInto: opened)
    await Self.runTerminalSignIn(in: scenario, with: runner)

    try await ACPTestTimeLimit.run(stopping: scenario.stop) { try await agent.reconnect() }

    let expected = [Self.firstSessionID, Self.signedInSessionID].map { SessionId(rawValue: $0) }
    #expect(opened.sessions.map(\.sessionId) == expected)
    #expect(agent.connection.authState == .authenticated(Self.terminalMethodID))
    await scenario.stop()
  }

  @Test func aReconnectWhoseInitializeGivesNoSignInDoesNotRetry() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let scenario = try await Self.makeScenario(runner: runner, secondAuthMethods: Self.noMethods)
    let opened = await Self.openSessionExpectingSignIn(in: scenario)
    await Self.runTerminalSignIn(in: scenario, with: runner)

    try await ACPTestTimeLimit.run(stopping: scenario.stop) { try await scenario.agent.reconnect() }

    #expect(scenario.second.messages(method: Self.initializeMethod).count == 1)
    #expect(scenario.second.messages(method: Self.newSessionMethod).isEmpty)
    #expect(opened.sessions.isEmpty)
    #expect(scenario.agent.connection.authState == .notRequired)
    await scenario.stop()
  }

  @Test func aRunnerWithNoExitStatusGivesTheTerminalFailureAndNoReconnect() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: nil)
    let scenario = try await Self.makeScenario(runner: runner)
    await Self.openSessionExpectingSignIn(in: scenario)
    await Self.runTerminalSignIn(in: scenario, with: runner)

    try await ACPTestTimeLimit.run(stopping: scenario.stop) { try await scenario.agent.reconnect() }

    let failure = AuthFailure(
      operation: .terminalLogin(Self.terminalMethodID), reason: .terminal(exitStatus: nil, message: nil))
    #expect(scenario.agent.connection.authState == .failed(failure))
    #expect(scenario.second.messages(method: Self.initializeMethod).isEmpty)
    #expect(scenario.second.messages(method: Self.newSessionMethod).isEmpty)
    await scenario.stop()
  }
}
