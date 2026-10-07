import Foundation
import FoundationModelsACPClient
import OSLog

/// The `TerminalAuthRunner` of the demo app. It runs the agent program in a
/// Terminal.app window for a `terminal` auth method of the agent.
///
/// A run writes a shell script into a new temporary directory, and opens the
/// script in a terminal. The script runs the agent command, with the arguments
/// of the method appended and the environment of the method applied, so that
/// the user can type into the process. When the process ends, the script
/// writes its exit status to a status file. The runner reads that file, and
/// then deletes the directory.
///
/// The run gives `nil` when it cannot start the process: an environment name
/// that the shell cannot read, a script that the runner cannot write, or a
/// script that the terminal cannot open. The run also gives `nil` when the user
/// stops the script: a hang-up (the window closes), an interrupt (Control-C)
/// or a terminate signal. The runner logs the reason of each start failure.
///
/// The demo app gives this runner only when it starts the agent as an
/// `AgentProcess`, because only then does it know the agent command.
public nonisolated final class TerminalAppAuthRunner: TerminalAuthRunner {
  /// Opens a script file in an interactive terminal.
  ///
  /// The opener returns when the terminal has the script, not when the script
  /// ends. It returns `false` when the terminal cannot open the script.
  public typealias ScriptOpener = @Sendable (URL) async -> Bool

  /// The program that opens a file in an application.
  static let openProgram = "/usr/bin/open"

  /// The option of ``openProgram`` that names the application.
  static let applicationOption = "-a"

  /// The application that runs the script.
  static let terminalApplication = "Terminal"

  /// The exit status of a program that succeeded.
  static let successStatus: Int32 = 0

  /// The name of the script file. Terminal.app runs a `.command` file.
  static let scriptName = "sign-in.command"

  /// The name of the file that gets the exit status.
  static let statusName = "exit-status"

  /// The text that the script writes to the status file when the user stops
  /// it. It is not a number, so it gives no exit status.
  static let stoppedText = "stopped"

  /// The signals that stop the script: the window closes, the user presses
  /// Control-C, or a process sends a terminate signal.
  static let stopSignals = "HUP INT TERM"

  /// The permissions of the script file: the owner can read, write and run it.
  static let scriptPermissions = 0o700

  /// The time between two reads of the status file.
  static let statusPollInterval = Duration.milliseconds(200)

  /// The prefix of the name of the temporary directory of a run.
  static let directoryPrefix = "AgentViewKitDemo-sign-in-"

  /// The log of the runner.
  private static let logger = Logger(subsystem: "AgentViewKitDemo", category: "TerminalAppAuthRunner")

  /// The absolute path of the agent program.
  let command: String

  /// The arguments of the agent program in the ACP connection. The arguments
  /// of a method come after them.
  let arguments: [String]

  /// The opener of each script.
  private let openScript: ScriptOpener

  /// Makes a runner for an agent program.
  ///
  /// - Parameters:
  ///   - command: The absolute path of the agent program.
  ///   - arguments: The arguments of the agent program in the ACP connection.
  ///   - openScript: The opener of each script. The default opens the script
  ///     in Terminal.app.
  public init(command: String, arguments: [String], openScript: @escaping ScriptOpener = openInTerminal) {
    self.command = command
    self.arguments = arguments
    self.openScript = openScript
  }

  public func runTerminalAuth(arguments: [String], environment: [String: String]) async throws -> Int32? {
    let directory = FileManager.default.temporaryDirectory
      .appending(path: Self.directoryPrefix + UUID().uuidString, directoryHint: .isDirectory)
    defer { try? FileManager.default.removeItem(at: directory) }
    let statusFile = directory.appending(path: Self.statusName)
    let script: URL
    do {
      script = try writeScript(
        in: directory, statusFile: statusFile, arguments: arguments, environment: environment)
    } catch {
      Self.logger.error("The sign-in script was not written: \(String(describing: error), privacy: .public)")
      return nil
    }
    guard await openScript(script) else {
      Self.logger.error("The terminal did not open the sign-in script.")
      return nil
    }
    return try await waitForExitStatus(in: statusFile)
  }

  /// Writes the script of one run into a new directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to make for the script.
  ///   - statusFile: The file that gets the exit status.
  ///   - arguments: The arguments of the method.
  ///   - environment: The environment of the method.
  /// - Returns: The script file, which its owner can run.
  /// - Throws: ``TerminalAppAuthRunnerError`` for an environment name that the
  ///   shell cannot read, or the error of the file system.
  private func writeScript(
    in directory: URL, statusFile: URL, arguments: [String], environment: [String: String]
  ) throws -> URL {
    let text = try Self.makeScript(
      command: [command] + self.arguments + arguments, environment: environment, statusFile: statusFile)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let script = directory.appending(path: Self.scriptName)
    try text.write(to: script, atomically: true, encoding: .utf8)
    try FileManager.default.setAttributes([.posixPermissions: Self.scriptPermissions], ofItemAtPath: script.path)
    return script
  }

  /// Reads the status file until the script writes it.
  ///
  /// - Parameter statusFile: The file that gets the exit status.
  /// - Returns: The exit status, or `nil` when the user stopped the script.
  /// - Throws: `CancellationError` when the calling task is cancelled.
  private func waitForExitStatus(in statusFile: URL) async throws -> Int32? {
    while true {
      if let text = try? String(contentsOf: statusFile, encoding: .utf8) {
        return Int32(text)
      }
      try await Task.sleep(for: Self.statusPollInterval)
    }
  }

  /// Makes the text of the script of one run.
  ///
  /// The script quotes each word, so that no argument and no value can run as
  /// shell code. It writes the status through a second file and a rename, so
  /// that a read of the status file never sees a part of the text.
  ///
  /// - Parameters:
  ///   - command: The agent program and all its arguments.
  ///   - environment: The variables to apply over the launch environment.
  ///   - statusFile: The file that gets the exit status.
  /// - Returns: The text of the script.
  /// - Throws: ``TerminalAppAuthRunnerError/invalidEnvironmentName(_:)`` for a
  ///   name that the shell cannot read.
  static func makeScript(command: [String], environment: [String: String], statusFile: URL) throws -> String {
    let exports = try environment.sorted { $0.key < $1.key }.map { name, value in
      guard isShellName(name) else { throw TerminalAppAuthRunnerError.invalidEnvironmentName(name) }
      return "export \(name)=\(quoted(value))"
    }
    let statusPath = quoted(statusFile.path(percentEncoded: false))
    let lines =
      [
        "#!/bin/sh",
        "status_file=\(statusPath)",
        #"report() { printf '%s' "$1" > "$status_file.partial" && mv "$status_file.partial" "$status_file"; }"#,
        "trap 'report \(stoppedText); exit 1' \(stopSignals)",
      ] + exports + [
        command.map(quoted).joined(separator: " "),
        #"report "$?""#,
      ]
    return lines.joined(separator: "\n") + "\n"
  }

  /// Quotes a word for the shell.
  ///
  /// - Parameter word: The word.
  /// - Returns: The word in single quotes. Each single quote in the word ends
  ///   the quote, adds an escaped quote, and starts a new quote.
  static func quoted(_ word: String) -> String {
    "'" + word.replacingOccurrences(of: "'", with: #"'\''"#) + "'"
  }

  /// Tells whether the shell can read a name as a variable name: a letter or
  /// an underscore, and then letters, digits and underscores.
  ///
  /// - Parameter name: The name of the variable.
  /// - Returns: `true` when the shell can read the name.
  static func isShellName(_ name: String) -> Bool {
    guard let first = name.unicodeScalars.first, isShellNameStart(first) else { return false }
    return name.unicodeScalars.dropFirst().allSatisfy { isShellNameStart($0) || ("0"..."9").contains($0) }
  }

  /// Tells whether a scalar can start a shell variable name.
  ///
  /// - Parameter scalar: The scalar.
  /// - Returns: `true` for an ASCII letter or an underscore.
  private static func isShellNameStart(_ scalar: Unicode.Scalar) -> Bool {
    ("a"..."z").contains(scalar) || ("A"..."Z").contains(scalar) || scalar == "_"
  }

  /// Opens a script in Terminal.app with `/usr/bin/open -a Terminal`.
  ///
  /// - Parameter script: The script file.
  /// - Returns: `true` when `open` exits with status zero.
  public static func openInTerminal(_ script: URL) async -> Bool {
    let arguments = [applicationOption, terminalApplication, script.path(percentEncoded: false)]
    return await run(program: openProgram, arguments: arguments) == successStatus
  }

  /// Runs a program, and waits until it ends.
  ///
  /// - Parameters:
  ///   - program: The absolute path of the program.
  ///   - arguments: The arguments of the program.
  /// - Returns: The exit status of the program, or `nil` when the program
  ///   does not start. The runner logs the reason of a start failure.
  static func run(program: String, arguments: [String]) async -> Int32? {
    await withCheckedContinuation { continuation in
      let process = Process()
      process.executableURL = URL(filePath: program)
      process.arguments = arguments
      process.terminationHandler = { ended in
        continuation.resume(returning: ended.terminationStatus)
      }
      do {
        try process.run()
      } catch {
        let reason = String(describing: error)
        logger.error("The program \(program, privacy: .public) did not start: \(reason, privacy: .public)")
        continuation.resume(returning: nil)
      }
    }
  }
}

/// The errors of ``TerminalAppAuthRunner``.
public enum TerminalAppAuthRunnerError: Error, Equatable, Sendable {
  /// The name of an environment variable of the method is not a name that the
  /// shell can read.
  case invalidEnvironmentName(String)
}
