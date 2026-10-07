import Foundation
import FoundationModelsACPClient
import Synchronization
import Testing

@testable import DemoSupport

/// Tests of ``TerminalAppAuthRunner``: the demo runner writes a script that
/// runs the agent command, opens the script in a terminal, and gives the exit
/// status that the script records.
///
/// The tests do not open Terminal.app. The opener of each test runs the script
/// with `/bin/sh` and waits until it ends, so the script runs as it runs in a
/// terminal window, with no window.
@Suite struct TerminalAppAuthRunnerTests {
  /// The shell that runs each command and each script of the tests.
  nonisolated static let shell = "/bin/sh"

  /// The shell option that reads a command from the next argument.
  static let commandOption = "-c"

  /// The name that the shell gives to `$0` of a `-c` command.
  static let commandName = "sign-in"

  /// A shell command that exits with its first argument.
  static let exitWithFirstArgument = #"exit "$1""#

  /// An exit status that the agent command gives in a test.
  static let exitStatus: Int32 = 7

  /// The name of the environment variable that a method gives.
  static let tokenName = "SIGN_IN_TOKEN"

  /// A value with a single quote and a space, which the script must quote.
  static let tokenValue = "it's a token"

  /// The exit status of a command that succeeded.
  static let successStatus: Int32 = 0

  /// A shell command that sends a terminate signal to the script shell, as a
  /// user who closes the terminal window or presses Control-C.
  static let terminateTheScript = #"kill -TERM "$PPID""#

  /// An environment variable name that the shell cannot read.
  static let invalidName = "SIGN-IN"

  /// A program path that does not exist, so that no process starts.
  static let missingProgram = "/nonexistent/sign-in-program"

  /// Records each script that an opener got, and opens no script.
  nonisolated final class RecordingOpener: Sendable {
    /// The scripts, in open order.
    private let storage = Mutex<[URL]>([])

    /// The scripts that the opener got, in open order.
    var opened: [URL] { storage.withLock { $0 } }

    /// Records `script` and tells that the open failed.
    ///
    /// - Parameter script: The script to open.
    /// - Returns: `false`.
    func open(_ script: URL) async -> Bool {
      storage.withLock { $0.append(script) }
      return false
    }
  }

  /// Runs a script with `/bin/sh`, and waits until it ends.
  ///
  /// The exit status of the script is not the result: the runner reads the
  /// status file that the script writes.
  ///
  /// - Parameter script: The script file.
  /// - Returns: `true` when the shell started.
  nonisolated static func runInShell(_ script: URL) async -> Bool {
    await TerminalAppAuthRunner.run(program: shell, arguments: [script.path(percentEncoded: false)]) != nil
  }

  /// Makes a runner whose agent command is `/bin/sh -c <command> sign-in`.
  ///
  /// - Parameters:
  ///   - command: The shell command that acts as the agent program.
  ///   - openScript: The opener of the script.
  /// - Returns: The runner.
  static func makeRunner(
    command: String,
    openScript: @escaping TerminalAppAuthRunner.ScriptOpener = runInShell
  ) -> TerminalAppAuthRunner {
    TerminalAppAuthRunner(
      command: shell, arguments: [commandOption, command, commandName], openScript: openScript)
  }

  /// Runs `runner` with the time limit of the ACP tests. When the time runs
  /// out, the run is cancelled, so the test fails and does not hang.
  ///
  /// - Parameters:
  ///   - runner: The runner.
  ///   - arguments: The arguments of the method.
  ///   - environment: The environment of the method.
  /// - Returns: The exit status that the runner gives.
  /// - Throws: The error of the runner.
  static func run(
    _ runner: TerminalAppAuthRunner, arguments: [String] = [], environment: [String: String] = [:]
  ) async throws -> Int32? {
    let run = Task { try await runner.runTerminalAuth(arguments: arguments, environment: environment) }
    return try await ACPTestTimeLimit.run(stopping: { run.cancel() }) { try await run.value }
  }

  @Test func aRunGivesTheExitStatusOfTheCommandWithTheArgumentsOfTheMethod() async throws {
    let runner = Self.makeRunner(command: Self.exitWithFirstArgument)

    let status = try await Self.run(runner, arguments: [String(Self.exitStatus)])

    #expect(status == Self.exitStatus)
  }

  @Test func aRunAppliesTheEnvironmentOfTheMethod() async throws {
    let runner = Self.makeRunner(command: #"test "$\#(Self.tokenName)" = "\#(Self.tokenValue)""#)

    let status = try await Self.run(runner, environment: [Self.tokenName: Self.tokenValue])

    #expect(status == Self.successStatus)
  }

  @Test func aRunThatTheUserStopsGivesNoExitStatus() async throws {
    let runner = Self.makeRunner(command: Self.terminateTheScript)

    let status = try await Self.run(runner)

    #expect(status == nil)
  }

  @Test func aScriptThatTheTerminalCannotOpenGivesNoExitStatus() async throws {
    let opener = RecordingOpener()
    let runner = Self.makeRunner(command: Self.exitWithFirstArgument, openScript: opener.open)

    let status = try await Self.run(runner)

    #expect(status == nil)
    #expect(opener.opened.count == 1)
  }

  @Test func runGivesTheExitStatusOfTheProgram() async {
    let status = await TerminalAppAuthRunner.run(
      program: Self.shell,
      arguments: [Self.commandOption, Self.exitWithFirstArgument, Self.commandName, String(Self.exitStatus)])

    #expect(status == Self.exitStatus)
  }

  @Test func runOfAProgramThatDoesNotStartGivesNoExitStatus() async {
    let status = await TerminalAppAuthRunner.run(program: Self.missingProgram, arguments: [])

    #expect(status == nil)
  }

  @Test func anEnvironmentNameThatTheShellCannotReadOpensNoScript() async throws {
    let opener = RecordingOpener()
    let runner = Self.makeRunner(command: Self.exitWithFirstArgument, openScript: opener.open)

    let status = try await Self.run(runner, environment: [Self.invalidName: Self.tokenValue])

    #expect(status == nil)
    #expect(opener.opened.isEmpty)
  }
}
