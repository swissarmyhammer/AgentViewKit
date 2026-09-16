import AgentViewKitACP
import Testing

/// Proves that the test target links the `AgentViewKitACP` module.
@Suite struct AgentViewKitACPModuleTests {
  @Test func markerBelongsToTheACPAdapterModule() {
    #expect(String(reflecting: AgentViewKitACPModule.self) == "AgentViewKitACP.AgentViewKitACPModule")
  }
}
