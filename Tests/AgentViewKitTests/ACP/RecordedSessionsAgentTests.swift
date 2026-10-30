import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Tests of the agent of the Gallery tab: FoundationModelsACPAgent runs in this
/// process over a stage of the recorded sessions of the demo app, with the stub
/// model (``RecordedSessionsScenario``). No test starts a program. The hosted
/// tests of the Gallery tab are in `RecordedSessionsGalleryHostedTests` of the
/// IntegrationTests package.
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
  @Test func theAgentListsTheRecordedSessions() async throws {
    let scenario = try await RecordedSessionsScenario.start()

    let sessions = try await RecordedSessionsScenario.listSessions(of: scenario.agent)

    #expect(!sessions.isEmpty)
    await scenario.stop()
  }

  @Test func aResumeFromTheStartReplaysEachRecordedSession() async throws {
    let scenario = try await RecordedSessionsScenario.start()

    try await RecordedSessionsScenario.resumeEachSessionFromTheStart(of: scenario.agent) { info, session in
      #expect(!session.transcript.isEmpty, "\(info.sessionId)")
    }
    await scenario.stop()
  }

  @Test func aRunOfTheAgentLeavesTheProjectStoreOfTheHomeDirectoryUnchanged() async throws {
    let homeStore = FolderSnapshot(of: Self.homeProjectStore)
    let scenario = try await RecordedSessionsScenario.start()

    try await Self.openAndResumeEachSession(of: scenario.agent)
    await scenario.stop()

    #expect(FolderSnapshot(of: Self.homeProjectStore) == homeStore)
  }

  @Test func theAgentWritesAProjectFileIntoTheConfigurationDirectoryOfTheStage() async throws {
    let scenario = try await RecordedSessionsScenario.start()
    let stageStore = Self.projectStore(in: scenario.stage.configurationDirectory)

    try await Self.openAndResumeEachSession(of: scenario.agent)

    #expect(FolderSnapshot(of: stageStore).files.keys.contains { $0.hasSuffix(Self.projectFileExtension) })
    await scenario.stop()
  }
}

extension RecordedSessionsAgentTests {
  /// The name of the folder of the project store in the user layer of the
  /// agent. The store holds one markdown file for each project.
  static let projectStoreFolderName = "projects"

  /// The end of the name of each file of the project store.
  static let projectFileExtension = ".md"

  /// The folder of the project store of the agent below a configuration
  /// root: `<configuration root>/<dotfolder name>/projects/`.
  ///
  /// - Parameter configurationRoot: The configuration root of the agent.
  /// - Returns: The folder of the project store.
  static func projectStore(in configurationRoot: URL) -> URL {
    configurationRoot
      .appending(path: DemoAgent.agentDotfolderName, directoryHint: .isDirectory)
      .appending(path: projectStoreFolderName, directoryHint: .isDirectory)
  }

  /// The project store that the agent writes when it has no configuration
  /// root of its own: `~/.config/<dotfolder name>/projects/`.
  static var homeProjectStore: URL {
    projectStore(
      in: FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config", directoryHint: .isDirectory))
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

  /// The state of the files of one folder, by file name. A folder that does
  /// not exist has no files. The test reads the folder and changes nothing.
  struct FolderSnapshot: Equatable {
    /// The state of each file of the folder, by file name.
    let files: [String: FileSnapshot]

    /// Reads the state of the files of a folder.
    ///
    /// - Parameter folder: The folder.
    init(of folder: URL) {
      let names = (try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? []
      files = Dictionary(
        uniqueKeysWithValues: names.map { name in
          (name, FileSnapshot(of: folder.appending(path: name, directoryHint: .notDirectory)))
        })
    }
  }

  /// Opens a new session in the working directory of the agent, and resumes
  /// each listed session from the start. Each of the two requests makes the
  /// agent register a working directory in its project store, when that
  /// directory exists.
  ///
  /// - Parameter agent: The agent.
  /// - Throws: The error of a request.
  static func openAndResumeEachSession(of agent: DemoAgent) async throws {
    try await agent.openSession { _ in }
    try await RecordedSessionsScenario.resumeEachSessionFromTheStart(of: agent) { _, _ in }
  }
}
