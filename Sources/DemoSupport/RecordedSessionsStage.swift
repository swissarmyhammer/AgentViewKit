import Foundation

/// A temporary copy of the recorded sessions that the Gallery tab of the demo
/// app gives to FoundationModelsACPAgent.
///
/// The recordings directory holds one directory for each recording. Each
/// recording is one transcript location of FoundationModelsACPAgent as the
/// agent wrote it: one directory for each session, and other files such as
/// `.gitattributes`. Each session directory holds the whole record of its
/// session: the `index.md` whose frontmatter is the record that the agent
/// lists, and the transcript. No file of the transcript location lists the
/// sessions, so the stage writes no file of its own.
///
/// The transcript location of the agent is one directory, so
/// ``make(copying:below:)`` makes one transcript location from all the
/// recordings:
///
/// - It copies each session directory and each other file of each recording
///   as it is. When two recordings have a file with the same name, the file
///   of the first recording stays.
/// - It copies no file from the top of the recordings directory, such as a
///   README.
///
/// The agent writes to its transcript location when it restores a session.
/// The stage is a copy, so the agent never changes the recordings.
///
/// The stage also gives an empty working directory for the start of the
/// agent and for `session/list`, and a configuration directory for the user
/// layer of the agent. The user layer holds one file, ``profileFileName``,
/// that names ``recordedStandardModel``: the agent restores a session only
/// when the model that it recorded is the resident model of its slot, and the
/// default `standard` model of the agent is not the model of the recordings.
/// ``DemoAgent/makeInProcess(recordedSessions:)`` gives the transcript
/// location and ``agentEnvironment`` to the agent in code.
public struct RecordedSessionsStage: Equatable, Sendable {
  /// The error of a start that finds no recordings in the app bundle.
  nonisolated public struct MissingRecordingsError: LocalizedError, Equatable {
    /// Makes the error.
    public init() {}

    /// The text of the error. The failure label of the Gallery tab shows it.
    public var errorDescription: String? {
      "The app bundle has no \(RecordedSessionsStage.recordingsResourceName) directory."
    }
  }

  /// The name of the directory of the recorded sessions in the app bundle.
  /// The text of ``MissingRecordingsError`` reads it outside the main actor.
  nonisolated public static let recordingsResourceName = "RecordedSessions"

  /// The name of the transcript location below ``root``.
  static let transcriptsDirectoryName = "transcripts"

  /// The name of the working directory below ``root``.
  static let workingDirectoryName = "working-directory"

  /// The name of the configuration directory below ``root``.
  static let configurationDirectoryName = "configuration"

  /// The key of the environment that gives the agent its configuration
  /// root: the XDG Base Directory variable that FoundationModelsACPAgent
  /// reads its user layer from.
  static let configurationHomeKey = "XDG_CONFIG_HOME"

  /// The `standard` model that the recorded sessions of the demo app ran
  /// with, without a drafter. The agent restores a session only when this
  /// model is the resident model of its slot.
  nonisolated public static let recordedStandardModel = "mlx-community/Qwen3.8-27B-mxfp4"

  /// The name of the configuration file in the user layer of the agent.
  nonisolated public static let profileFileName = "config.yaml"

  /// The text of the configuration file: the profile with the
  /// ``recordedStandardModel`` in the `standard` slot.
  nonisolated static var profileText: String {
    "profile:\n  standard:\n    - \(recordedStandardModel)\n"
  }

  /// The start of the name of each stage directory.
  static let stageNamePrefix = "AgentViewKitDemo-RecordedSessions-"

  /// The directory that holds the stage.
  public let root: URL

  /// The transcript location of the agent: the copy of the recordings.
  public var transcriptsDirectory: URL {
    directory(named: Self.transcriptsDirectoryName)
  }

  /// The empty working directory of the start of the agent and of
  /// `session/list`.
  public var workingDirectory: URL {
    directory(named: Self.workingDirectoryName)
  }

  /// The configuration root of the agent: the user layer of the agent is the
  /// dotfolder below it. The agent writes its project store there, and not
  /// into `~/.config` of the home directory.
  public var configurationDirectory: URL {
    directory(named: Self.configurationDirectoryName)
  }

  /// The user layer of the agent: the dotfolder of the demo below
  /// ``configurationDirectory``.
  public var userLayerDirectory: URL {
    configurationDirectory.appending(path: DemoAgent.agentDotfolderName, directoryHint: .isDirectory)
  }

