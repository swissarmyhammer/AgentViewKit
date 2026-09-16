import AgentViewKitFoundationModels
import Testing

/// Proves that the test target links the `AgentViewKitFoundationModels` module.
@Suite struct AgentViewKitFoundationModelsModuleTests {
  @Test func markerBelongsToTheFoundationModelsAdapterModule() {
    #expect(
      String(reflecting: AgentViewKitFoundationModelsModule.self)
        == "AgentViewKitFoundationModels.AgentViewKitFoundationModelsModule"
    )
  }
}
