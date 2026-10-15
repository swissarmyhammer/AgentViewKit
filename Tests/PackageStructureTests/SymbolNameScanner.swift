import Foundation
import PackageFileSupport

/// One SF Symbol name in a Swift source file.
struct SymbolNameUse: Equatable, CustomStringConvertible {
  /// The file that holds the name, relative to the base of the scan.
  let file: String
  /// The line number of the name. The first line is line 1.
  let line: Int
  /// The symbol name: the text of the string literal.
  let name: String

  var description: String {
    "\(file):\(line) \(name)"
  }
}

/// Finds the SF Symbol names in the text of a Swift file.
///
/// A string literal is a symbol name when it stands in a symbol context:
///
/// - the argument of a `systemName:`, `systemImage:`, `systemSymbolName:` or
///   `symbolName:` label, such as `Image(systemName: "folder")`;
/// - the value or the body of a declaration whose name has the word `symbol`
///   in any case, or whose name is `systemImage` or `systemName`. Examples
///   are `static let commandSymbol = "terminal"`, `enum ToolKindSymbol { … }`
///   and `var systemImage: String { … }`.
///
/// Other literals are not symbol names. Thus the accessibility identifier
/// `static let identifier = "terminal"` is not a symbol name. The scan
/// ignores comments. A literal with an escape or an interpolation, and a
/// multi-line literal, are not symbol names.
struct SymbolNameScanner {
  /// Where the scan of a symbol context stops.
  enum RegionEnd {
    /// An argument or a value: the scan stops at a `,`, at a line break or
    /// at the close of the enclosing bracket.
    case argument
    /// A body: the scan starts at a `{` and stops at the matching `}`.
    case block
  }

  /// The UTF-8 bytes of the source, with each comment byte changed to a
  /// space. A line break in a comment stays.
  let code: [UInt8]

  /// Makes the scanner of one source.
  ///
  /// - Parameter source: The text of a Swift file.
  init(source: String) {
    code = SwiftLiteralLexer.blankingComments(in: Array(source.utf8))
  }

  /// The pattern of a label whose argument is a symbol name.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Returns: The pattern.
  static func symbolLabel() -> Regex<Substring> {
    #/\b(?:systemName|systemImage|systemSymbolName|symbolName):/#
  }

  /// The pattern of a declaration whose value or body holds symbol names.
  /// The first capture is the keyword.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  ///
  /// - Returns: The pattern.
  static func symbolDeclaration() -> Regex<(Substring, Substring)> {
    #/\b(let|var|func|enum|struct|class)\s+(?:\w*[Ss]ymbol\w*|systemImage|systemName)\b/#
  }

  /// The symbol names of the source, in source order.
  ///
  /// - Parameter file: The file name to write into each use.
  /// - Returns: The uses.
  func names(file: String) -> [SymbolNameUse] {
    let text = String(decoding: code, as: UTF8.self)
    let labelLiterals = text.matches(of: Self.symbolLabel()).flatMap { match in
      literals(from: offset(of: match.range.upperBound, in: text), endingAt: .argument)
    }
    let declarationLiterals = text.matches(of: Self.symbolDeclaration()).flatMap { match in
      let isValue = match.output.1 == "let" || match.output.1 == "var"
      return declarationLiterals(after: offset(of: match.range.upperBound, in: text), isValue: isValue)
    }
    let unique = Dictionary(
      (labelLiterals + declarationLiterals).map { ($0.start, $0) }, uniquingKeysWith: { first, _ in first })
    return unique.values.sorted { $0.start < $1.start }.compactMap { literal in
      literal.value.map { SymbolNameUse(file: file, line: line(of: literal.start), name: $0) }
    }
  }

  /// The UTF-8 offset of an index of the text of ``code``.
  ///
  /// - Parameters:
  ///   - index: The index.
  ///   - text: The text of ``code``.
  /// - Returns: The offset in ``code``.
  private func offset(of index: String.Index, in text: String) -> Int {
    text.utf8.distance(from: text.utf8.startIndex, to: index)
  }

