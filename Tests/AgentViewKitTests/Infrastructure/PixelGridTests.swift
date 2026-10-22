import Testing

@testable import AgentViewKit

/// The order of the positions of ``PixelGrid``, which the preview images and
/// the rendered pixels of the test support both read.
@Suite struct PixelGridTests {
  @Test func thePositionsRunRowByRowFromTheTopAndFromTheLeadingColumn() {
    let positions = PixelGrid.positions(width: 3, height: 2).map { [$0.row, $0.column] }

    #expect(positions == [[0, 0], [0, 1], [0, 2], [1, 0], [1, 1], [1, 2]])
  }

  @Test func aGridWithNoColumnHasNoPosition() {
    #expect(Array(PixelGrid.positions(width: 0, height: 2)).isEmpty)
  }

  @Test func aGridWithNoRowHasNoPosition() {
    #expect(Array(PixelGrid.positions(width: 3, height: 0)).isEmpty)
  }
}
