/// The places of the pixels of an image whose rows run from the top.
///
/// ``PreviewFixtures`` makes the pixels of its images in this order, and the
/// test support target reads the pixels of a render in it. The type has
/// `package` access, so that the test support target reaches it and a host of
/// the kit does not.
package nonisolated enum PixelGrid {
  /// The place of one pixel, from the top leading corner.
  package struct Position {
    /// The row, from zero at the top.
    package let row: Int

    /// The column, from zero at the leading edge.
    package let column: Int
  }

  /// Each place of an image, row by row from the top, and in each row from
  /// the leading column.
  ///
  /// The sequence is lazy, so that a large image makes no array of places.
  ///
  /// - Parameters:
  ///   - width: The number of pixels in a row.
  ///   - height: The number of rows.
  /// - Returns: The places. An image with no row or no column has none.
  package static func positions(width: Int, height: Int) -> some Sequence<Position> {
    (0..<height).lazy.flatMap { row in
      (0..<width).lazy.map { column in Position(row: row, column: column) }
    }
  }
}
