import DemoSupport
import Foundation
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The time that ``AgentProcessLauncherTests`` waits for a process.
private let operationLimit = ScriptedWireAgent.operationLimit

@MainActor
@Suite struct AgentProcessLauncherTests {
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

  @Test func commandWithNoEnvironmentIsTheProgram() throws {
    let command = try AgentProcessLauncher.command(program: "/bin/agent", arguments: ["--x"], environment: [:])
    #expect(command.program == "/bin/agent")
    #expect(command.arguments == ["--x"])
  }

  @Test func commandWithAnEnvironmentStartsEnvWithSortedPairs() throws {
    let command = try AgentProcessLauncher.command(
      program: "/bin/agent", arguments: ["--x"], environment: ["ZED": "2", "ALPHA": "1"])
    #expect(command.program == AgentProcessLauncher.environmentProgram)
    #expect(command.arguments == ["ALPHA=1", "ZED=2", "/bin/agent", "--x"])
  }

  @Test func commandRefusesAnInvalidName() {
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("A=B")) {
      try AgentProcessLauncher.command(program: "/bin/agent", arguments: [], environment: ["A=B": "1"])
    }
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("")) {
      try AgentProcessLauncher.command(program: "/bin/agent", arguments: [], environment: ["": "1"])
    }
  }

  @Test func commandRefusesAProgramPathWithAnEqualSign() {
    #expect(throws: AgentProcessLauncherError.programPathHasEqualSign("/bin/a=b")) {
      try AgentProcessLauncher.command(program: "/bin/a=b", arguments: [], environment: ["A": "1"])
    }
  }

  @Test func launchRunsTheProgramWithTheEnvironment() async throws {
    let process = try AgentProcessLauncher().launch(
      program: "/bin/sh", arguments: ["-c", "echo \"$AVK_VALUE\""], environment: ["AVK_VALUE": "hello"])
    let output = await collectOutput(of: process)
    #expect(String(decoding: output, as: UTF8.self) == "hello\n")
    #expect(process.exitStatus == nil)
    process.terminate()
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
