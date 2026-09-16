/// The code fence rules that ``ParagraphSplitter`` and
/// ``StreamingMarkdownBalancer`` share (plan.md §8).
///
/// A fence line has at most three spaces of indent, and then a run of three or
/// more backticks. The info string follows the run. A closing fence line has a
/// run of backticks that is at least as long as the opening run, and nothing
/// after the run but whitespace. The two types must use the same rules, so that
/// the balancer sees an open fence exactly when the splitter keeps the fence in
/// the tail.
nonisolated enum MarkdownFence {
  /// The data of an opening fence line.
  struct Opening: Equatable, Sendable {
    /// The count of backticks in the run.
    var length: Int
    /// The first word of the info string, or `nil` when there is no word.
    var language: String?
  }

  /// The largest indent that a fence line can have.
  private static let maximumIndent = 3

  /// The smallest count of backticks in a fence run.
  private static let minimumLength = 3

  /// Changes each CRLF and each lone CR to LF.
  ///
  /// - Parameter text: The Markdown text.
  /// - Returns: The text with LF line breaks only.
  static func normalizeLineBreaks(_ text: String) -> String {
    guard text.utf8.contains(UInt8(ascii: "\r")) else { return text }
    return text.replacing("\r\n", with: "\n").replacing("\r", with: "\n")
  }

  /// Reads `line` as an opening fence line.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The opening data, or `nil` when `line` is not a fence line.
  ///   An info string that has a backtick makes the line not a fence line.
  static func opening(_ line: Substring) -> Opening? {
    guard let (length, rest) = backtickRun(line) else { return nil }
    guard !rest.contains("`") else { return nil }
    let language = rest.split(whereSeparator: \.isWhitespace).first.map(String.init)
    return Opening(length: length, language: language)
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
