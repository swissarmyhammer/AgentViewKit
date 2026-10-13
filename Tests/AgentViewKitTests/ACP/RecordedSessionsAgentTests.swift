import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import PackageFileSupport
import SwiftUI
import Testing

@testable import AgentViewKit
@testable import DemoSupport

/// Tests of the agent of the Gallery tab: FoundationModelsACPAgent runs in this
/// process over a stage of the recorded sessions of the demo app, with the stub
/// model. No test starts a program.
///
/// The recorded sessions of the demo app are replaced over time, so no test
/// reads their content or counts them.
///
/// The tests run one at a time. A resume of a recorded session whose working
/// directory exists opens the code-context index in that directory, and the
/// stages of all tests hold the same recorded working directories. Two
/// resumes at the same time open the same index database, and one of them
/// fails because the database is locked.
@Suite(.serialized) struct RecordedSessionsAgentTests {
  /// The directory of the recorded sessions of the demo app, relative to the
  /// package root.
  static let recordingsPath = "Examples/AgentViewKitDemo/RecordedSessions"

  /// The longest time that the session list test waits for a row, in
  /// seconds. It is the time that the end-to-end test of the Gallery tab
  /// waits for a row of the session list.
  static let rowTimeout: TimeInterval = 20

  /// The agent of one test, and the temporary directory of its stage.
  struct Scenario {
    /// The temporary directory that holds the stage.
    let directory: TemporaryDirectory

    /// The stage of the recorded sessions that the agent runs over.
    let stage: RecordedSessionsStage

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
    return Scenario(directory: directory, stage: stage, agent: agent)
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

  @Test(.hostedSerially) func theSessionListOfTheGalleryShowsARowOfARecordedSession() async throws {
    let scenario = try await Self.start()
    let harness = HostedViewHarness(
      SessionListView(connection: scenario.agent.connection, cwd: scenario.agent.workingDirectory, onOpen: { _ in }),
      size: SessionPickerConnectionModelHostedTests.listSize)

    await harness.pump(until: Self.rowTimeout) {
      !SessionPickerConnectionModelHostedTests.rowIdentifiers(in: harness).isEmpty
    }

    #expect(!SessionPickerConnectionModelHostedTests.rowIdentifiers(in: harness).isEmpty)
    harness.close()
    await scenario.stop()
  }

  @Test(.hostedSerially) func theGalleryDetailShowsATranscriptRowOfEachRecordedSession() async throws {
    try await Self.hostTheGalleryWindowOfEachSession { info, harness in
      #expect(!Self.transcriptRowIdentifiers(in: harness).isEmpty, "\(info.sessionId)")
    }
  }

  @Test(.hostedSerially) func theGalleryWindowOfEachRecordedSessionGetsNarrower() async throws {
    try await Self.hostTheGalleryWindowOfEachSession { info, harness in
      harness.window.styleMask.insert(.resizable)
      harness.window.setContentSize(CGSize(width: Self.narrowWindowWidth, height: GalleryWindowReplica.windowSize.height))
      harness.pump()

      #expect(harness.hostingView.frame.width == Self.narrowWindowWidth, "\(info.sessionId)")
    }
  }

  @Test func aResumeFromTheStartReplaysEachRecordedSession() async throws {
    let scenario = try await Self.start()

    try await Self.resumeEachSessionFromTheStart(of: scenario.agent) { info, session in
      #expect(!session.transcript.isEmpty, "\(info.sessionId)")
    }
    await scenario.stop()
  }

  @Test func aRunOfTheAgentLeavesTheProjectRegistryOfTheHomeDirectoryUnchanged() async throws {
    let homeRegistry = FileSnapshot(of: Self.homeProjectRegistry)
    let scenario = try await Self.start()

    try await Self.openAndResumeEachSession(of: scenario.agent)
    await scenario.stop()

    #expect(FileSnapshot(of: Self.homeProjectRegistry) == homeRegistry)
  }

  @Test func theAgentWritesItsProjectRegistryIntoTheConfigurationDirectoryOfTheStage() async throws {
    let scenario = try await Self.start()
    let stageRegistry = scenario.stage.configurationDirectory
      .appending(path: DemoAgent.agentDotfolderName, directoryHint: .isDirectory)
      .appending(path: Self.projectRegistryFileName, directoryHint: .notDirectory)

    try await Self.openAndResumeEachSession(of: scenario.agent)

    #expect(FileSnapshot(of: stageRegistry).contents != nil)
    await scenario.stop()
  }
}

extension RecordedSessionsAgentTests {
  /// The name of the project registry file in the user layer of the agent.
  static let projectRegistryFileName = "projects.jsonl"

