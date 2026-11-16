@testable import AgentViewKit
import FoundationModelsACPAgent
import Testing

/// The settings store of FoundationModelsACPAgent checks the `statusline`
/// setting with a copy of the keys of the kit, because the agent package
/// cannot import the kit. A change on one side fails this test.
@Suite struct StatusLineSchemaParityTests {
  @Test func agentKeysAreTheKeysOfTheKit() {
    let agent = StatusLineConfiguration.settingsKeys
    let kit = StatusLineDefinition.settingsKeys
    #expect(Set(agent).subtracting(kit).isEmpty, "Only in the agent: \(Set(agent).subtracting(kit).sorted { $0.joined(separator: ".") < $1.joined(separator: ".") })")
    #expect(Set(kit).subtracting(agent).isEmpty, "Only in the kit: \(Set(kit).subtracting(agent).sorted { $0.joined(separator: ".") < $1.joined(separator: ".") })")
    #expect(agent == kit)
  }
}
