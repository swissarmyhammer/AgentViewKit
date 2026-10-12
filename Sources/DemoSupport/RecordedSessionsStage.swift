import Foundation

/// A temporary copy of the recorded sessions that the Gallery tab of the demo
/// app gives to FoundationModelsACPAgent.
///
/// The recordings directory holds one directory for each recording. Each
/// recording is one transcript location of FoundationModelsACPAgent as the
/// agent wrote it: the `sessions.jsonl` index, one directory for each
/// session, and other files such as `.gitattributes`.
///
/// The `transcripts.location` configuration of the agent names one
/// directory, so ``make(copying:below:)`` makes one transcript location from
/// all the recordings:
///
/// - It copies each session directory and each other file of each recording
///   as it is. When two recordings have a file with the same name, the file
///   of the first recording stays.
/// - It joins the lines of each `sessions.jsonl` in one `sessions.jsonl`, in
///   the name order of the recordings. Each line of the index is one whole
///   record, and git merges the file with `merge=union`, so a join of the
///   lines is a correct index.
/// - It copies no file from the top of the recordings directory, such as a
///   README.
///
/// The agent writes to its transcript location when it restores a session.
/// The stage is a copy, so the agent never changes the recordings.
///
/// The stage also writes the user configuration of the agent, which sets
/// `transcripts.location` to the copy, and gives an empty working directory
/// for `session/list`. ``agentEnvironment(adding:)`` gives the environment
/// of the agent process: `XDG_CONFIG_HOME` names the configuration of the
/// stage, so the agent does not read or write the configuration of the user.
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

  /// The variable that names the directory of the user configuration of the
  /// agent.
  public static let configurationHomeVariable = "XDG_CONFIG_HOME"

  /// The name of the configuration directory of `acp-agent` below
  /// ``configurationHomeVariable``.
  static let agentConfigurationDirectoryName = "acp-agent"

  /// The name of the configuration file of the agent.
  static let configurationFileName = "config.yaml"

  /// The name of the index file of a transcript location.
  static let indexFileName = "sessions.jsonl"

  /// The name of the transcript location below ``root``.
  static let transcriptsDirectoryName = "transcripts"

  /// The name of the configuration home below ``root``.
  static let configurationHomeDirectoryName = "configuration"

  /// The name of the working directory below ``root``.
  static let workingDirectoryName = "working-directory"

  /// The start of the name of each stage directory.
  static let stageNamePrefix = "AgentViewKitDemo-RecordedSessions-"

  /// The byte that ends each line of the index.
  static let lineEnd = UInt8(ascii: "\n")

  /// The directory that holds the stage.
  public let root: URL

  /// The transcript location of the agent: the copy of the recordings.
  public var transcriptsDirectory: URL {
    root.appending(path: Self.transcriptsDirectoryName, directoryHint: .isDirectory)
  }

  /// The directory that ``configurationHomeVariable`` names for the agent.
  public var configurationHome: URL {
    root.appending(path: Self.configurationHomeDirectoryName, directoryHint: .isDirectory)
  }

  /// The empty working directory of the agent process and of `session/list`.
  public var workingDirectory: URL {
    root.appending(path: Self.workingDirectoryName, directoryHint: .isDirectory)
  }

  /// The configuration file of the agent below ``configurationHome``.
  var configurationFile: URL {
    configurationHome
      .appending(path: Self.agentConfigurationDirectoryName, directoryHint: .isDirectory)
      .appending(path: Self.configurationFileName, directoryHint: .notDirectory)
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
    var index = Data()
    for recording in try directories(in: recordings) {
      index.append(try stage.copy(recording))
    }
    try index.write(to: stage.transcriptsDirectory.appending(path: indexFileName, directoryHint: .notDirectory))
    try Data(stage.makeConfigurationText().utf8).write(to: stage.configurationFile)
    return stage
  }

  /// The environment of the agent process: `base` with
  /// ``configurationHomeVariable`` set to ``configurationHome``.
  ///
  /// - Parameter base: The environment to start from.
  /// - Returns: The environment.
  public func agentEnvironment(
    adding base: [String: String] = ProcessInfo.processInfo.environment
  ) -> [String: String] {
    base.merging([Self.configurationHomeVariable: configurationHome.path(percentEncoded: false)]) { $1 }
  }

  /// Makes the text of the configuration file. The location is a JSON
  /// string, which is also a YAML string, so that each path reads correctly.
  ///
  /// - Returns: The text.
  /// - Throws: The error of the JSON encoder.
  private func makeConfigurationText() throws -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = .withoutEscapingSlashes
    let location = try encoder.encode(transcriptsDirectory.path(percentEncoded: false))
    return "transcripts:\n  location: \(String(decoding: location, as: UTF8.self))\n"
  }

  /// Makes the transcript location, the configuration directory of the
  /// agent, and the working directory.
  ///
  /// - Throws: The error of the file manager.
  private func makeDirectories() throws {
    for directory in [transcriptsDirectory, configurationFile.deletingLastPathComponent(), workingDirectory] {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }
  }

  /// Copies each directory and each file of one recording into
  /// ``transcriptsDirectory``, except its index.
  ///
  /// A file whose name the transcript location has already keeps the file
  /// of the first recording. A session directory whose name the transcript
  /// location has already is an error.
  ///
  /// - Parameter recording: The directory of the recording.
  /// - Returns: The lines of the index of the recording, each with its line
  ///   end, or no data when the recording has no index.
  /// - Throws: The error of the file manager.
  private func copy(_ recording: URL) throws -> Data {
    var index = Data()
    for item in try Self.contents(of: recording) {
      let name = item.lastPathComponent
      guard name != Self.indexFileName else {
        index = try Self.indexLines(of: item)
        continue
      }
      let destination = transcriptsDirectory.appending(path: name)
      let isKeptFile =
        !Self.isDirectory(item) && FileManager.default.fileExists(atPath: destination.path(percentEncoded: false))
      guard !isKeptFile else { continue }
      try FileManager.default.copyItem(at: item, to: destination)
    }
    return index
  }

  /// The bytes of an index file, with a line end after the last line.
  ///
  /// - Parameter file: The index file.
  /// - Returns: The bytes.
  /// - Throws: The error of the read.
  private static func indexLines(of file: URL) throws -> Data {
    var data = try Data(contentsOf: file)
    if let last = data.last, last != lineEnd {
      data.append(lineEnd)
    }
    return data
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
