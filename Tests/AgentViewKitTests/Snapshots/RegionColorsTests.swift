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

    #expect(RegionColors.contains(RenderedPixelsTests.notDrawn, in: Self.trailingHalf, of: pixels))
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

  @Test func theRowAtAPointIsThePixelRowThatHoldsThePoint() throws {
    let pixels = try Self.halves()
    let onePixel = RenderedPixelsTests.onePixel
    let inSecondPixelRow = onePixel.height + onePixel.height / 2

    let row = RegionColors.row(of: pixels, at: inSecondPixelRow)

    #expect(row == CGRect(x: 0, y: onePixel.height, width: RenderedPixelsTests.size.width, height: onePixel.height))
  }

  @Test func theRowAtTheEdgeBetweenTwoPixelRowsIsTheRowBelowTheEdge() throws {
    let pixels = try Self.halves()
    let onePixel = RenderedPixelsTests.onePixel

    let columnCount = Int(RenderedPixelsTests.size.width / onePixel.width)
    let expectedColumns = (0..<columnCount).map { column in
      CGRect(x: CGFloat(column) * onePixel.width, y: onePixel.height, width: onePixel.width, height: onePixel.height)
    }

    let row = RegionColors.row(of: pixels, at: onePixel.height)

    #expect(row.minY == onePixel.height)
    #expect(RegionColors.columns(of: pixels, in: row) == expectedColumns)
  }
}
