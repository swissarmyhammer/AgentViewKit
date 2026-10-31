import EditorStyle
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

  @Test func theEdgeOfACardHasTheRadiusOfACard() {
    let edge = ChangeHighlightEdge(corners: .card, isShowing: true)

    #expect(edge.radius(in: .default) == SurfaceCorners.card.radius(in: .default))
  }

  @Test func theEdgeOfSquareCornersHasNoRadius() {
    let edge = ChangeHighlightEdge(corners: .square, isShowing: true)

    #expect(edge.radius(in: .default) == .zero)
  }
}
