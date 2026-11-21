/// An agent answer with a paragraph above a fenced code block.
///
/// The unit tests and the hosted tests of Copy Code Block in the item menu of
/// an answer use this answer, and keep no copy of their own. The answer
/// shows the paragraph in its Markdown editor and the code block in a
/// `CodeBlockView`, so a test right-clicks on each view.
public enum CodeBlockAnswerFixture {
  /// The number of code lines of the block.
  static let codeLineCount = 8

  /// The code of the block, with no fence lines.
  public static let code = (1...codeLineCount).map { "let value\($0) = \($0)" }
    .joined(separator: "\n")

  /// The Markdown of the answer: a paragraph, then a code block, with a
  /// line break after the closing fence.
  public static let markdown = fenceEndingMarkdown + "\n"

  /// The Markdown of an answer that ends with its closing fence: the same
  /// paragraph and code block as ``markdown``, with no line break after the
  /// closing fence.
  ///
  /// An agent answer often ends in this form. The code of the block is
  /// ``code`` also, with no fence line.
  public static let fenceEndingMarkdown = """
    The parser reads each line of the file. It keeps the name of each value, \
    and it skips each empty line. Then it gives the values to the caller, in \
    the order of the file, with no change. The code below shows the values.

    ```swift
    \(code)
    ```
    """
}
