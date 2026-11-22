/// One segment of the Markdown text of a response: prose, or a fenced code
/// block.
nonisolated enum MarkdownSegment: Equatable, Sendable {
  /// Markdown text with no fenced code block, with no blank line at its
  /// start or its end.
  case prose(String)

  /// The code of a fenced code block, with no fence line, and the language
  /// and the file name of its info string.
  case code(code: String, language: String?, filename: String?)

  /// Whether the segment is a fenced code block.
  var isCode: Bool {
    guard case .code = self else { return false }
    return true
  }
}

/// Finds the fenced code blocks of the Markdown text of a response, so that
/// ``ResponseView`` shows each one in a ``CodeBlockView``.
///
/// The rules are the CommonMark fence rules:
/// - A fence line has at most three spaces of indent, and then a run of three
///   or more backticks or tildes. The info string follows the run. An info
///   string after backticks has no backtick.
/// - A closing fence line has a run of the same character that is at least
///   as long as the opening run, and nothing after the run but whitespace.
/// - A code line loses the spaces of its indent, up to the indent of the
///   opening fence line.
/// - A fence that does not close runs to the end of the text, as the text of
///   a response that still streams does.
/// - A CRLF pair and a lone CR are line breaks, as an LF is.
///
/// ``CodeFenceInfo`` reads the language and the file name from the info
/// string. These rules are not the rules of ``MarkdownFence``, which finds
/// only backtick fences for the paragraph index of a ``CitationMarker``.
nonisolated enum MarkdownCodeFences {
  /// One segment and its range in the text.
  struct Piece: Equatable, Sendable {
    /// The segment.
    let segment: MarkdownSegment

    /// The range of the segment in the text. The range of a prose segment
    /// holds exactly the text of the segment. The range of a code segment
    /// holds its fence lines also.
    let range: Range<String.Index>
  }

  /// The segments of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The segments, in text order. A text with no fence gives one
  ///   prose segment that is equal to the text.
  static func segments(in markdown: String) -> [MarkdownSegment] {
    pieces(in: markdown).map(\.segment)
  }

  /// The segments of `markdown`, with their ranges.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The pieces, in text order. A text with no fence gives one
  ///   prose piece that holds the whole text.
  static func pieces(in markdown: String) -> [Piece] {
    var builder = Builder()
    for line in markdown.split(
      omittingEmptySubsequences: false, whereSeparator: MarkdownParagraphs.isLineBreak)
    {
      builder.add(line)
    }
    let pieces = builder.finish()
    guard pieces.contains(where: \.segment.isCode) else {
      return [Piece(segment: .prose(markdown), range: markdown.startIndex..<markdown.endIndex)]
    }
    return pieces
  }

  /// The state of one scan.
  private nonisolated struct Builder {
    /// The pieces that are complete.
    private var pieces: [Piece] = []

    /// The open prose, from the start of its first line that is not blank
    /// to the end of its last line that is not blank, or `nil` when no prose
    /// is open.
    private var prose: Substring?

    /// The open fence, or `nil` when no fence is open.
    private var fence: OpenFence?

    /// Adds one line of the text.
    ///
    /// - Parameter line: The line, with no line break.
    mutating func add(_ line: Substring) {
      if var open = fence {
        if CodeFenceLine.closes(line, open.opening) {
          open.end = line.endIndex
          settle(open)
        } else {
          open.add(line)
          fence = open
        }
      } else if let opening = CodeFenceLine.opening(line) {
        settleProse()
        fence = OpenFence(opening: opening, start: line.startIndex, end: line.endIndex)
      } else if !line.allSatisfy(\.isWhitespace) {
        prose = line.base[(prose?.startIndex ?? line.startIndex)..<line.endIndex]
      }
    }

    /// Ends the open fence and the open prose.
    ///
    /// - Returns: The pieces of the text, in text order.
    mutating func finish() -> [Piece] {
      if let fence { settle(fence) }
      settleProse()
      return pieces
    }

    /// Ends the open prose, if there is one.
    private mutating func settleProse() {
      guard let prose else { return }
      pieces.append(Piece(segment: .prose(String(prose)), range: prose.startIndex..<prose.endIndex))
      self.prose = nil
    }

    /// Ends `open` as a code piece.
    ///
    /// - Parameter open: The fence.
    private mutating func settle(_ open: OpenFence) {
      pieces.append(Piece(segment: open.segment, range: open.start..<open.end))
      fence = nil
    }
  }

  /// A fence that is open in a scan.
  private nonisolated struct OpenFence {
    /// The data of the opening fence line.
    let opening: CodeFenceLine.Opening

    /// The start of the opening fence line.
    let start: String.Index

    /// The end of the last line of the fence.
    var end: String.Index

    /// The code lines, with no indent up to the indent of the opening line.
    private var lines: [Substring] = []

    /// Makes a fence with no code line.
    ///
    /// - Parameters:
    ///   - opening: The data of the opening fence line.
    ///   - start: The start of the opening fence line.
    ///   - end: The end of the opening fence line.
    init(opening: CodeFenceLine.Opening, start: String.Index, end: String.Index) {
      self.opening = opening
      self.start = start
      self.end = end
    }

    /// Adds one code line.
    ///
    /// - Parameter line: The line, with no line break.
    mutating func add(_ line: Substring) {
      let indent = line.prefix(opening.indent).prefix { $0 == " " }
      lines.append(line[indent.endIndex...])
      end = line.endIndex
    }

    /// The code segment of the fence.
    var segment: MarkdownSegment {
      let info = CodeFenceInfo(opening.info)
      return .code(
        code: lines.joined(separator: "\n"), language: info.language, filename: info.filename)
    }
  }
}

