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

    let session = try await ACPTestTimeLimit.run(stopping: agent.stop) { try await agent.openSession() }

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
}
