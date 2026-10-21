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

  /// A view with ``drawn`` in its leading half and ``notDrawn`` in its
  /// trailing half.
  static var halves: some View {
    HStack(spacing: 0) {
      drawn
      notDrawn
    }
  }

  /// The center of the leading half of ``halves`` at ``size``, in points.
  static let leadingPoint = CGPoint(x: 10, y: 10)

  /// The center of the trailing half of ``halves`` at ``size``, in points.
  static let trailingPoint = CGPoint(x: 30, y: 10)

  /// The leading half of ``halves`` at ``size``, in points.
  static let leadingHalf = CGRect(x: 0, y: 0, width: size.width / 2, height: size.height)

  /// The size of one pixel of a render, in points: a render has two pixels
  /// for each point.
  static let onePixel = CGSize(width: 0.5, height: 0.5)

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

  @Test func aClearViewAfterADrawnViewHasNoColorOfTheDrawnView() throws {
    // `ImageRenderer` gives the pixels of an earlier render when the content
    // draws nothing. Thus the drawn view comes first, at the same size.
    _ = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let clear = try #require(RenderedPixels(rendering: Color.clear, size: Self.size))
    #expect(!clear.contains(Self.drawn))
  }

  @Test func rendersOfTwoColorsHaveDifferentPixels() throws {
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let notDrawn = try #require(RenderedPixels(rendering: Self.notDrawn, size: Self.size))
    #expect(drawn != notDrawn)
  }

  @Test func twoRendersOfOneViewAreClose() throws {
    let first = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let second = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(first.isClose(to: second))
  }

  @Test func rendersOfTwoColorsAreNotClose() throws {
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let notDrawn = try #require(RenderedPixels(rendering: Self.notDrawn, size: Self.size))
    #expect(!drawn.isClose(to: notDrawn))
  }

  @Test func rendersOfTwoSizesAreNotClose() throws {
    let small = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let large = try #require(
      RenderedPixels(
        rendering: Self.drawn, size: CGSize(width: Self.size.width * 2, height: Self.size.height)))
    #expect(!small.isClose(to: large))
  }

  @Test func aPointHasTheColorThatTheViewDrawsThere() throws {
    let pixels = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    #expect(pixels.contains(Self.drawn, at: Self.leadingPoint))
    #expect(pixels.contains(Self.notDrawn, at: Self.trailingPoint))
  }

  @Test func aPointDoesNotHaveAColorThatTheViewDrawsAtADifferentPoint() throws {
    let pixels = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    #expect(!pixels.contains(Self.notDrawn, at: Self.leadingPoint))
    #expect(!pixels.contains(Self.drawn, at: Self.trailingPoint))
  }

  @Test func aPointOutsideTheRenderHasNoColor() throws {
    let pixels = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let outside = CGPoint(x: Self.size.width, y: Self.size.height)
    #expect(!pixels.contains(Self.drawn, at: outside))
  }

  @Test func twoRendersAreCloseAtAPointWhereTheyHaveTheSameColor() throws {
    let halves = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(halves.isClose(to: drawn, at: [Self.leadingPoint]))
  }

  @Test func twoRendersAreNotCloseAtAPointWhereTheyHaveDifferentColors() throws {
    let halves = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(!halves.isClose(to: drawn, at: [Self.leadingPoint, Self.trailingPoint]))
  }

  @Test func twoRendersAreNotCloseAtAPointOutsideTheRender() throws {
    let first = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let second = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let outside = CGPoint(x: Self.size.width, y: Self.size.height)
    #expect(!first.isClose(to: second, at: [outside]))
  }

  @Test func twoRendersAreCloseInARegionWhereTheyHaveTheSameColor() throws {
    let halves = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    #expect(halves.isClose(to: drawn, within: Path(Self.leadingHalf)))
  }

  @Test func twoRendersAreNotCloseInARegionWhereOnePixelHasADifferentColor() throws {
    let halves = try #require(RenderedPixels(rendering: Self.halves, size: Self.size))
    let drawn = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let trailingPixel = CGRect(origin: Self.trailingPoint, size: Self.onePixel)
    let region = Path(Self.leadingHalf).union(Path(trailingPixel))
    #expect(!halves.isClose(to: drawn, within: region))
  }

  @Test func twoRendersAreNotCloseInARegionWithNoPixel() throws {
    let first = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let second = try #require(RenderedPixels(rendering: Self.drawn, size: Self.size))
    let outside = CGRect(origin: CGPoint(x: Self.size.width, y: Self.size.height), size: Self.size)
    #expect(!first.isClose(to: second, within: Path(outside)))
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
