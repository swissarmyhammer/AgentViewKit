import DemoSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// The agent of the Gallery tab in one test, and the temporary directory of
/// its stage: FoundationModelsACPAgent runs in this process over a stage of
/// the recorded sessions of the demo app, with the stub model.
///
/// The agent tests of the recorded sessions, the tests of ``DemoAgent`` and
/// the hosted tests of the Gallery tab share this scenario.
public struct RecordedSessionsScenario {
  /// The directory of the recorded sessions of the demo app.
  ///
  /// This file is `Sources/AgentViewKitTestSupport/` below the package root,
  /// so the root is two directories above the folder of the file.
  public static let recordingsDirectory = URL(filePath: #filePath)
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .deletingLastPathComponent()
    .appending(path: "Examples/AgentViewKitDemo/RecordedSessions", directoryHint: .isDirectory)

  /// The temporary directory that holds the stage.
  public let directory: TemporaryFolder

  /// The stage of the recorded sessions that the agent runs over.
  public let stage: RecordedSessionsStage

  /// The agent, connected and initialized.
  public let agent: DemoAgent

  /// Stops the agent and removes the stage.
  public func stop() async {
    await agent.stop()
    directory.remove()
  }

  /// Copies the recorded sessions of the demo app to a new stage, and starts
  /// the agent over it.
  ///
  /// - Returns: The scenario.
  /// - Throws: The error of the stage or of the start.
  public static func start() async throws -> RecordedSessionsScenario {
    let directory = try TemporaryFolder(prefix: TestFolderPrefix.agentViewKit)
    let stage = try RecordedSessionsStage.make(
      copying: recordingsDirectory, below: directory.url)
    let agent = try await DemoAgent.makeInProcess(recordedSessions: stage)
    return RecordedSessionsScenario(directory: directory, stage: stage, agent: agent)
  }

  /// Lists the sessions of the agent in its working directory, as the
  /// session list of the Gallery tab does.
  ///
  /// - Parameter agent: The agent.
  /// - Returns: The listed sessions.
  /// - Throws: The error of `session/list`.
  public static func listSessions(of agent: DemoAgent) async throws -> [SessionInfo] {
    try await agent.connection.refreshSessions(cwd: agent.workingDirectory)
    return agent.connection.sessions
  }

  /// Lists the sessions of the agent, resumes each one from the start, and
  /// gives each resumed session to `body`, one at a time.
  ///
  /// - Parameters:
  ///   - agent: The agent.
  ///   - body: The work on one listed session and its resumed model.
  /// - Throws: The error of a request, or of `body`.
  public static func resumeEachSessionFromTheStart(
    of agent: DemoAgent, _ body: (SessionInfo, SessionModel) async throws -> Void
  ) async throws {
    for info in try await listSessions(of: agent) {
      let session = try await agent.connection.resumeSession(resumeFromStartRequest(of: info))
      try await body(info, session)
    }
  }

  /// The `session/resume` request of a listed session, with a replay from
  /// the start, as the Gallery tab sends it.
  ///
  /// The request sends the same `cwd` and the full list of additional
  /// directories of the session again, and no `additionalDirectories` when
  /// that list is empty, as each kit view that resumes a session does.
  ///
  /// - Parameter info: The listed session.
  /// - Returns: The request.
  public static func resumeFromStartRequest(of info: SessionInfo) -> ResumeSessionRequest {
    let additionalDirectories = info.additionalDirectories ?? []
    return ResumeSessionRequest(
      cwd: info.cwd, sessionId: info.sessionId,
      additionalDirectories: additionalDirectories.isEmpty ? nil : additionalDirectories,
      replayFrom: .start(ReplayFromStart()))
  }
}
