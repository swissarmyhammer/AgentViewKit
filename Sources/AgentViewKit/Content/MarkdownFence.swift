/// The code fence rules of ``MarkdownParagraphs`` (plan.md §9 C).
///
/// A fence line has at most three spaces of indent, and then a run of three or
/// more backticks. The info string follows the run. A closing fence line has a
/// run of backticks that is at least as long as the opening run, and nothing
/// after the run but whitespace.
nonisolated enum MarkdownFence {
  /// The data of an opening fence line.
  struct Opening: Equatable, Sendable {
    /// The count of backticks in the run.
    var length: Int
  }

  /// The largest indent that a fence line can have.
  private static let maximumIndent = 3

  /// The smallest count of backticks in a fence run.
  private static let minimumLength = 3

  /// Reads `line` as an opening fence line.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The opening data, or `nil` when `line` is not a fence line.
  ///   An info string that has a backtick makes the line not a fence line.
  static func opening(_ line: Substring) -> Opening? {
    guard let (length, rest) = backtickRun(line) else { return nil }
    guard !rest.contains("`") else { return nil }
    return Opening(length: length)
  }

  /// Tells if `line` closes a fence that `opening` opened.
  ///
  /// - Parameters:
  ///   - line: One line, with no line break.
  ///   - opening: The opening data of the open fence.
  /// - Returns: `true` when `line` is a closing fence line for `opening`.
  static func closes(_ line: Substring, _ opening: Opening) -> Bool {
    guard let (length, rest) = backtickRun(line) else { return false }
    return length >= opening.length && rest.allSatisfy(\.isWhitespace)
  }

  /// Reads the indent and the backtick run at the start of `line`.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The run length and the text after the run, or `nil` when the
  ///   line does not start with a fence run.
  private static func backtickRun(_ line: Substring) -> (Int, Substring)? {
    let indent = line.prefix(while: { $0 == " " })
    guard indent.count <= maximumIndent else { return nil }
    let afterIndent = line[indent.endIndex...]
    let run = afterIndent.prefix(while: { $0 == "`" })
    guard run.count >= minimumLength else { return nil }
    return (run.count, afterIndent[run.endIndex...])
  }
}