  /// The line number of an offset in ``code``. The first line is line 1.
  ///
  /// - Parameter offset: The offset.
  /// - Returns: The line number.
  private func line(of offset: Int) -> Int {
    code[..<offset].count(where: { $0 == SwiftLiteralLexer.newline }) + 1
  }

  /// The literals in the value or the body of a declaration.
  ///
  /// The scan reads the head of the declaration after its name. A `{` at
  /// the top level starts the body. For a `let` or a `var`, a `=` at the top
  /// level starts the value, and a line break ends a head with no value.
  ///
  /// - Parameters:
  ///   - start: The offset after the name.
  ///   - isValue: `true` for a `let` or a `var`.
  /// - Returns: The literals, or none when the declaration has no value and
  ///   no body.
  private func declarationLiterals(after start: Int, isValue: Bool) -> [SwiftLiteralLexer.Literal] {
    var depth = 0
    var index = start
    while index < code.count {
      if let literal = SwiftLiteralLexer.literal(in: code, at: index) {
        index = literal.end
        continue
      }
      let byte = code[index]
      if depth == 0 {
        if byte == SwiftLiteralLexer.openBrace { return literals(from: index, endingAt: .block) }
        if isValue, byte == SwiftLiteralLexer.equals { return literals(from: index + 1, endingAt: .argument) }
        if isValue, byte == SwiftLiteralLexer.newline { return [] }
      }
      depth += SwiftLiteralLexer.depthChange(of: byte)
      index += 1
    }
    return []
  }

  /// The literals of one symbol context.
  ///
  /// - Parameters:
  ///   - start: The offset of the context. For ``RegionEnd/block`` this is
  ///     the offset of the `{`.
  ///   - end: Where the scan stops.
  /// - Returns: The literals, in source order.
  func literals(from start: Int, endingAt end: RegionEnd) -> [SwiftLiteralLexer.Literal] {
    var found: [SwiftLiteralLexer.Literal] = []
    var depth = 0
    var index = SwiftLiteralLexer.indexAfterWhitespace(in: code, from: start)
    while index < code.count {
      if let literal = SwiftLiteralLexer.literal(in: code, at: index) {
        found.append(literal)
        index = literal.end
        continue
      }
      let byte = code[index]
      let change = SwiftLiteralLexer.depthChange(of: byte)
      if change < 0, depth == 0 { return found }
      depth += change
      if end == .block, change < 0, depth == 0 { return found }
      if end == .argument, depth == 0, byte == SwiftLiteralLexer.comma || byte == SwiftLiteralLexer.newline {
        return found
      }
      index += 1
    }
    return found
  }

  /// Finds the symbol names in each Swift file below a directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each use is relative to.
  /// - Returns: The uses, in the order of the file paths, then in source
  ///   order.
  /// - Throws: An error when the directory or a file cannot be read, or
  ///   `PackageFiles.FileOutsideDirectory` when a file is not below `base`.
  static func names(inSwiftFilesBelow directory: URL, relativeTo base: URL) throws -> [SymbolNameUse] {
    try PackageFiles.swiftFileTexts(below: directory, relativeTo: base).flatMap { file in
      SymbolNameScanner(source: file.text).names(file: file.path)
    }
  }
}

/// Reads the string literals and the comments of Swift source bytes.
///
/// The lexer knows a single-line literal, a multi-line literal, a raw
/// literal with `#` delimiters, an escape and an interpolation. It does not
/// know nested block comments.
enum SwiftLiteralLexer {
  /// One string literal.
  struct Literal: Equatable {
    /// The offset of the first byte of the literal, the first `#` or `"`.
    let start: Int
    /// The offset after the last byte of the literal.
    let end: Int
    /// The text of a single-line literal with no escape and no
    /// interpolation, or `nil`.
    let value: String?
  }

