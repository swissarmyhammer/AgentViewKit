import CoreGraphics
import Testing

@testable import EditorStyle

/// Checks the measuring and the rows of EditorKit's ``EditorChipRows``, with
/// no view, that EditorKit's own `EditorChipRowsTests` does not make.
///
/// The location chips of a tool call and the file chips of a diff stand in
/// these rows. EditorKit checks that chips that fit stay on one row, that a
/// chip that does not fit starts the next row, the trailing edge, and the
/// width of a chip wider than the row. These checks add the ideal size of a
/// chip that fits, the height of a chip measured again, the width of a chip
/// that stays too wide, a row of no width, and the row of a full-width chip.
@Suite struct EditorChipRowsTests {
  /// The width of a row of the tests.
  static let rowWidth: CGFloat = 100

  /// The space between two chips of the tests.
  static let spacing: CGFloat = 4

  /// The height of one line of a chip.
  static let lineHeight: CGFloat = 20

  /// The height of a chip that wraps to the width of a row.
  static let wrappedHeight: CGFloat = 40

  /// The width of a chip that fits twice in a row.
  static let smallWidth: CGFloat = 40

  /// Places chips of `sizes` in rows that start at the leading edge.
  ///
  /// - Parameter sizes: The sizes of the chips.
  /// - Returns: The frames of the chips.
  static func frames(_ sizes: [CGSize]) -> [CGRect] {
    EditorChipRows.frames(of: sizes, width: rowWidth, spacing: spacing, edge: .leading)
  }

  @Test func aChipThatFitsKeepsItsIdealSize() {
    let ideal = CGSize(width: Self.rowWidth, height: Self.lineHeight)

    let size = EditorChipRows.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { _ in .zero }

    #expect(size == ideal)
  }

  @Test func aChipWiderThanTheRowIsMeasuredAgainAtTheRowWidth() {
    let ideal = CGSize(width: Self.rowWidth + 1, height: Self.lineHeight)

    let size = EditorChipRows.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { width in
      CGSize(width: width, height: Self.wrappedHeight)
    }

    #expect(size == CGSize(width: Self.rowWidth, height: Self.wrappedHeight))
  }

  @Test func aChipThatStaysTooWideTakesTheRowWidth() {
    let ideal = CGSize(width: 2 * Self.rowWidth, height: Self.lineHeight)

    let size = EditorChipRows.chipSize(ideal: ideal, rowWidth: Self.rowWidth) { _ in ideal }

    #expect(size.width == Self.rowWidth)
  }

  @Test func noRowWidthMeasuresNoChipAgain() {
    let ideal = CGSize(width: 2 * Self.rowWidth, height: Self.lineHeight)

    let size = EditorChipRows.chipSize(ideal: ideal, rowWidth: .infinity) { _ in .zero }

    #expect(size == ideal)
  }

  @Test func aFullWidthChipHasARowOfItsOwn() {
    let small = CGSize(width: Self.smallWidth, height: Self.lineHeight)
    let wide = CGSize(width: Self.rowWidth, height: Self.wrappedHeight)

    let frames = Self.frames([small, wide, small])

    #expect(
      frames.map(\.minY)
        == [0, Self.lineHeight + Self.spacing, 2 * Self.spacing + Self.lineHeight + Self.wrappedHeight])
  }
}
