import DemoSupport
import Foundation
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The time that ``AgentProcessLauncherTests`` waits for a process.
private let operationLimit = ScriptedWireAgent.operationLimit

@MainActor
@Suite struct AgentProcessLauncherTests {
  /// The shell that each test starts.
  static let shell = "/bin/sh"

  /// The option of ``shell`` that runs the next argument as a command.
  static let commandOption = "-c"

  /// The name of the launch variable that the tests give.
  static let variableName = "AVK_VALUE"

  /// The value of ``variableName``.
  static let variableValue = "hello"

  /// The host variable that the child must keep when the launch adds a
  /// variable.
  static let hostVariableName = "PATH"

  /// The exit code of the shell in the exit status tests.
  static let exitCode: Int32 = 3

  /// Reads the output of `process` until it ends, with a time limit.
  ///
  /// When the time runs out, the function records an issue and stops the
  /// process. The stop ends the output.
  private func collectOutput(of process: any LaunchedProcess) async -> Data {
    let watchdog = Task {
      try? await Task.sleep(for: operationLimit)
      guard !Task.isCancelled else { return }
      Issue.record("The process did not end in time.")
      process.terminate()
    }
    defer { watchdog.cancel() }
    var output = Data()
    for await chunk in process.output {
      output.append(chunk)
    }
    return output
  }

  /// Runs `script` in ``shell`` with `launcher`, and gives its output text.
  ///
  /// - Parameters:
  ///   - script: The shell command to run.
  ///   - environment: The launch variables.
  ///   - launcher: The launcher that starts the shell.
  /// - Returns: The standard output of the shell.
  private func outputText(
    of script: String, environment: [String: String] = [:], launcher: AgentProcessLauncher = AgentProcessLauncher()
  ) async throws -> String {
    let process = try launcher.launch(
      program: Self.shell, arguments: [Self.commandOption, script], environment: environment)
    defer { process.terminate() }
    return String(decoding: await collectOutput(of: process), as: UTF8.self)
  }

  /// The directory URL of a path, with the symbolic links resolved, so that
  /// two spellings of one directory compare equal.
  ///
  /// - Parameter path: The path of the directory, with or without a trailing
  ///   slash or a trailing new line.
  /// - Returns: The resolved directory URL.
  private func directoryURL(_ path: String) -> URL {
    URL(filePath: path.trimmingCharacters(in: .newlines), directoryHint: .isDirectory).resolvingSymlinksInPath()
  }

  @Test func launchStartsTheProgramItselfWithTheLaunchVariables() throws {
    let arguments = [Self.commandOption, "exit 0"]
    let process = try AgentProcessLauncher().launch(
      program: Self.shell, arguments: arguments, environment: [Self.variableName: Self.variableValue])
    defer { process.terminate() }
    let launched = try #require(process as? AgentLaunchedProcess)

    #expect(launched.process.command == Self.shell)
    #expect(launched.process.arguments == arguments)
  }

  @Test func launchGivesTheChildTheLaunchVariablesAndTheHostEnvironment() async throws {
    let hostValue = try #require(ProcessInfo.processInfo.environment[Self.hostVariableName])

    let text = try await outputText(
      of: "printf '%s\\n%s' \"$\(Self.variableName)\" \"$\(Self.hostVariableName)\"",
      environment: [Self.variableName: Self.variableValue])

    #expect(text == "\(Self.variableValue)\n\(hostValue)")
  }

  @Test func launchWithNoVariablesGivesTheChildTheHostEnvironment() throws {
    let process = try AgentProcessLauncher().launch(
      program: Self.shell, arguments: [Self.commandOption, "exit 0"], environment: [:])
    defer { process.terminate() }
    let launched = try #require(process as? AgentLaunchedProcess)

    #expect(launched.process.environment == nil)
  }

  @Test func launchStartsTheChildInTheCurrentDirectoryOfTheLauncher() async throws {
    let directory = FileManager.default.temporaryDirectory.path(percentEncoded: false)

    let text = try await outputText(of: "pwd -P", launcher: AgentProcessLauncher(currentDirectory: directory))

    #expect(directoryURL(text) == directoryURL(directory))
  }

  @Test func launchWithNoCurrentDirectoryStartsTheChildInTheHostDirectory() async throws {
    let hostDirectory = FileManager.default.currentDirectoryPath

    let text = try await outputText(of: "pwd -P")

    #expect(directoryURL(text) == directoryURL(hostDirectory))
  }

  @Test func exitStatusIsTheClientStatusAfterTheOutputEnds() async throws {
    let process = try AgentProcessLauncher().launch(
      program: Self.shell, arguments: [Self.commandOption, "exit \(Self.exitCode)"], environment: [:])
    defer { process.terminate() }

    _ = await collectOutput(of: process)

    #expect(process.exitStatus == .exited(code: Self.exitCode))
  }

  @Test func exitStatusIsNilWhileTheProcessRuns() throws {
    let process = try AgentProcessLauncher().launch(program: "/bin/cat", arguments: [], environment: [:])
    defer { process.terminate() }

    #expect(process.exitStatus == nil)
  }

  @Test func exitStatusAfterTerminateIsTheSignalOfTheClientShutdown() throws {
    let process = try AgentProcessLauncher().launch(program: "/bin/cat", arguments: [], environment: [:])

    process.terminate()

    #expect(process.exitStatus == .signaled(signal: SIGKILL))
  }

  @Test func launchRefusesAnInvalidName() {
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("A=B")) {
      try AgentProcessLauncher().launch(program: Self.shell, arguments: [], environment: ["A=B": "1"])
    }
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("")) {
      try AgentProcessLauncher().launch(program: Self.shell, arguments: [], environment: ["": "1"])
    }
  }

  @Test func launchWritesToTheStandardInput() async throws {
    let process = try AgentProcessLauncher().launch(
      program: "/usr/bin/head", arguments: ["-n", "1"], environment: [:])
    try process.write(Data("line\n".utf8))
    let output = await collectOutput(of: process)
    #expect(String(decoding: output, as: UTF8.self) == "line\n")
    process.terminate()
    #expect(throws: AgentProcessError.agentUnavailable) {
      try process.write(Data("more\n".utf8))
    }
  }

  @Test func launchOfARelativePathThrows() {
    #expect(throws: AgentProcessError.commandNotAbsolute("agent")) {
      try AgentProcessLauncher().launch(program: "agent", arguments: [], environment: [:])
    }
  }
}