/// The fence line rules of ``MarkdownCodeFences``. ``MarkdownFence`` also
/// reads its fence lines with these rules, and keeps only a backtick run.
nonisolated enum CodeFenceLine {
  /// The data of an opening fence line.
  struct Opening: Equatable, Sendable {
    /// The character of the run: a backtick or a tilde.
    let character: Character

    /// The count of characters in the run.
    let length: Int

    /// The count of spaces before the run.
    let indent: Int

    /// The info string: the text after the run.
    let info: Substring
  }

  /// The largest indent that a fence line can have.
  private static let maximumIndent = 3

  /// The smallest count of characters in a fence run.
  private static let minimumLength = 3

  /// The characters that make a fence run.
  private static let fenceCharacters: Set<Character> = ["`", "~"]

  /// The fence character whose info string cannot hold it.
  private static let backtick: Character = "`"

  /// Reads `line` as an opening fence line.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The opening data, or `nil` when `line` is not a fence line.
  static func opening(_ line: Substring) -> Opening? {
    guard let run = run(in: line) else { return nil }
    guard run.character != backtick || !run.rest.contains(backtick) else { return nil }
    return Opening(
      character: run.character, length: run.length, indent: run.indent, info: run.rest)
  }

  /// Tells whether `line` closes a fence that `opening` opened.
  ///
  /// - Parameters:
  ///   - line: One line, with no line break.
  ///   - opening: The opening data of the open fence.
  /// - Returns: `true` when `line` is a closing fence line for `opening`.
  static func closes(_ line: Substring, _ opening: Opening) -> Bool {
    guard let run = run(in: line) else { return false }
    return run.character == opening.character && run.length >= opening.length
      && run.rest.allSatisfy(\.isWhitespace)
  }

  /// Reads the indent and the fence run at the start of `line`.
  ///
  /// - Parameter line: One line, with no line break.
  /// - Returns: The character, the length and the indent of the run, and
  ///   the text after it, or `nil` when the line does not start with a run.
  private static func run(in line: Substring) -> (
    character: Character, length: Int, indent: Int, rest: Substring
  )? {
    let indent = line.prefix { $0 == " " }
    guard indent.count <= maximumIndent else { return nil }
    let afterIndent = line[indent.endIndex...]
    guard let character = afterIndent.first, fenceCharacters.contains(character) else {
      return nil
    }
    let run = afterIndent.prefix { $0 == character }
    guard run.count >= minimumLength else { return nil }
    return (character, run.count, indent.count, afterIndent[run.endIndex...])
  }
}