  /// The project registry file that the agent writes when it has no
  /// configuration root of its own: `~/.config/<dotfolder name>/projects.jsonl`.
  static var homeProjectRegistry: URL {
    FileManager.default.homeDirectoryForCurrentUser
      .appending(path: ".config", directoryHint: .isDirectory)
      .appending(path: DemoAgent.agentDotfolderName, directoryHint: .isDirectory)
      .appending(path: projectRegistryFileName, directoryHint: .notDirectory)
  }

  /// The state of one file: its bytes and its modification date, or `nil`
  /// for each when the file does not exist. The test reads the file and
  /// changes nothing.
  struct FileSnapshot: Equatable {
    /// The bytes of the file, or `nil` when the file does not exist.
    let contents: Data?

    /// The modification date of the file, or `nil` when the file does not
    /// exist.
    let modificationDate: Date?

    /// Reads the state of a file.
    ///
    /// - Parameter file: The file.
    init(of file: URL) {
      let path = file.path(percentEncoded: false)
      contents = FileManager.default.contents(atPath: path)
      modificationDate = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
    }
  }

  /// Opens a new session in the working directory of the agent, and resumes
  /// each listed session from the start. Each of the two requests makes the
  /// agent register a working directory in its project registry, when that
  /// directory exists.
  ///
  /// - Parameter agent: The agent.
  /// - Throws: The error of a request.
  static func openAndResumeEachSession(of agent: DemoAgent) async throws {
    try await agent.openSession { _ in }
    try await resumeEachSessionFromTheStart(of: agent) { _, _ in }
  }

  /// Lists the sessions of the agent, resumes each one from the start, and
  /// gives each resumed session to `body`, one at a time.
  ///
  /// - Parameters:
  ///   - agent: The agent.
  ///   - body: The work on one listed session and its resumed model.
  /// - Throws: The error of a request, or of `body`.
  static func resumeEachSessionFromTheStart(
    of agent: DemoAgent, _ body: (SessionInfo, SessionModel) async throws -> Void
  ) async throws {
    for info in try await listSessions(of: agent) {
      let session = try await agent.connection.resumeSession(resumeFromStartRequest(of: info))
      try await body(info, session)
    }
  }

  /// A width of the Gallery window that is less than its first width, and
  /// more than the minimum widths of its columns, in points.
  static let narrowWindowWidth: CGFloat = 1100

  /// Resumes each listed session from the start, shows it in the window of
  /// the Gallery tab, waits for a transcript row, and runs `check`.
  ///
  /// - Parameter check: The checks of one session and its window.
  /// - Throws: The error of the start or of a request.
  static func hostTheGalleryWindowOfEachSession(
    _ check: (SessionInfo, HostedViewHarness<GalleryWindowReplica>) -> Void
  ) async throws {
    let scenario = try await start()
    let connection = scenario.agent.connection
    try await resumeEachSessionFromTheStart(of: scenario.agent) { info, session in
      let harness = HostedViewHarness(
        GalleryWindowReplica(session: session, connection: connection), size: GalleryWindowReplica.windowSize)
      await harness.pump(until: rowTimeout) { !transcriptRowIdentifiers(in: harness).isEmpty }
      check(info, harness)
      harness.close()
    }
    await scenario.stop()
  }

  /// The identifiers of the transcript rows that show.
  ///
  /// - Parameter harness: The harness that shows the transcript.
  /// - Returns: The row identifiers, in view order.
  static func transcriptRowIdentifiers(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements().compactMap(\.identifier).filter { $0.hasPrefix(ItemRow.identifierPrefix) }
  }

  /// The `session/resume` request of a listed session, with a replay from
  /// the start, as the Gallery tab sends it.
  ///
  /// - Parameter info: The listed session.
  /// - Returns: The request.
  static func resumeFromStartRequest(of info: SessionInfo) -> ResumeSessionRequest {
    ResumeSessionRequest.makeAgentViewKitRequest(
      sessionId: info.sessionId, cwd: info.cwd, additionalDirectories: info.additionalDirectories ?? [],
      replayFrom: .start(ReplayFromStart()))
  }
}
