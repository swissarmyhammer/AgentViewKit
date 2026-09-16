import AgentViewKitRouter
import Testing

/// Proves that the test target links the `AgentViewKitRouter` module.
@Suite struct AgentViewKitRouterModuleTests {
  @Test func markerBelongsToTheRouterAdapterModule() {
    #expect(String(reflecting: AgentViewKitRouterModule.self) == "AgentViewKitRouter.AgentViewKitRouterModule")
  }
}