/// The language and the file name of the info string of a fence, as the
/// EditorKit `FencedCodeBlock` reads them.
///
/// - The first word of the info string is the language.
/// - In the pandoc attribute form (`{.python}`), the language is the first
///   class, with no period.
/// - The value of a `title` or `file` attribute (`key=value`) is the file
///   name. The value can be in double quotes or in single quotes. With no
///   such attribute, the first word after the language that is not an
///   attribute is the file name. The attribute form takes the file name only
///   from an attribute.
nonisolated struct CodeFenceInfo: Equatable, Sendable {
  /// The language, or `nil` when the info string has none.
  let language: String?

  /// The file name, or `nil` when the info string gives none.
  let filename: String?

  /// The keys of an attribute whose value is the file name, in order of
  /// priority.
  private static let fileNameKeys = ["title", "file"]

  /// The first character of the pandoc attribute form.
  private static let attributeFormOpening: Character = "{"

  /// The prefix of a class in the pandoc attribute form.
  private static let classPrefix: Character = "."

  /// Reads an info string.
  ///
  /// - Parameter info: The text after the fence run.
  init(_ info: Substring) {
    let text = info.drop { $0.isWhitespace }
    let isAttributeForm = text.first == Self.attributeFormOpening
    let tokens = InfoToken.tokens(of: isAttributeForm ? text : text.drop { !$0.isWhitespace })
    let languageText =
      isAttributeForm
      ? tokens.lazy.compactMap(\.word).first.map(Self.className(of:))
      : text.prefix { !$0.isWhitespace }
    let attributes = Dictionary(
      tokens.compactMap(\.attribute), uniquingKeysWith: { first, _ in first })
    let attributeName = Self.fileNameKeys.lazy.compactMap { attributes[$0] }.first
    let word = isAttributeForm ? nil : tokens.lazy.compactMap(\.word).first
    language = Self.nonEmpty(languageText)
    filename = Self.nonEmpty(attributeName ?? word)
  }

  /// `text` as a string, or `nil` when it is empty.
  ///
  /// - Parameter text: A part of the info string, or `nil`.
  /// - Returns: The string, or `nil`.
  private static func nonEmpty(_ text: Substring?) -> String? {
    guard let text, !text.isEmpty else { return nil }
    return String(text)
  }

  /// `text` with no class prefix.
  ///
  /// - Parameter text: The first word of the pandoc attribute form.
  /// - Returns: The class name.
  private static func className(of text: Substring) -> Substring {
    text.first == classPrefix ? text.dropFirst() : text
  }
}

/// One token of an info string after its language: an attribute
/// (`key=value`) or a word.
private nonisolated enum InfoToken {
  /// An attribute with its key and its value, with no quotes.
  case attribute(key: String, value: Substring)

  /// A word that is not an attribute. A brace of the pandoc attribute form
  /// is not part of a word.
  case word(Substring)

  /// The key and the value of an attribute token, or `nil` for a word.
  var attribute: (key: String, value: Substring)? {
    guard case .attribute(let key, let value) = self else { return nil }
    return (key, value)
  }

  /// The text of a word token, or `nil` for an attribute.
  var word: Substring? {
    guard case .word(let text) = self else { return nil }
    return text
  }

  /// The tokens of `text`, in order.
  ///
  /// - Parameter text: The info string after its language, or the whole
  ///   info string in the pandoc attribute form.
  /// - Returns: The tokens.
  static func tokens(of text: Substring) -> [InfoToken] {
    let token = /([^\s={}]+)=(?:"([^"]*)"|'([^']*)'|([^\s{}]*))|([^\s{}]+)/
    return text.matches(of: token).map { match in
      let (_, key, doubleQuoted, singleQuoted, bare, word) = match.output
      guard let key else { return .word(word ?? "") }
      return .attribute(key: String(key), value: doubleQuoted ?? singleQuoted ?? bare ?? "")
    }
  }
}
