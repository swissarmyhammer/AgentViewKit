import AgentViewKit
import Testing

/// Proves that the test target links the `AgentViewKit` module.
@Suite struct AgentViewKitModuleTests {
  @Test func markerBelongsToTheAgentViewKitModule() {
    #expect(String(reflecting: AgentViewKitModule.self) == "AgentViewKit.AgentViewKitModule")
  }
}