  /// The byte of `"`.
  static let quote = UInt8(ascii: "\"")
  /// The byte of `#`.
  static let hash = UInt8(ascii: "#")
  /// The byte of `\`.
  static let backslash = UInt8(ascii: "\\")
  /// The byte of `/`.
  static let slash = UInt8(ascii: "/")
  /// The byte of `*`.
  static let star = UInt8(ascii: "*")
  /// The byte of `(`.
  static let openParenthesis = UInt8(ascii: "(")
  /// The byte of `)`.
  static let closeParenthesis = UInt8(ascii: ")")
  /// The byte of `{`.
  static let openBrace = UInt8(ascii: "{")
  /// The byte of `=`.
  static let equals = UInt8(ascii: "=")
  /// The byte of `,`.
  static let comma = UInt8(ascii: ",")
  /// The byte of a line break.
  static let newline = UInt8(ascii: "\n")
  /// The byte of a space.
  static let space = UInt8(ascii: " ")
  /// The number of quotes that open a multi-line literal.
  static let multiLineQuoteCount = 3
  /// The bytes that open a line comment: `//`.
  static let lineCommentOpener = [slash, slash]
  /// The bytes that open a block comment: `/*`.
  static let blockCommentOpener = [slash, star]
  /// The bytes that close a block comment: `*/`.
  static let blockCommentCloser = [star, slash]

  /// The bytes that open a bracket.
  static let openers: Set<UInt8> = [openParenthesis, UInt8(ascii: "["), openBrace]
  /// The bytes that close a bracket.
  static let closers: Set<UInt8> = [closeParenthesis, UInt8(ascii: "]"), UInt8(ascii: "}")]

  /// The change of the bracket depth at one byte.
  ///
  /// - Parameter byte: The byte.
  /// - Returns: `1` for an open bracket, `-1` for a close bracket, else `0`.
  static func depthChange(of byte: UInt8) -> Int {
    if openers.contains(byte) { return 1 }
    if closers.contains(byte) { return -1 }
    return 0
  }

  /// The offset of the first byte at or after an offset that is not a
  /// space, a tab or a line break.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset.
  /// - Returns: The offset, or the count of `bytes`.
  static func indexAfterWhitespace(in bytes: [UInt8], from start: Int) -> Int {
    bytes[start...].firstIndex { !Character(UnicodeScalar($0)).isWhitespace } ?? bytes.count
  }

  /// Tells if some bytes stand at an offset.
  ///
  /// - Parameters:
  ///   - pattern: The bytes to find.
  ///   - bytes: The source bytes.
  ///   - offset: The offset.
  /// - Returns: `true` when `bytes` holds `pattern` at `offset`.
  static func has(_ pattern: [UInt8], in bytes: [UInt8], at offset: Int) -> Bool {
    offset + pattern.count <= bytes.count && bytes[offset..<offset + pattern.count].elementsEqual(pattern)
  }

  /// Reads the string literal that starts at an offset.
  ///
  /// - Parameters:
  ///   - bytes: The source bytes.
  ///   - start: The offset.
  /// - Returns: The literal, or `nil` when no literal starts at `start`.
  static func literal(in bytes: [UInt8], at start: Int) -> Literal? {
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
    var hasEscape = false
    var index = contentStart
    while index < bytes.count {
      if has(escape, in: bytes, at: index) {
        hasEscape = true
        index = escapeEnd(in: bytes, after: index + escape.count)
      } else if has(closing, in: bytes, at: index) {
        let content = String(decoding: bytes[contentStart..<index], as: UTF8.self)
        return Literal(start: start, end: index + closing.count, value: hasEscape || !isSingleLine ? nil : content)
      } else if isSingleLine, bytes[index] == newline {
        return Literal(start: start, end: index, value: nil)
      } else {
        index += 1
      }
    }
    return Literal(start: start, end: bytes.count, value: nil)
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

  /// Changes each byte of each comment to a space. A line break in a comment
  /// stays, so the line numbers stay. The string literals stay.
  ///
  /// - Parameter bytes: The source bytes.
  /// - Returns: The bytes with the comments blanked.
  static func blankingComments(in bytes: [UInt8]) -> [UInt8] {
    var result = bytes
    var index = 0
    while index < bytes.count {
      if let literal = literal(in: bytes, at: index) {
        index = literal.end
      } else if let end = commentEnd(in: bytes, at: index) {
        for position in index..<end where result[position] != newline {
          result[position] = space
        }
        index = end
      } else {
        index += 1
      }
    }
    return result
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
