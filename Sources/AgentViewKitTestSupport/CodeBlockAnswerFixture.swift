import CoreGraphics

/// An agent answer with a paragraph above a fenced code block, and the
/// points of a right click in each part.
///
/// The unit tests and the hosted tests of Copy Code Block in the item menu of
/// an answer use this answer, and keep no copy of their own. A test finds a
/// point in a part as a fraction of the height of the text of the answer,
/// from the top: the paragraph is in the top part, and the code block is in
/// the bottom part.
public enum CodeBlockAnswerFixture {
  /// The number of code lines of the block.
  static let codeLineCount = 8

  /// The code of the block, with no fence lines.
  public static let code = (1...codeLineCount).map { "let value\($0) = \($0)" }
    .joined(separator: "\n")

  /// The Markdown of the answer: a paragraph, then a code block.
  ///
  /// The paragraph wraps to more lines than the top eighth of the text, and
  /// the code block holds more lines than the bottom eighth. A line break
  /// follows the closing fence: with no line break there, EditorKit gives
  /// the closing fence as a part of the code (task ^dbh2sda).
  public static let markdown = """
    The parser reads each line of the file. It keeps the name of each value, \
    and it skips each empty line. Then it gives the values to the caller, in \
    the order of the file, with no change. The code below shows the values.

    ```swift
    \(code)
    ```

    """

  /// The number of equal bands of the height of the text. The point in the
  /// paragraph is at the end of the top band, and the point in the code
  /// block is at the start of the bottom band.
  static let heightBandCount: CGFloat = 8

  /// The fraction of the height of the text, from the top, of a point in
  /// the paragraph.
  public static let paragraphFraction: CGFloat = 1 / heightBandCount

  /// The fraction of the height of the text, from the top, of a point in
  /// the code block.
  public static let codeFraction: CGFloat = 1 - paragraphFraction

  /// The point at the horizontal center of `frame`, at `fraction` of its
  /// height from the top.
  ///
  /// - Parameters:
  ///   - fraction: The fraction of the height, from the top.
  ///   - frame: The frame of the text.
  ///   - isFlipped: `true` when the y axis of `frame` goes down, as in a
  ///     flipped view. `false` when it goes up, as in the screen.
  /// - Returns: The point, in the space of `frame`.
  public static func point(atFraction fraction: CGFloat, of frame: CGRect, isFlipped: Bool)
    -> CGPoint
  {
    let offset = frame.height * fraction
    return CGPoint(x: frame.midX, y: isFlipped ? frame.minY + offset : frame.maxY - offset)
  }
}
