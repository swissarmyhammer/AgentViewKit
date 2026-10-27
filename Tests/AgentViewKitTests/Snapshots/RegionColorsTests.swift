@testable import AgentViewKitTestSupport
import SwiftUI
import Testing

/// Tests for the pixel enumeration of ``RegionColors``, over a render of
/// ``RenderedPixelsTests/halves``: ``RenderedPixelsTests/drawn`` in the
/// leading half and ``RenderedPixelsTests/notDrawn`` in the trailing half.
@Suite @MainActor struct RegionColorsTests {
  /// The trailing half of ``RenderedPixelsTests/halves`` at
  /// ``RenderedPixelsTests/size``, in points.
  static let trailingHalf = RenderedPixelsTests.leadingHalf.offsetBy(dx: RenderedPixelsTests.leadingHalf.width, dy: 0)

  /// The render of ``RenderedPixelsTests/halves``.
  ///
  /// - Returns: The pixels.
  /// - Throws: An issue when the renderer gives no pixels.
  static func halves() throws -> RenderedPixels {
    try #require(RenderedPixels(rendering: RenderedPixelsTests.halves, size: RenderedPixelsTests.size))
  }

  @Test func aRegionContainsTheColorThatItsPixelsHave() throws {
    let pixels = try Self.halves()

    #expect(RegionColors.contains(RenderedPixelsTests.drawn, in: RenderedPixelsTests.leadingHalf, of: pixels))
  }

  @Test func aRegionDoesNotContainTheColorOfThePixelsOutsideIt() throws {
    let pixels = try Self.halves()

    #expect(!RegionColors.contains(RenderedPixelsTests.drawn, in: Self.trailingHalf, of: pixels))
  }

  @Test func theColumnsOfARegionAreOnePixelWideAndCoverTheRegion() throws {
    let pixels = try Self.halves()
    let region = RenderedPixelsTests.leadingHalf

    let columns = RegionColors.columns(of: pixels, in: region)

    #expect(columns.count == Int(region.width * pixels.scale))
    #expect(columns.allSatisfy { $0.width == RenderedPixelsTests.onePixel.width && $0.height == region.height })
    #expect(columns.reduce(CGRect.null) { $0.union($1) } == region)
  }

  @Test func theColumnsOfARegionOutsideTheImageAreNone() throws {
    let pixels = try Self.halves()
    let outside = RenderedPixelsTests.leadingHalf.offsetBy(dx: 0, dy: RenderedPixelsTests.size.height)

    #expect(RegionColors.columns(of: pixels, in: outside).isEmpty)
  }
}
