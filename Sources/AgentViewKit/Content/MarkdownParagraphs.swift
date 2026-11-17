/// One paragraph of a Markdown text.
nonisolated struct MarkdownParagraph: Equatable, Sendable {
  /// The range of the paragraph in the text, from the start of its first
  /// line to the end of its last line, with no line break at the end.
  let range: Range<String.Index>

  /// Whether the paragraph is a fenced code block.
  let isFence: Bool
}

/// Finds the paragraphs of a Markdown text (plan.md §9 C).
///
/// The paragraph index of a ``CitationMarker`` counts these paragraphs. The
/// rules:
/// - A blank line ends a paragraph. A line that has only whitespace is blank.
/// - A fenced code block is one paragraph. A blank line in the fence does not
///   end it. A fence line starts a new paragraph, and a closing fence line ends
///   it, also with no blank line around it. ``MarkdownFence`` has the fence
///   rules. A fence that does not close runs to the end of the text.
/// - A CRLF pair and a lone CR are line breaks, as an LF is.
nonisolated enum MarkdownParagraphs {
  /// The paragraphs of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The paragraphs, in text order.
  static func paragraphs(in markdown: String) -> [MarkdownParagraph] {
    var builder = Builder()
    for line in markdown.split(omittingEmptySubsequences: false, whereSeparator: isLineBreak) {
      builder.add(line)
    }
    builder.settle()
    return builder.paragraphs
  }

  /// Tells whether a character is a line break of the paragraph rules.
  ///
  /// - Parameter character: A character of the text.
  /// - Returns: `true` for an LF, a CR, and a CRLF pair.
  private static func isLineBreak(_ character: Character) -> Bool {
    character == "\n" || character == "\r" || character == "\r\n"
  }

  /// The state of one scan.
  private nonisolated struct Builder {
    /// The paragraphs that are complete.
    var paragraphs: [MarkdownParagraph] = []

    /// The range of the open paragraph, or `nil` when no paragraph is open.
    private var open: Range<String.Index>?

    /// The opening data of the open fence, or `nil` when no fence is open.
    private var fence: MarkdownFence.Opening?

    /// Adds one line of the text.
    ///
    /// - Parameter line: The line, with no line break.
    mutating func add(_ line: Substring) {
      if let openFence = fence {
        extend(with: line)
        if MarkdownFence.closes(line, openFence) { settle() }
      } else if let newFence = MarkdownFence.opening(line) {
        settle()
        extend(with: line)
        fence = newFence
      } else if line.allSatisfy(\.isWhitespace) {
        settle()
      } else {
        extend(with: line)
      }
    }

    /// Ends the open paragraph, if there is one.
    mutating func settle() {
      if let open {
        paragraphs.append(MarkdownParagraph(range: open, isFence: fence != nil))
      }
      open = nil
      fence = nil
    }

    /// Adds `line` to the open paragraph, and opens a paragraph when none is
    /// open.
    ///
    /// - Parameter line: The line, with no line break.
    private mutating func extend(with line: Substring) {
      open = (open?.lowerBound ?? line.startIndex)..<line.endIndex
    }
  }
}
