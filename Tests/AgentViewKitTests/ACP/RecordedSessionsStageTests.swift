import Foundation
import Testing

@testable import DemoSupport

/// The tests of ``RecordedSessionsStage``: the temporary copy of the recorded
/// sessions that the Gallery tab of the demo app gives to
/// FoundationModelsACPAgent.
///
/// Each test makes its own recordings in a temporary directory. The recorded
/// sessions of the demo app are replaced over time, so no test reads them.
@Suite struct RecordedSessionsStageTests {
  /// The name of the index file of a recording root.
  static let indexFileName = "sessions.jsonl"

  /// The failure text of a start that finds no recordings in the app bundle.
  static let missingRecordingsText = "The app bundle has no RecordedSessions directory."

  /// The key of the XDG configuration root in the environment of the agent.
  static let configurationHomeKey = "XDG_CONFIG_HOME"

  /// The name of the first recording. It sorts before ``secondRecording``.
  static let firstRecording = "alpha-recording"

  /// The name of the second recording.
  static let secondRecording = "beta-recording"

  /// The session directory of the first recording.
  static let firstSession = "01ARZ3NDEKTSV4RRFFQ69G5FAV"

  /// The session directory of the second recording.
  static let secondSession = "01BX5ZZKBKACTAV9WEVGEMMVRZ"

  /// The index line of the first recording, with its line end.
  static let firstIndexLine = #"{"sessionId":"01ARZ3NDEKTSV4RRFFQ69G5FAV"}"# + "\n"

  /// The index line of the second recording, with no line end.
  static let secondIndexLine = #"{"sessionId":"01BX5ZZKBKACTAV9WEVGEMMVRZ"}"#

  /// The name of a file at the top of the recordings, such as a README.
  static let topFileName = "README.md"

  /// The name of a file of a recording that is not the index and not a
  /// session directory.
  static let attributesFileName = ".gitattributes"

  /// The files of each session directory, by file name.
  static let sessionFiles = [
    "session.json": #"{"configuration":{}}"#,
    "session-history.json": #"{"updates":[]}"#,
    "transcript.jsonl": #"{"type":"session"}"# + "\n",
  ]

  /// The recordings of one test, in a temporary directory.
  struct Recordings {
    /// The temporary directory of the test. It holds the recordings and the
    /// stages.
    let directory: TemporaryDirectory

    /// The directory that holds the recordings.
    var url: URL { directory.url.appending(path: "recordings", directoryHint: .isDirectory) }

    /// The directory that holds the stages of the test.
    var stages: URL { directory.url.appending(path: "stages", directoryHint: .isDirectory) }

    /// Makes two recordings, each with one session, and a file at the top.
    ///
    /// - Throws: The error of a write.
    init() throws {
      directory = try TemporaryDirectory()
      try write(RecordedSessionsStageTests.firstIndexLine, to: "\(firstRecording)/\(indexFileName)")
      try write(RecordedSessionsStageTests.secondIndexLine, to: "\(secondRecording)/\(indexFileName)")
      try write("** linguist-generated=true\n", to: "\(firstRecording)/\(attributesFileName)")
      try write("# Recordings\n", to: topFileName)
      for (recording, session) in [(firstRecording, firstSession), (secondRecording, secondSession)] {
        for (name, contents) in sessionFiles {
          try write(contents, to: "\(recording)/\(session)/\(name)")
        }
      }
    }

    /// Writes a file below ``url``, and makes its directories.
    ///
    /// - Parameters:
    ///   - contents: The text of the file.
    ///   - path: The path of the file, relative to ``url``.
    /// - Throws: The error of the write.
    func write(_ contents: String, to path: String) throws {
      let file = url.appending(path: path, directoryHint: .notDirectory)
      try FileManager.default.createDirectory(
        at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
      try Data(contents.utf8).write(to: file)
    }

    /// The bytes of a file below ``url``.
    ///
    /// - Parameter path: The path of the file, relative to ``url``.
    /// - Returns: The bytes.
    /// - Throws: The error of the read.
    func data(at path: String) throws -> Data {
      try Data(contentsOf: url.appending(path: path, directoryHint: .notDirectory))
    }

    /// Makes a stage of the recordings below ``stages``.
    ///
    /// - Returns: The stage.
    /// - Throws: The error of the stage.
    func makeStage() throws -> RecordedSessionsStage {
      try RecordedSessionsStage.make(copying: url, below: stages)
    }
  }

  /// The bytes of a file below the transcript location of a stage.
  ///
  /// - Parameters:
  ///   - path: The path of the file, relative to the transcript location.
  ///   - stage: The stage.
  /// - Returns: The bytes.
  /// - Throws: The error of the read.
  static func stagedData(at path: String, of stage: RecordedSessionsStage) throws -> Data {
    try Data(contentsOf: stage.transcriptsDirectory.appending(path: path, directoryHint: .notDirectory))
  }

