/// The code fence rules of ``MarkdownParagraphs`` (plan.md §9 C).
///
/// A fence line has at most three spaces of indent, and then a run of three or
/// more backticks. The info string follows the run. A closing fence line has a
/// run of backticks that is at least as long as the opening run, and nothing
/// after the run but whitespace. ``CodeFenceLine`` reads the indent and the
/// run, so the two Markdown scanners have one run rule. A tilde run is not a
/// fence run here.
nonisolated enum MarkdownFence {
  /// The data of an opening fence line.
  struct Opening: Equatable, Sendable {
    /// The opening fence line, as ``CodeFenceLine`` reads it.
    let line: CodeFenceLine.Opening
  }

  /// The only character of a fence run of these rules.
  private static let backtick: Character = "`"

  /// Reads `line` as an opening fence line.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The opening data, or `nil` when `line` is not a fence line.
  ///   A tilde run, or an info string that has a backtick, makes the line not
  ///   a fence line.
  static func opening(_ line: Substring) -> Opening? {
    guard let opening = CodeFenceLine.opening(line), opening.character == backtick else {
      return nil
    }
    return Opening(line: opening)
  }

  /// Tells if `line` closes a fence that `opening` opened.
  ///
  /// - Parameters:
  ///   - line: One line, with no line break.
  ///   - opening: The opening data of the open fence.
  /// - Returns: `true` when `line` is a closing fence line for `opening`.
  static func closes(_ line: Substring, _ opening: Opening) -> Bool {
    CodeFenceLine.closes(line, opening.line)
  }
}
