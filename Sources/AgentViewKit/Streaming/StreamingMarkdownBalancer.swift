/// Makes the streaming tail of a Markdown message safe to render
/// (plan.md §8).
///
/// While a response streams, the tail can stop in the middle of a span, as in
/// `some **bold`. Textual shows the literal `**` until the closing delimiter
/// arrives. The balancer adds the missing closing delimiters at the end of the
/// tail, so that the span shows with its style at once.
///
/// The balancer works on the tail that ``ParagraphSplitter`` returns. It never
/// changes a settled paragraph. An open code fence is always in the tail,
/// because the splitter never settles a fence that is not closed. So the
/// balancer finds an open fence in the tail alone: an odd count of fence lines
/// in the message is an odd count of fence lines in the tail.
public nonisolated enum StreamingMarkdownBalancer {
  /// The balanced form of a streaming tail.
  public nonisolated enum BalancedTail: Equatable, Sendable {
    /// Markdown text to give to Textual. The balancer added the missing
    /// closing delimiters.
    case markdown(String)
    /// The tail is a code fence that is not closed. The caller gives `body`
    /// to the EditorKit append path (`EditorModel.syncStreaming(to:)`).
    ///
    /// - Parameters:
    ///   - language: The first word of the info string, or `nil`.
    ///   - body: The text after the opening fence line, as the stream sent it.
    case openFence(language: String?, body: String)
  }

  /// Balances `tail`.
  ///
  /// - When the tail has a fence that is not closed, the result is
  ///   ``BalancedTail/openFence(language:body:)``. The balancer adds no
  ///   closing delimiters.
  /// - When the tail has only closed fences, the result is the tail with no
  ///   change.
  /// - Otherwise, the result is the tail with a closing delimiter for each
  ///   dangling `**`, `__`, `*`, `_`, backtick run, `[`, and link
  ///   destination `(`. The closing delimiters go in reverse order of the
  ///   opening delimiters, before the whitespace at the end of the tail.
  ///
  /// - Parameter tail: The streaming tail of a message.
  /// - Returns: The balanced tail.
  public static func balance(tail: String) -> BalancedTail {
    switch scanFences(MarkdownFence.normalizeLineBreaks(tail)) {
    case .none:
      return .markdown(balanceInline(tail))
    case .closed:
      return .markdown(tail)
    case .open(let language, let body):
      return .openFence(language: language, body: body)
    }
  }

  // MARK: - Fences

  /// The fence state at the end of a tail.
  private enum FenceScan {
    /// The tail has no fence line.
    case none
    /// Each fence in the tail is closed.
    case closed
    /// The last fence in the tail is not closed.
    case open(language: String?, body: String)
  }

  /// Finds the fence state at the end of `text`.
  ///
  /// - Parameter text: The tail, with LF line breaks only.
  /// - Returns: The fence state.
  private static func scanFences(_ text: String) -> FenceScan {
    var result = FenceScan.none
    var openFence: MarkdownFence.Opening?
    var bodyStart = text.endIndex
    for line in text.split(separator: "\n", omittingEmptySubsequences: false) {
      if let fence = openFence {
        if MarkdownFence.closes(line, fence) {
          openFence = nil
          result = .closed
        }
      } else if let fence = MarkdownFence.opening(line) {
        openFence = fence
        // The body starts after the line break of the opening line. When the
        // opening line has no line break yet, the body is empty.
        bodyStart =
          line.endIndex < text.endIndex ? text.index(after: line.endIndex) : text.endIndex
      }
    }
    if let fence = openFence {
      result = .open(language: fence.language, body: String(text[bodyStart...]))
    }
    return result
  }

  // MARK: - Inline delimiters

  /// A delimiter that is open.
  private enum Opener: Equatable {
    /// An emphasis or strong delimiter: `*`, `_`, `**`, or `__`.
    case emphasis(String)
    /// The `[` that starts link text.
    case linkText

    /// The text that closes the delimiter.
    var closer: String {
      switch self {
      case .emphasis(let marker): marker
      case .linkText: "]"
      }
    }
  }

  /// The inline delimiter state of a scan.
  private struct InlineScanner {
    /// The characters of the tail.
    let characters: [Character]
    /// The open emphasis and link text delimiters, from the first to the last.
    var openers: [Opener] = []
    /// The length of the backtick run of the open code span, or `nil`.
    var codeSpanLength: Int?
    /// `true` while the scan is in a link destination, after `](`.
    var inLinkDestination = false

    /// The longest emphasis delimiter.
    private static let strongLength = 2

    /// Scans each character of the tail.
    mutating func scan() {
      var index = 0
      while index < characters.count {
        index = step(at: index)
      }
    }

    /// The text that closes each open delimiter, innermost first.
    var closers: String {
      // A code span and a link destination take no other delimiter, so they
      // are always innermost.
      let codeSpan = codeSpanLength.map { String(repeating: "`", count: $0) } ?? ""
      let destination = inLinkDestination ? ")" : ""
      return codeSpan + destination + openers.reversed().map(\.closer).joined()
    }

    /// Scans the token at `index`.
    ///
    /// - Parameter index: The position of the token.
    /// - Returns: The position after the token.
    private mutating func step(at index: Int) -> Int {
      let character = characters[index]
      if let length = codeSpanLength {
        guard character == "`" else { return index + 1 }
        let run = runLength(at: index)
        if run == length { codeSpanLength = nil }
        return index + run
      }
      if inLinkDestination {
        if character == "\\" { return index + 2 }
        if character == ")" { inLinkDestination = false }
        return index + 1
      }
      switch character {
      case "\\":
        return index + 2
      case "`":
        let run = runLength(at: index)
        codeSpanLength = run
        return index + run
      case "[":
        openers.append(.linkText)
        return index + 1
      case "]":
        return closeLinkText(at: index)
      case "*", "_":
        let run = runLength(at: index)
        addEmphasisRun(at: index, length: run)
        return index + run
      default:
        return index + 1
      }
    }

    /// Closes the open link text at the `]` at `index`, if there is one.
    ///
    /// - Parameter index: The position of the `]`.
    /// - Returns: The position after the `]`, or after `](` when a link
    ///   destination starts.
    private mutating func closeLinkText(at index: Int) -> Int {
      guard let opener = openers.lastIndex(of: .linkText) else { return index + 1 }
      // An emphasis delimiter in the link text that is not closed stays
      // literal text.
      openers.removeSubrange(opener...)
      let next = index + 1
      guard next < characters.count, characters[next] == "(" else { return next }
      inLinkDestination = true
      return next + 1
    }

    /// Opens or closes the emphasis delimiters of a run of `*` or `_`.
    ///
    /// The run makes one `**` or `__` token for each two characters, and one
    /// `*` or `_` token for a character that remains. A token closes the
    /// open delimiter with the same marker when the character before the run
    /// is not whitespace. Otherwise, the token opens a delimiter when the
    /// character after the run is not whitespace. An `_` run between two
    /// letters or digits does not open a delimiter.
    ///
    /// - Parameters:
    ///   - index: The position of the run.
    ///   - length: The length of the run.
    private mutating func addEmphasisRun(at index: Int, length: Int) {
      let character = characters[index]
      let before = index > 0 ? characters[index - 1] : nil
      let after = index + length < characters.count ? characters[index + length] : nil
      let canClose = before.map { !$0.isWhitespace } ?? false
      var canOpen = after.map { !$0.isWhitespace } ?? false
      if character == "_", let before, before.isLetter || before.isNumber {
        canOpen = false
      }
      var remaining = length
      while remaining > 0 {
        let tokenLength = min(remaining, Self.strongLength)
        remaining -= tokenLength
        let opener = Opener.emphasis(String(repeating: character, count: tokenLength))
        if canClose, let open = openers.lastIndex(of: opener) {
          openers.removeSubrange(open...)
        } else if canOpen {
          openers.append(opener)
        }
      }
    }

    /// Counts the characters equal to the character at `index`, from
    /// `index`.
    ///
    /// - Parameter index: The position of the run.
    /// - Returns: The length of the run.
    private func runLength(at index: Int) -> Int {
      let character = characters[index]
      var end = index
      while end < characters.count, characters[end] == character {
        end += 1
      }
      return end - index
    }
  }

  /// Adds the closing delimiters to a tail that has no fence line.
  ///
  /// - Parameter tail: The tail.
  /// - Returns: The tail with the closing delimiters before its trailing
  ///   whitespace.
  private static func balanceInline(_ tail: String) -> String {
    var scanner = InlineScanner(characters: Array(tail))
    scanner.scan()
    let closers = scanner.closers
    guard !closers.isEmpty else { return tail }
    let trailing = tail.reversed().prefix(while: \.isWhitespace).count
    let split = tail.index(tail.endIndex, offsetBy: -trailing)
    return String(tail[..<split]) + closers + String(tail[split...])
  }
}