  /// The configuration file in ``userLayerDirectory``.
  public var profileFile: URL {
    userLayerDirectory.appending(path: Self.profileFileName, directoryHint: .notDirectory)
  }

  /// The directory with the name `name` directly below ``root``.
  ///
  /// - Parameter name: The name of the directory.
  /// - Returns: The URL of the directory.
  private func directory(named name: String) -> URL {
    root.appending(path: name, directoryHint: .isDirectory)
  }

  /// The environment that ``DemoAgent/makeInProcess(recordedSessions:)``
  /// gives to the agent in code. It holds only ``configurationDirectory`` as
  /// the configuration root, so the agent reads no value of the process
  /// environment and writes nothing into the home directory.
  public var agentEnvironment: [String: String] {
    [Self.configurationHomeKey: configurationDirectory.path(percentEncoded: false)]
  }

  /// The directory of the recorded sessions in a bundle.
  ///
  /// - Parameter bundle: The bundle that holds the recordings, for example
  ///   the app bundle.
  /// - Returns: The ``recordingsResourceName`` directory of the bundle.
  /// - Throws: ``MissingRecordingsError`` when the bundle has no such
  ///   directory.
  public static func recordingsDirectory(in bundle: Bundle = .main) throws -> URL {
    guard let directory = bundle.url(forResource: recordingsResourceName, withExtension: nil) else {
      throw MissingRecordingsError()
    }
    return directory
  }

  /// Makes a new stage below `parent`, and copies the recordings into it.
  ///
  /// - Parameters:
  ///   - recordings: The directory that holds one directory for each
  ///     recording.
  ///   - parent: The directory that gets the new stage directory.
  /// - Returns: The stage.
  /// - Throws: The error of the file manager when a read, a copy, or a write
  ///   fails, for example when two recordings have a session directory with
  ///   the same name.
  public static func make(
    copying recordings: URL, below parent: URL = FileManager.default.temporaryDirectory
  ) throws -> RecordedSessionsStage {
    let stage = RecordedSessionsStage(
      root: parent.appending(path: stageNamePrefix + UUID().uuidString, directoryHint: .isDirectory))
    try stage.makeDirectories()
    for recording in try directories(in: recordings) {
      try stage.copy(recording)
    }
    return stage
  }

  /// Makes the transcript location, the working directory, and the user
  /// layer in the configuration directory, and writes ``profileFile``.
  ///
  /// - Throws: The error of the file manager.
  private func makeDirectories() throws {
    for directory in [transcriptsDirectory, workingDirectory, userLayerDirectory] {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
    try Data(Self.profileText.utf8).write(to: profileFile)
  }

  /// Copies each directory and each file of one recording into
  /// ``transcriptsDirectory``.
  ///
  /// A file whose name the transcript location has already keeps the file
  /// of the first recording. A session directory whose name the transcript
  /// location has already is an error.
  ///
  /// - Parameter recording: The directory of the recording.
  /// - Throws: The error of the file manager.
  private func copy(_ recording: URL) throws {
    for item in try Self.contents(of: recording) {
      let destination = transcriptsDirectory.appending(path: item.lastPathComponent)
      let isKeptFile =
        !Self.isDirectory(item) && FileManager.default.fileExists(atPath: destination.path(percentEncoded: false))
      guard !isKeptFile else { continue }
      try FileManager.default.copyItem(at: item, to: destination)
    }
  }

  /// The directories in `directory`, in name order.
  ///
  /// - Parameter directory: The directory to read.
  /// - Returns: The directories.
  /// - Throws: The error of the file manager.
  private static func directories(in directory: URL) throws -> [URL] {
    try contents(of: directory).filter(isDirectory)
  }

  /// The items in `directory`, hidden files included, in name order.
  ///
  /// - Parameter directory: The directory to read.
  /// - Returns: The items.
  /// - Throws: The error of the file manager.
  private static func contents(of directory: URL) throws -> [URL] {
    try FileManager.default
      .contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey])
      .sorted { $0.lastPathComponent < $1.lastPathComponent }
  }

  /// Whether `item` is a directory.
  ///
  /// - Parameter item: The item.
  /// - Returns: `true` for a directory.
  private static func isDirectory(_ item: URL) -> Bool {
    (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true
  }
}
