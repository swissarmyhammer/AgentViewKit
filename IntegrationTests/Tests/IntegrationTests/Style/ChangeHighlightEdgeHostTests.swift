import AgentViewKitStyle
import SwiftUI
import Testing

/// Checks the change-highlight edge through its public API.
@Suite @MainActor struct ChangeHighlightEdgeHostTests {
  /// The view of the tests.
  static let label = Text(verbatim: "A card")

  @Test(arguments: [true, false])
  func theEdgeAddsNoSpace(isShowing: Bool) {
    let edged = StyleViewHost.fittingSize(of: Self.label.changeHighlightEdge(radius: .large, isShowing: isShowing))

    #expect(edged == StyleViewHost.fittingSize(of: Self.label))
  }

  @Test(arguments: [SurfaceCorners.card, .square])
  func theEdgeOfCornersAddsNoSpace(corners: SurfaceCorners) {
    let edged = StyleViewHost.fittingSize(of: Self.label.changeHighlightEdge(corners: corners, isShowing: true))

    #expect(edged == StyleViewHost.fittingSize(of: Self.label))
  }
}
