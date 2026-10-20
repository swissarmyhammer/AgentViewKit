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

  @Test func twoRendersOfOneViewHaveEqualPixels() throws {
    let first = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let second = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(first == second)
  }

  @Test func rendersOfTwoColorsHaveDifferentPixels() throws {
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let notDrawn = try #require(RenderedPixels(rendering: Self.notDrawn, size: Self.size))
    #expect(drawn != notDrawn)
  }

  @Test func aRenderDrawsTheLiquidGlassOfTheView() throws {
    let glass = ZStack {
      Self.drawn
      Color.clear.glassEffect(.regular, in: .rect)
    }
    let withGlass = try #require(RenderedPixels(rendering: glass, size: Self.size))
    let withoutGlass = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(withGlass != withoutGlass)
  }
}

/// Checks the pixels that AppKit caches for a view in a window.
@Suite(.serialized, .hostedSerially) @MainActor struct RenderedPixelsHostedTests {
  @Test func theCachedPixelsContainTheColorThatTheHostedViewDraws() throws {
    let harness = HostedViewHarness(RenderedPixelsTests.drawn, size: RenderedPixelsTests.size)
    defer { harness.close() }
    let pixels = try #require(RenderedPixels(cachingDisplayOf: harness.hostingView))
    #expect(pixels.contains(RenderedPixelsTests.drawn))
    #expect(!pixels.contains(RenderedPixelsTests.notDrawn))
  }
}
