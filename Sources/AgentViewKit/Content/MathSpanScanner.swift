/// Finds the `$…$` and `$$…$$` math spans of a Markdown text, before the
/// Markdown parse (plan.md §11 decision 7).
///
/// The Markdown parse removes the backslash of an escape such as `\,` or
/// `\\`. Thus the kit finds the math spans in the raw text, and the Markdown
/// parse never sees the LaTeX source. Docs/decisions/math-engine.md records
/// this.
///
/// The rules:
///
/// - Block math is `$$<source>$$`. The source can have line breaks. The
///   source must have a character that is not whitespace.
/// - Inline math is `$<source>$` on one line. The character after the
///   opening `$` is not whitespace. The character before the closing `$` is
///   not whitespace. The character after the closing `$` is not a digit.
///   Thus "It costs $5 and $10" has no math. This is the Pandoc rule.
/// - `\$` is a literal dollar sign.
/// - The scanner does not look in code spans or in fenced code blocks.
nonisolated enum MathSpanScanner {
  /// One part of a Markdown text.
  enum Piece: Equatable {
    /// Markdown text with no math span.
    case text(String)
    /// One math span.
    ///
    /// - Parameters:
    ///   - span: The source and the display style.
    ///   - source: The span as it is in the text, with its delimiters.
    case math(MathMarkdownParser.Span, source: String)
  }

  /// The dollar sign that starts and ends a span.
  static let dollar: Character = "$"

  /// The escape character of Markdown.
  static let backslash: Character = "\\"

  /// The character of a code span.
  static let backtick: Character = "`"

  /// The characters that can make a code fence.
  static let fenceCharacters: Set<Character> = ["`", "~"]

  /// The smallest number of fence characters in a code fence.
  static let minimumFenceLength = 3

  /// The largest indent of a code fence, in spaces.
  static let maximumFenceIndent = 3

  /// The number of characters in an escape: the backslash and the escaped
  /// character.
  static let escapeLength = 2

  /// Splits `markdown` into text parts and math spans.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The parts, in text order. Two text parts are never next to
  ///   each other.
  static func pieces(in markdown: String) -> [Piece] {
    var scanner = Scan(text: markdown)
    return scanner.run()
  }

  /// The math spans of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The spans, in text order.
  static func spans(in markdown: String) -> [MathMarkdownParser.Span] {
    pieces(in: markdown).compactMap { piece in
      if case .math(let span, _) = piece { span } else { nil }
    }
  }

  /// The one block span of `markdown`, when the text has only that span and
  /// whitespace.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The block span, or `nil`.
  static func soleBlock(in markdown: String) -> MathMarkdownParser.Span? {
    let parts = pieces(in: markdown).filter { piece in
      if case .text(let text) = piece { !text.allSatisfy(\.isWhitespace) } else { true }
    }
    guard parts.count == 1, case .math(let span, _) = parts.first, span.display else {
      return nil
    }
    return span
  }

  /// The state of one scan.
  private struct Scan {
    /// The text to scan.
    let text: String

    /// The position of the scan.
    var index: String.Index

    /// The parts that the scan found.
    var pieces: [Piece] = []

    /// The text since the last math span.
    var pending = ""

    /// Makes the state at the start of `text`.
    ///
    /// - Parameter text: The text to scan.
    init(text: String) {
      self.text = text
      index = text.startIndex
    }

    /// Scans the full text.
    ///
    /// - Returns: The parts, in text order.
    mutating func run() -> [Piece] {
      while index < text.endIndex {
        let character = text[index]
        if isLineStart, let end = fenceBlockEnd(from: index) {
          copy(to: end)
        } else if character == MathSpanScanner.backslash {
          copy(to: escapeEnd(from: index))
        } else if character == MathSpanScanner.backtick {
          copy(to: codeSpanEnd(from: index))
        } else if character == MathSpanScanner.dollar, let (span, end) = mathSpan(from: index) {
          if !pending.isEmpty {
            pieces.append(.text(pending))
            pending = ""
          }
          pieces.append(.math(span, source: String(text[index..<end])))
          index = end
        } else {
          copy(to: text.index(after: index))
        }
      }
      if !pending.isEmpty {
        pieces.append(.text(pending))
      }
      return pieces
    }

    /// Whether the scan is at the start of a line.
    var isLineStart: Bool {
      index == text.startIndex || text[text.index(before: index)] == "\n"
    }

    /// Copies the text up to `end` into the pending text.
    ///
    /// - Parameter end: The position after the last character to copy.
    mutating func copy(to end: String.Index) {
      pending += text[index..<end]
      index = end
    }

    /// The end of the escape that starts at `position`.
    ///
    /// - Parameter position: The position of a backslash.
    /// - Returns: The position after the escaped character, or the end of the
    ///   text.
    func escapeEnd(from position: String.Index) -> String.Index {
      text.index(position, offsetBy: MathSpanScanner.escapeLength, limitedBy: text.endIndex)
        ?? text.endIndex
    }

    /// The end of the line that holds `position`, after its line break.
    ///
    /// - Parameter position: A position in the text.
    /// - Returns: The start of the next line, or the end of the text.
    func lineEnd(from position: String.Index) -> String.Index {
      guard let breakIndex = text[position...].firstIndex(of: "\n") else {
        return text.endIndex
      }
      return text.index(after: breakIndex)
    }

    /// The fence of the line at `position`: its character and its length.
    ///
    /// - Parameter position: The start of a line.
    /// - Returns: The fence, or `nil` when the line is not a code fence.
    func fence(at position: String.Index) -> (character: Character, length: Int)? {
      let line = text[position..<lineEnd(from: position)]
      let indent = line.prefix { $0 == " " }
      guard indent.count <= MathSpanScanner.maximumFenceIndent else { return nil }
      let rest = line.dropFirst(indent.count)
      guard let first = rest.first, MathSpanScanner.fenceCharacters.contains(first) else {
        return nil
      }
      let length = rest.prefix { $0 == first }.count
      guard length >= MathSpanScanner.minimumFenceLength else { return nil }
      return (first, length)
    }

    /// The end of the fenced code block that starts at `position`.
    ///
    /// - Parameter position: The start of a line.
    /// - Returns: The position after the closing fence line, the end of the
    ///   text when the block does not close, or `nil` when the line does not
    ///   open a code block.
    func fenceBlockEnd(from position: String.Index) -> String.Index? {
      guard let opening = fence(at: position) else { return nil }
      var line = lineEnd(from: position)
      while line < text.endIndex {
        let next = lineEnd(from: line)
        if let closing = fence(at: line), closing.character == opening.character,
          closing.length >= opening.length,
          text[line..<next].drop(while: { $0 == " " || $0 == closing.character })
            .allSatisfy(\.isWhitespace)
        {
          return next
        }
        line = next
      }
      return text.endIndex
    }

    /// The end of the code span that starts at `position`.
    ///
    /// - Parameter position: The position of a backtick.
    /// - Returns: The position after the closing backticks, or the position
    ///   after the opening backticks when the span does not close.
    func codeSpanEnd(from position: String.Index) -> String.Index {
      let length = text[position...].prefix { $0 == MathSpanScanner.backtick }.count
      let openingEnd = text.index(position, offsetBy: length)
      var search = openingEnd
      while let start = text[search...].firstIndex(of: MathSpanScanner.backtick) {
        let run = text[start...].prefix { $0 == MathSpanScanner.backtick }
        let runEnd = text.index(start, offsetBy: run.count)
        if run.count == length {
          return runEnd
        }
        search = runEnd
      }
      return openingEnd
    }

    /// The math span that starts at `position`.
    ///
    /// - Parameter position: The position of a dollar sign.
    /// - Returns: The span and the position after its closing delimiter, or
    ///   `nil` when no span starts at `position`.
    func mathSpan(from position: String.Index) -> (MathMarkdownParser.Span, String.Index)? {
      let next = text.index(after: position)
      if next < text.endIndex, text[next] == MathSpanScanner.dollar {
        return blockSpan(from: text.index(after: next))
      }
      return inlineSpan(from: next)
    }

    /// The block span whose source starts at `start`.
    ///
    /// - Parameter start: The position after the opening `$$`.
    /// - Returns: The span and the position after the closing `$$`, or `nil`.
    func blockSpan(from start: String.Index) -> (MathMarkdownParser.Span, String.Index)? {
      var position = start
      while position < text.endIndex {
        let character = text[position]
        if character == MathSpanScanner.backslash {
          position = escapeEnd(from: position)
          continue
        }
        let next = text.index(after: position)
        if character == MathSpanScanner.dollar, next < text.endIndex,
          text[next] == MathSpanScanner.dollar
        {
          let source = String(text[start..<position])
          guard !source.allSatisfy(\.isWhitespace) else { return nil }
          return (MathMarkdownParser.Span(latex: source, display: true), text.index(after: next))
        }
        position = next
      }
      return nil
    }

    /// The inline span whose source starts at `start`.
    ///
    /// - Parameter start: The position after the opening `$`.
    /// - Returns: The span and the position after the closing `$`, or `nil`.
    func inlineSpan(from start: String.Index) -> (MathMarkdownParser.Span, String.Index)? {
      guard start < text.endIndex, !text[start].isWhitespace else { return nil }
      var position = start
      while position < text.endIndex {
        let character = text[position]
        if character == "\n" { return nil }
        if character == MathSpanScanner.backslash {
          position = escapeEnd(from: position)
          continue
        }
        if character == MathSpanScanner.dollar {
          let end = text.index(after: position)
          guard !text[text.index(before: position)].isWhitespace,
            end == text.endIndex || !text[end].isNumber
          else {
            return nil
          }
          let source = String(text[start..<position])
          return (MathMarkdownParser.Span(latex: source, display: false), end)
        }
        position = text.index(after: position)
      }
      return nil
    }
  }
}
