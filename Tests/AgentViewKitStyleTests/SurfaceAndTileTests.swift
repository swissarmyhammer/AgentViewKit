import AgentViewKitStyle
import EditorStyle
import SwiftUI
import Testing

/// Checks the content tile, the tile layout, the surface corners and the
/// selectable surface through their public API.
@Suite @MainActor struct SurfaceAndTileTests {
  /// The largest difference, in points, between two lengths that a test
  /// counts as the same length.
  static let layoutTolerance: CGFloat = 0.5

  /// The size of the sample block of the tests.
  static let blockSize = CGSize(width: 40, height: 20)

  /// The shared style of the tests.
  static let style = EditorStyle.default

  /// A block of a fixed size.
  static var block: some View {
    Color.clear.frame(width: blockSize.width, height: blockSize.height)
  }

  @Test func aContentTilePadsEachEdgeByTheTilePadding() {
    let size = StyleViewHost.fittingSize(of: Self.block.contentTile())

    #expect(abs(size.width - (Self.blockSize.width + 2 * Self.style.tile.padding)) <= Self.layoutTolerance)
    #expect(abs(size.height - (Self.blockSize.height + 2 * Self.style.tile.padding)) <= Self.layoutTolerance)
  }

  @Test func aTileStackPutsTheTileGapBetweenItsHeaderAndItsBody() {
    let stack = ContentTileStack { Self.block } body: { Self.block }

    let size = StyleViewHost.fittingSize(of: stack)

    #expect(abs(size.height - (2 * Self.blockSize.height + Self.style.tile.gap)) <= Self.layoutTolerance)
  }

  @Test func roundedCornersHaveTheRadiusOfTheirStep() {
    #expect(SurfaceCorners.rounded(.medium).radius(in: Self.style) == Self.style.radii[.medium])
  }

  @Test func squareCornersHaveNoRadius() {
    #expect(SurfaceCorners.square.radius(in: Self.style) == .zero)
  }

  @Test func theCardCornersHaveTheLargeRadius() {
    #expect(SurfaceCorners.card == .rounded(.large))
  }

  @Test func aSelectableSurfaceKeepsTheSizeOfItsItem() {
    for isSelected in [true, false] {
      let size = StyleViewHost.fittingSize(of: Self.block.selectableSurface(isSelected, radius: .small))

      #expect(abs(size.width - Self.blockSize.width) <= Self.layoutTolerance, "\(isSelected)")
    }
  }

  @Test func aFlowLayoutStartsANewRowWhenAViewDoesNotFit() {
    let spacing = Self.style.spacing.xs
    let flow = ChipFlowLayout(spacing: spacing) {
      Self.block
      Self.block
    }

    let wide = StyleViewHost.size(of: flow, width: 2 * Self.blockSize.width + spacing)
    let narrow = StyleViewHost.size(of: flow, width: Self.blockSize.width + spacing)

    #expect(abs(wide.height - Self.blockSize.height) <= Self.layoutTolerance)
    #expect(abs(narrow.height - (2 * Self.blockSize.height + spacing)) <= Self.layoutTolerance)
  }
}
