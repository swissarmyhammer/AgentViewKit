import AgentViewKitTestSupport
import SwiftUI
import Testing

@Suite @MainActor struct RenderedPixelsTests {
  /// The color of the view that the tests render.
  static let drawn = Color(red: 0.2, green: 0.4, blue: 0.6)

  /// A color that the view does not draw.
  static let notDrawn = Color(red: 0.9, green: 0.1, blue: 0.3)

  /// The size that the tests render at.
  static let size = CGSize(width: 40, height: 20)

  @Test func thePixelsContainTheColorThatTheViewDraws() throws {
    let pixels = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(pixels.contains(Self.drawn))
  }

  @Test func thePixelsDoNotContainAColorThatTheViewDoesNotDraw() throws {
    let pixels = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(!pixels.contains(Self.notDrawn))
  }
}
