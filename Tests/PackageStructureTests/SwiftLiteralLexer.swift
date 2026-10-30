/// Blanks the string literals and the comments of Swift source bytes, for the
/// structure scans of the kit that read code only.
///
/// The lexer knows a single-line literal, a multi-line literal, a raw
/// literal with `#` delimiters, an escape and an interpolation. It does not
/// know nested block comments.
///
/// EditorKit's engines read the code with an internal reader of their own
/// (`SwiftCodeText` of `EditorTestSupport`), which no other package can call,
/// so the scans of the kit's own rules keep this one.
enum SwiftLiteralLexer {
  /// One string literal.
  private struct Literal: Equatable {
    /// The offset of the first byte of the literal, the first `#` or `"`.
    let start: Int
    /// The offset after the last byte of the literal.
    let end: Int
  }

  /// The byte of `"`.
  private static let quote = UInt8(ascii: "\"")
  /// The byte of `#`.
  private static let hash = UInt8(ascii: "#")
  /// The byte of `\`.
  private static let backslash = UInt8(ascii: "\\")
  /// The byte of `/`.
  private static let slash = UInt8(ascii: "/")
  /// The byte of `*`.
  private static let star = UInt8(ascii: "*")
  /// The byte of `(`.
  private static let openParenthesis = UInt8(ascii: "(")
  /// The byte of a line break.
  private static let newline = UInt8(ascii: "\n")
  /// The byte of a space.
  private static let space = UInt8(ascii: " ")
  /// The number of quotes that open a multi-line literal.
  private static let multiLineQuoteCount = 3
  /// The bytes that open a line comment: `//`.
  private static let lineCommentOpener = [slash, slash]
  /// The bytes that open a block comment: `/*`.
  private static let blockCommentOpener = [slash, star]
  /// The bytes that close a block comment: `*/`.
  private static let blockCommentCloser = [star, slash]

  /// The bytes that open a bracket.
  private static let openers: Set<UInt8> = [openParenthesis, UInt8(ascii: "["), UInt8(ascii: "{")]
  /// The bytes that close a bracket.
  private static let closers: Set<UInt8> = [UInt8(ascii: ")"), UInt8(ascii: "]"), UInt8(ascii: "}")]

  /// Changes each byte of each comment and of each string literal to a
  /// space. A line break in a comment or in a literal stays, so the line
  /// numbers stay. The interpolation of a literal is part of the literal.
  ///
  /// - Parameter bytes: The source bytes.
  /// - Returns: The bytes with the comments and the string literals blanked.
  static func blankingCommentsAndLiterals(in bytes: [UInt8]) -> [UInt8] {
    var result = bytes
    var index = 0
    while index < bytes.count {
      if let literal = literal(in: bytes, at: index) {
        blank(literal.start..<literal.end, of: &result)
        index = literal.end
      } else if let end = commentEnd(in: bytes, at: index) {
        blank(index..<end, of: &result)
        index = end
      } else {
        index += 1
      }
    }
    return result
  }

  /// The change of the bracket depth at one byte.
  ///
  /// - Parameter byte: The byte.
  /// - Returns: `1` for an open bracket, `-1` for a close bracket, else `0`.
  private static func depthChange(of byte: UInt8) -> Int {
    if openers.contains(byte) { return 1 }
    if closers.contains(byte) { return -1 }
    return 0
  }

  /// Tells if some bytes stand at an offset.
  ///
  /// - Parameters:
  ///   - pattern: The bytes to find.
  ///   - bytes: The source bytes.
  ///   - offset: The offset.
  /// - Returns: `true` when `bytes` holds `pattern` at `offset`.
  private static func has(_ pattern: [UInt8], in bytes: [UInt8], at offset: Int) -> Bool {
    offset + pattern.count <= bytes.count && bytes[offset..<offset + pattern.count].elementsEqual(pattern)
  }

  /// Reads the string literal that starts at an offset.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset.
  /// - Returns: The literal, or `nil` when no literal starts at `start`.
  private static func literal(in bytes: [UInt8], at start: Int) -> Literal? {
    let quoteIndex = bytes[start...].firstIndex { $0 != hash } ?? bytes.count
    guard quoteIndex < bytes.count, bytes[quoteIndex] == quote else { return nil }
    let hashes = [UInt8](repeating: hash, count: quoteIndex - start)
    let multiLineQuotes = [UInt8](repeating: quote, count: multiLineQuoteCount)
    let isMultiLine = has(multiLineQuotes, in: bytes, at: quoteIndex)
    let opening = isMultiLine ? multiLineQuotes : [quote]
    return literalBody(
      in: bytes, start: start, contentStart: quoteIndex + opening.count,
      closing: opening + hashes, escape: [backslash] + hashes, isSingleLine: !isMultiLine)
  }

  /// Reads the content of a string literal up to its closing delimiter.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset of the literal.
  ///   - contentStart: The offset after the opening delimiter.
  ///   - closing: The closing delimiter.
  ///   - escape: The start of an escape.
  ///   - isSingleLine: `true` for a single-line literal.
  /// - Returns: The literal. An open single-line literal ends at its line
  ///   break.
  private static func literalBody(
    in bytes: [UInt8], start: Int, contentStart: Int, closing: [UInt8], escape: [UInt8], isSingleLine: Bool
  ) -> Literal {
    var index = contentStart
    while index < bytes.count {
      if has(escape, in: bytes, at: index) {
        index = escapeEnd(in: bytes, after: index + escape.count)
      } else if has(closing, in: bytes, at: index) {
        return Literal(start: start, end: index + closing.count)
      } else if isSingleLine, bytes[index] == newline {
        return Literal(start: start, end: index)
      } else {
        index += 1
      }
    }
    return Literal(start: start, end: bytes.count)
  }

  /// The offset after an escape.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset after the escape delimiter.
  /// - Returns: The offset after the interpolation when a `(` follows, else
  ///   the offset after the escaped byte.
  private static func escapeEnd(in bytes: [UInt8], after start: Int) -> Int {
    guard start < bytes.count, bytes[start] == openParenthesis else { return start + 1 }
    var depth = 1
    var index = start + 1
    while index < bytes.count {
      if let literal = literal(in: bytes, at: index) {
        index = literal.end
        continue
      }
      depth += depthChange(of: bytes[index])
      index += 1
      if depth == 0 { return index }
    }
    return bytes.count
  }

  /// Changes each byte in a range to a space. A line break stays.
  ///
  /// - Parameters:
  ///   - range: The offsets of the bytes to change.
  ///   - bytes: The source bytes.
  private static func blank(_ range: Range<Int>, of bytes: inout [UInt8]) {
    for position in range where bytes[position] != newline {
      bytes[position] = space
    }
  }

  /// The end of the comment that starts at an offset.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset.
  /// - Returns: The offset of the line break after a line comment, the offset
  ///   after the `*/` of a block comment, or `nil` when no comment starts at
  ///   `start`.
  private static func commentEnd(in bytes: [UInt8], at start: Int) -> Int? {
    if has(lineCommentOpener, in: bytes, at: start) {
      return bytes[start...].firstIndex(of: newline) ?? bytes.count
    }
    guard has(blockCommentOpener, in: bytes, at: start) else { return nil }
    var index = start + blockCommentOpener.count
    while index < bytes.count, !has(blockCommentCloser, in: bytes, at: index) {
      index += 1
    }
    return min(index + blockCommentCloser.count, bytes.count)
  }
}
