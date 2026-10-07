import Foundation
import Testing

@testable import DemoSupport

/// The tests of the launch arguments of the demo app, and of the arguments
/// that the demo app gives to the agent program.
struct DemoLaunchOptionsTests {
  /// The working directory that the tests give with `--cwd`.
  static let workingDirectory = "/tmp/demo"

  @Test func acpAgentByNameStartsWithTheACPSubcommand() {
    #expect(DemoLaunchOptions.agentArguments(for: "acp-agent") == ["acp"])
  }

  @Test func acpAgentByPathStartsWithTheACPSubcommand() {
    #expect(DemoLaunchOptions.agentArguments(for: "/usr/local/bin/acp-agent") == ["acp"])
  }

  @Test func otherAgentStartsWithNoArguments() {
    #expect(DemoLaunchOptions.agentArguments(for: "other-agent").isEmpty)
  }

  @Test func launchOptionsReadTheKnownArgumentsAndIgnoreTheOthers() {
    let options = DemoLaunchOptions(arguments: [
      "app", "-NSDocumentRevisionsDebugMode", "YES", InMemoryDemoAgent.launchArgument,
      DemoLaunchOptions.agentCommandArgument, "/bin/agent", DemoLaunchOptions.cwdArgument, Self.workingDirectory,
    ])

    #expect(options.usesInMemoryAgent)
    #expect(options.agentCommand == "/bin/agent")
    #expect(options.cwd == Self.workingDirectory)
  }

  @Test func launchOptionsWithNoArgumentsUseTheDefaults() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.cwdArgument])

    #expect(!options.usesInMemoryAgent)
    #expect(options.agentCommand == DemoLaunchOptions.defaultAgentCommand)
    #expect(options.agentCommand.hasSuffix(DemoLaunchOptions.siblingAgentPath))
    #expect(options.agentCommand.hasPrefix("/"))
    #expect(options.cwd == FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false))
  }
}
