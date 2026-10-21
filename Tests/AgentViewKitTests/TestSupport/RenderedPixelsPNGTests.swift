import AgentViewKitTestSupport
import ImageIO
import SwiftUI
import Testing

/// Tests for the PNG form of ``RenderedPixels`` and for the difference of two
/// renders, which the snapshot images use (AVK-13).
@Suite @MainActor struct RenderedPixelsPNGTests {
  /// The pixels of ``RenderedPixelsTests/halves``.
  ///
  /// - Returns: The pixels.
  /// - Throws: An issue when the renderer gives no pixels.
  static func halves() throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: RenderedPixelsTests.halves, size: RenderedPixelsTests.size))
  }

  /// The pixels of one color that fills the view.
  ///
  /// - Returns: The pixels.
  /// - Throws: An issue when the renderer gives no pixels.
  static func filled() throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: RenderedPixelsTests.drawn, size: RenderedPixelsTests.size))
  }

  /// The width and the height of the image in `data`, in pixels.
  ///
  /// - Parameter data: The bytes of an image file.
  /// - Returns: The size in pixels.
  /// - Throws: An issue when ImageIO cannot read the image.
  static func pixelSize(of data: Data) throws -> CGSize {
    let source = try #require(CGImageSourceCreateWithData(data as CFData, nil))
    let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
    return CGSize(width: image.width, height: image.height)
  }

  @Test func thePixelsReadBackFromTheirPNG() throws {
    let original = try Self.halves()
    let png = try #require(original.pngData())

    let read = try #require(RenderedPixels(pngData: png, scale: RenderedPixels.renderScale))

    #expect(read.isClose(to: original))
  }

  @Test func thePNGHasTwoPixelsForEachPoint() throws {
    let png = try #require(Self.halves().pngData())

    let size = try Self.pixelSize(of: png)

    #expect(size.width == RenderedPixelsTests.size.width * RenderedPixels.renderScale)
    #expect(size.height == RenderedPixelsTests.size.height * RenderedPixels.renderScale)
  }

  @Test func theDifferenceMarksAPixelThatChanged() throws {
    let difference = try #require(Self.halves().difference(from: Self.filled()))

    #expect(difference.marksAChange(at: RenderedPixelsTests.trailingPoint))
  }

  @Test func theDifferenceDoesNotMarkAPixelThatIsTheSame() throws {
    let difference = try #require(Self.halves().difference(from: Self.filled()))

    #expect(!difference.marksAChange(at: RenderedPixelsTests.leadingPoint))
  }

  @Test func theChangedPixelCountIsTheNumberOfPixelsThatChanged() throws {
    let pixelCount = Int(RenderedPixelsTests.size.width * RenderedPixelsTests.size.height * RenderedPixels.renderScale * RenderedPixels.renderScale)

    #expect(try Self.halves().changedPixelCount(comparedWith: Self.filled()) == pixelCount / 2)
  }

  @Test func twoRendersOfOneViewHaveNoChangedPixel() throws {
    #expect(try Self.halves().changedPixelCount(comparedWith: Self.halves()) == 0)
  }

  @Test func twoRendersOfTwoSizesHaveNoChangedPixelCount() throws {
    let other = try #require(
      RenderedPixels(rendering: RenderedPixelsTests.drawn, size: RenderedPixelsTests.leadingHalf.size))

    #expect(try Self.halves().changedPixelCount(comparedWith: other) == nil)
  }

  @Test func twoRendersOfTwoSizesHaveNoDifferenceImage() throws {
    let other = try #require(
      RenderedPixels(rendering: RenderedPixelsTests.drawn, size: RenderedPixelsTests.leadingHalf.size))

    #expect(try Self.halves().difference(from: other) == nil)
  }
}

/// Tests for the cache of a view in a window at a fixed scale (AVK-13).
@Suite(.serialized, .hostedSerially) @MainActor struct RenderedPixelsCacheScaleTests {
  /// A scale that no screen of this computer has, so that the test fails
  /// when the cache uses the scale of the window.
  static let otherScale: CGFloat = 3

  @Test func theCacheHasTheGivenScale() throws {
    let harness = HostedViewHarness(RenderedPixelsTests.halves, size: RenderedPixelsTests.size)
    defer { harness.close() }
    harness.render()

    let pixels = try #require(RenderedPixels(cachingDisplayOf: harness.hostingView, scale: Self.otherScale))
    let size = try RenderedPixelsPNGTests.pixelSize(of: #require(pixels.pngData()))

    #expect(size.width == RenderedPixelsTests.size.width * Self.otherScale)
  }

  @Test func theCacheAtAFixedScaleShowsTheView() throws {
    let harness = HostedViewHarness(RenderedPixelsTests.halves, size: RenderedPixelsTests.size)
    defer { harness.close() }
    harness.render()

    let pixels = try #require(
      RenderedPixels(cachingDisplayOf: harness.hostingView, scale: RenderedPixels.renderScale))

    #expect(pixels.contains(RenderedPixelsTests.drawn, at: RenderedPixelsTests.leadingPoint))
    #expect(pixels.contains(RenderedPixelsTests.notDrawn, at: RenderedPixelsTests.trailingPoint))
  }
}
