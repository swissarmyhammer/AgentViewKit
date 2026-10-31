import CoreGraphics
import Testing

@testable import AgentViewKitStyle

/// Checks the measuring and the rows of ``ChipFlowLayout``, with no view.
@Suite struct ChipFlowLayoutTests {
  /// The width of a row of the tests.
  static let rowWidth: CGFloat = 100

  /// The space between two chips of the tests.
  static let spacing: CGFloat = 4

  /// The height of one line of a chip.
  static let lineHeight: CGFloat = 20

  /// The height of a chip that wraps to the width of a row.
  static let wrappedHeight: CGFloat = 40

  /// Places chips of `sizes` in rows.
  ///
  /// - Parameter sizes: The sizes of the chips.
  /// - Returns: The frames of the chips.
  static func frames(_ sizes: [CGSize]) -> [CGRect] {
    ChipFlowLayout.frames(of: sizes, width: rowWidth, spacing: spacing)
  }

  @Test func aChipThatFitsKeepsItsIdealSize() {
    let ideal = CGSize(width: Self.rowWidth, height: Self.lineHeight)

    let size = ChipFlowLayout.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { _ in .zero }

    #expect(size == ideal)
  }

  @Test func aChipWiderThanTheRowIsMeasuredAgainAtTheRowWidth() {
    let ideal = CGSize(width: Self.rowWidth + 1, height: Self.lineHeight)

    let size = ChipFlowLayout.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { width in
      CGSize(width: width, height: Self.wrappedHeight)
    }

    #expect(size == CGSize(width: Self.rowWidth, height: Self.wrappedHeight))
  }

  @Test func aChipThatStaysTooWideTakesTheRowWidth() {
    let ideal = CGSize(width: 2 * Self.rowWidth, height: Self.lineHeight)

    let size = ChipFlowLayout.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { _ in ideal }

    #expect(size.width == Self.rowWidth)
  }

  @Test func noRowWidthMeasuresNoChipAgain() {
    let ideal = CGSize(width: 2 * Self.rowWidth, height: Self.lineHeight)

    let size = ChipFlowLayout.chipSize(ideal: ideal, rowWidth: .infinity) { _ in .zero }

    #expect(size == ideal)
  }

  @Test func chipsThatFitStayOnOneRow() {
    let chip = CGSize(width: 40, height: Self.lineHeight)

    #expect(Self.frames([chip, chip]).map(\.minY) == [0, 0])
  }

  @Test func aChipThatDoesNotFitStartsANewRow() {
    let chip = CGSize(width: 60, height: Self.lineHeight)

    let frames = Self.frames([chip, chip])

    #expect(frames[1].origin == CGPoint(x: 0, y: Self.lineHeight + Self.spacing))
  }

  @Test func aFullWidthChipHasARowOfItsOwn() {
    let small = CGSize(width: 40, height: Self.lineHeight)
    let wide = CGSize(width: Self.rowWidth, height: Self.wrappedHeight)

    let frames = Self.frames([small, wide, small])

    #expect(frames.map(\.minY) == [0, Self.lineHeight + Self.spacing, 2 * Self.spacing + Self.lineHeight + Self.wrappedHeight])
  }
}
