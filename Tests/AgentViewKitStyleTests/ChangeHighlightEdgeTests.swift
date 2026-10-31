import Testing

@testable import AgentViewKitStyle

/// Checks the motion of the change-highlight edge, with no view.
@Suite @MainActor struct ChangeHighlightEdgeTests {
  @Test func theEdgeHasNoAnimationUnderReduceMotion() {
    #expect(ChangeHighlightEdge.animation(reduceMotion: true) == nil)
  }

  @Test func theEdgeFadesWithoutReduceMotion() {
    #expect(ChangeHighlightEdge.animation(reduceMotion: false) != nil)
  }
}
