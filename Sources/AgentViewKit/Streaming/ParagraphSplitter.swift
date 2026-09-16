/// Splits a Markdown message into settled paragraphs and a streaming tail
/// (plan.md §8).
///
/// Textual has no streaming mode and parses its full input on each update
/// (plan.md §4.2). The view gives each settled paragraph to Textual one time,
/// and parses only the tail again for each chunk.
///
/// The rules:
/// - A blank line ends a paragraph. A line that has only whitespace is blank.
/// - A fenced code block is one paragraph. A blank line in the fence does not
///   end it. A fence line starts a new paragraph, and a closing fence line ends
///   it, also with no blank line around it. ``MarkdownFence`` has the fence
///   rules.
/// - The last paragraph is the tail, because the stream can add more text to
///   it. When the message ends with a blank line, each paragraph is settled
///   and the tail is empty.
/// - An open fence is always in the tail. So ``StreamingMarkdownBalancer`` can
///   find an open fence in the tail alone.
///
/// CRLF and lone CR line breaks become LF before the split.
public nonisolated enum ParagraphSplitter {
  /// One settled paragraph.
  public nonisolated struct Paragraph: Identifiable, Hashable, Sendable {
    /// The stable identity of a paragraph.
    ///
    /// The id does not change when the stream adds text after the paragraph.
    public nonisolated struct ID: Hashable, Sendable {
      /// The position of the paragraph in the message, from zero.
      public let index: Int
      /// The 64-bit FNV-1a hash of the UTF-8 bytes of the paragraph text.
      ///
      /// The hash is the same in each process. Swift's `Hasher` has a
      /// random seed for each process, so the splitter does not use it.
      public let textHash: UInt64

      /// Makes an id from its parts.
      ///
      /// - Parameters:
      ///   - index: The position of the paragraph in the message.
      ///   - textHash: The FNV-1a hash of the paragraph text.
      public init(index: Int, textHash: UInt64) {
        self.index = index
        self.textHash = textHash
      }
    }

    /// The stable identity of the paragraph.
    public let id: ID
    /// The Markdown text of the paragraph, with no line break at the end.
    public let text: String

    /// Makes a paragraph, and computes its id from `index` and `text`.
    ///
    /// - Parameters:
    ///   - index: The position of the paragraph in the message, from zero.
    ///   - text: The Markdown text of the paragraph.
    public init(index: Int, text: String) {
      self.id = ID(index: index, textHash: Self.fnv1a(text))
      self.text = text
    }

    /// The 64-bit FNV-1a offset basis.
    private static let fnvOffsetBasis: UInt64 = 0xCBF2_9CE4_8422_2325

    /// The 64-bit FNV-1a prime.
    private static let fnvPrime: UInt64 = 0x0000_0100_0000_01B3

    /// Computes the 64-bit FNV-1a hash of the UTF-8 bytes of `text`.
    ///
    /// - Parameter text: The text to hash.
    /// - Returns: The hash.
    private static func fnv1a(_ text: String) -> UInt64 {
      text.utf8.reduce(fnvOffsetBasis) { hash, byte in
        (hash ^ UInt64(byte)) &* fnvPrime
      }
    }
  }

  /// Splits `markdown` into settled paragraphs and the tail.
  ///
  /// - Parameter markdown: The full message text that the stream has now.
  /// - Returns: The settled paragraphs in message order, and the tail. The
  ///   tail is the raw text of the last paragraph, with its line breaks. It is
  ///   empty when no paragraph is open.
  public static func split(_ markdown: String) -> (settled: [Paragraph], tail: String) {
    let text = MarkdownFence.normalizeLineBreaks(markdown)
    var lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    // The text after the last line break is a line that is not complete yet.
    // `split` always returns one element or more.
    let partialLine = lines.removeLast()
    var builder = Builder()
    for line in lines {
      builder.add(completeLine: line)
    }
    builder.add(partialLine: partialLine)
    let tail = builder.tailStart.map { String(text[$0...]) } ?? ""
    return (builder.settled, tail)
  }

  /// The state of one split.
  private nonisolated struct Builder {
    /// The paragraphs that are settled.
    var settled: [Paragraph] = []
    /// The start of the open paragraph in the message, or `nil` when no
    /// paragraph is open.
    var tailStart: String.Index?
    /// The complete lines of the open paragraph.
    private var lines: [Substring] = []
    /// The opening data of the open fence, or `nil` when no fence is open.
    private var fence: MarkdownFence.Opening?

    /// Adds a line that has a line break after it.
    ///
    /// - Parameter line: The line, with no line break.
    mutating func add(completeLine line: Substring) {
      if let openFence = fence {
        lines.append(line)
        if MarkdownFence.closes(line, openFence) { settle() }
      } else if let newFence = MarkdownFence.opening(line) {
        settle()
        appendToParagraph(line)
        fence = newFence
      } else if isBlank(line) {
        settle()
      } else {
        appendToParagraph(line)
      }
    }

    /// Adds the last line of the message, which has no line break after it.
    ///
    /// The line stays in the tail. A fence line starts a new tail, so that
    /// the tail starts with the fence.
    ///
    /// - Parameter line: The line. It can be empty.
    mutating func add(partialLine line: Substring) {
      guard fence == nil else { return }
      if MarkdownFence.opening(line) != nil {
        settle()
        tailStart = line.startIndex
      } else if tailStart == nil, !isBlank(line) {
        tailStart = line.startIndex
      }
    }

    /// Adds `line` to the open paragraph, and opens a paragraph when none is
    /// open.
    ///
    /// - Parameter line: The line, with no line break.
    private mutating func appendToParagraph(_ line: Substring) {
      if tailStart == nil { tailStart = line.startIndex }
      lines.append(line)
    }

    /// Settles the open paragraph, if there is one.
    private mutating func settle() {
      if !lines.isEmpty {
        settled.append(Paragraph(index: settled.count, text: lines.joined(separator: "\n")))
      }
      lines = []
      tailStart = nil
      fence = nil
    }

    /// Tells if `line` is blank.
    ///
    /// - Parameter line: The line, with no line break.
    /// - Returns: `true` when the line is empty or has only whitespace.
    private func isBlank(_ line: Substring) -> Bool {
      line.allSatisfy(\.isWhitespace)
    }
  }
}
