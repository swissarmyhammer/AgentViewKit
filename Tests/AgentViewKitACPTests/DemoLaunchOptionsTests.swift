import Testing

@testable import DemoSupport

/// The tests of the arguments that the demo app gives to the agent program.
struct DemoLaunchOptionsTests {
  @Test func acpAgentByNameStartsWithTheACPSubcommand() {
    #expect(DemoLaunchOptions.agentArguments(for: "acp-agent") == ["acp"])
  }

  @Test func acpAgentByPathStartsWithTheACPSubcommand() {
    #expect(DemoLaunchOptions.agentArguments(for: "/usr/local/bin/acp-agent") == ["acp"])
  }

  @Test func otherAgentStartsWithNoArguments() {
    #expect(DemoLaunchOptions.agentArguments(for: "other-agent").isEmpty)
  }
}