  /// Expects that `directory` is an empty directory below the root of
  /// `stage`.
  ///
  /// - Parameters:
  ///   - directory: The directory.
  ///   - stage: The stage.
  /// - Throws: The error of the read of the directory.
  static func expectEmptyDirectory(_ directory: URL, of stage: RecordedSessionsStage) throws {
    let contents = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
    #expect(contents.isEmpty)
    #expect(directory.path(percentEncoded: false).hasPrefix(stage.root.path(percentEncoded: false)))
  }

  @Test func theStageCopiesEachSessionDirectoryOfEachRecording() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    for (recording, session) in [(Self.firstRecording, Self.firstSession), (Self.secondRecording, Self.secondSession)] {
      for name in Self.sessionFiles.keys {
        let staged = try Self.stagedData(at: "\(session)/\(name)", of: stage)
        #expect(staged == (try recordings.data(at: "\(recording)/\(session)/\(name)")))
      }
    }
  }

  @Test func theStagedIndexHoldsTheLinesOfEachRecordingInNameOrder() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    let index = try Self.stagedData(at: Self.indexFileName, of: stage)
    #expect(String(decoding: index, as: UTF8.self) == Self.firstIndexLine + Self.secondIndexLine + "\n")
  }

  @Test func theStageCopiesTheOtherFilesOfARecording() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    let staged = try Self.stagedData(at: Self.attributesFileName, of: stage)
    #expect(staged == (try recordings.data(at: "\(Self.firstRecording)/\(Self.attributesFileName)")))
  }

  @Test func theStageCopiesNoFileFromTheTopOfTheRecordings() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    let topFile = stage.transcriptsDirectory.appending(path: Self.topFileName, directoryHint: .notDirectory)
    #expect(!FileManager.default.fileExists(atPath: topFile.path(percentEncoded: false)))
  }

  @Test func aChangeOfTheStagedCopyLeavesTheRecordingsUnchanged() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }
    let historyPath = "\(Self.firstSession)/session-history.json"
    let recorded = try recordings.data(at: "\(Self.firstRecording)/\(historyPath)")

    let stage = try recordings.makeStage()
    try Data("changed".utf8).write(
      to: stage.transcriptsDirectory.appending(path: historyPath, directoryHint: .notDirectory))

    #expect(try recordings.data(at: "\(Self.firstRecording)/\(historyPath)") == recorded)
  }

  @Test func theStageHoldsOnlyTheTranscriptLocationTheWorkingDirectoryAndTheConfigurationDirectory() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    let names = try FileManager.default.contentsOfDirectory(atPath: stage.root.path(percentEncoded: false))
    let expected = [stage.transcriptsDirectory, stage.workingDirectory, stage.configurationDirectory]
      .map(\.lastPathComponent)
    #expect(names.sorted() == expected.sorted())
  }

  @Test func theWorkingDirectoryIsAnEmptyDirectoryOfTheStage() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    try Self.expectEmptyDirectory(stage.workingDirectory, of: stage)
  }

  @Test func theConfigurationDirectoryIsAnEmptyDirectoryOfTheStage() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    try Self.expectEmptyDirectory(stage.configurationDirectory, of: stage)
  }

  @Test func theAgentEnvironmentPutsTheConfigurationRootInTheStage() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let stage = try recordings.makeStage()

    #expect(stage.agentEnvironment == [Self.configurationHomeKey: stage.configurationDirectory.path(percentEncoded: false)])
  }

  @Test func aBundleWithNoRecordingsGivesTheErrorDescriptionAsTheFailureText() throws {
    let bundleDirectory = try TemporaryDirectory()
    defer { bundleDirectory.remove() }
    let bundle = try #require(Bundle(url: bundleDirectory.url))

    let error = #expect(throws: RecordedSessionsStage.MissingRecordingsError.self) {
      try RecordedSessionsStage.recordingsDirectory(in: bundle)
    }

    #expect(DemoFailureText.text(of: try #require(error)) == Self.missingRecordingsText)
  }

  @Test func aBundleWithRecordingsGivesTheRecordingsDirectory() throws {
    let bundleDirectory = try TemporaryDirectory()
    defer { bundleDirectory.remove() }
    let recordings = bundleDirectory.url.appending(
      path: RecordedSessionsStage.recordingsResourceName, directoryHint: .isDirectory)
    try FileManager.default.createDirectory(at: recordings, withIntermediateDirectories: true)
    let bundle = try #require(Bundle(url: bundleDirectory.url))

    let directory = try RecordedSessionsStage.recordingsDirectory(in: bundle)

    #expect(directory.resolvingSymlinksInPath().pathComponents == recordings.resolvingSymlinksInPath().pathComponents)
  }

  @Test func eachStageIsANewDirectory() throws {
    let recordings = try Recordings()
    defer { recordings.directory.remove() }

    let first = try recordings.makeStage()
    let second = try recordings.makeStage()

    #expect(first.root != second.root)
  }
}
