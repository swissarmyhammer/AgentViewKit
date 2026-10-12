import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import PackageFileSupport
import Testing

@testable import AgentViewKit
@testable import DemoSupport

/// Tests of the agent of the Gallery tab: FoundationModelsACPAgent runs in this
/// process over a stage of the recorded sessions of the demo app, with the stub
/// model. No test starts a program.
///
/// The recorded sessions of the demo app are replaced over time, so no test
/// reads their content or counts them.
@Suite struct RecordedSessionsAgentTests {
  /// The directory of the recorded sessions of the demo app, relative to the
  /// package root.
  static let recordingsPath = "Examples/AgentViewKitDemo/RecordedSessions"

  /// The agent of one test, and the temporary directory of its stage.
  struct Scenario {
    /// The temporary directory that holds the stage.
    let directory: TemporaryDirectory

    /// The agent, connected and initialized.
    let agent: DemoAgent

    /// Stops the agent and removes the stage.
    func stop() async {
      await agent.stop()
      directory.remove()
    }
  }

  /// Copies the recorded sessions of the demo app to a new stage, and starts
  /// the agent over it.
  ///
  /// - Returns: The scenario.
  /// - Throws: The error of the stage or of the start.
  static func start() async throws -> Scenario {
    let directory = try TemporaryDirectory()
    let stage = try RecordedSessionsStage.make(
      copying: try PackageFiles.file(recordingsPath), below: directory.url)
    let agent = try await DemoAgent.makeInProcess(recordedSessions: stage)
    return Scenario(directory: directory, agent: agent)
  }

  /// Lists the sessions of the agent in its working directory, as the
  /// session list of the Gallery tab does.
  ///
  /// - Parameter agent: The agent.
  /// - Returns: The listed sessions.
  /// - Throws: The error of `session/list`.
  static func listSessions(of agent: DemoAgent) async throws -> [SessionInfo] {
    try await agent.connection.refreshSessions(cwd: agent.workingDirectory)
    return agent.connection.sessions
  }

  @Test func theAgentListsTheRecordedSessions() async throws {
    let scenario = try await Self.start()

    let sessions = try await Self.listSessions(of: scenario.agent)

    #expect(!sessions.isEmpty)
    await scenario.stop()
  }

  @Test func aResumeFromTheStartReplaysEachRecordedSession() async throws {
    let scenario = try await Self.start()
    let connection = scenario.agent.connection

    for info in try await Self.listSessions(of: scenario.agent) {
      let request = ResumeSessionRequest.makeAgentViewKitRequest(
        sessionId: info.sessionId, cwd: info.cwd, additionalDirectories: info.additionalDirectories ?? [],
        replayFrom: .start(ReplayFromStart()))

      let session = try await connection.resumeSession(request)

      #expect(!session.transcript.isEmpty, "\(info.sessionId)")
    }
    await scenario.stop()
  }

  @Test func theAgentRunsInThisProcessWithNoTerminalSignIn() async throws {
    let scenario = try await Self.start()

    #expect(scenario.agent.connection.state == .connected)
    #expect(scenario.agent.terminalAuthRunner == nil)
    #expect(!scenario.agent.canReconnect)
    await scenario.stop()
  }

  @Test func stopMakesTheStateOfTheModelDisconnected() async throws {
    let scenario = try await Self.start()

    await scenario.stop()

    #expect(await waitUntil { scenario.agent.connection.state == .disconnected })
  }
}
