import Foundation
import PackageFileSupport

/// One line of a Swift source file.
struct SourceLine: Equatable {
  /// The file that holds the line, relative to the base of the scan.
  let file: String
  /// The line number. The first line is line 1.
  let number: Int
  /// The text of the line, without the line break.
  let text: Substring
}

/// Reads Swift source files as text, one line at a time.
///
/// The scanner gives each line to a match function, and collects the matches
/// that the function returns. The callers supply the match function, so one
/// traversal serves each check that reads source lines, for example
/// ``ImportScanner`` and ``RemovedVocabularyTests``.
enum SourceLineScanner {
  /// Finds the matches in each Swift file below a directory.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  ///   - match: The function that finds the matches on one line.
  /// - Returns: The matches, in the order of the file paths, then in line
  ///   order.
  /// - Throws: An error when the directory or a file cannot be read, or
  ///   `PackageFiles.FileOutsideDirectory` when a file is not below `base`.
  static func matches<Match>(
    inSwiftFilesBelow directory: URL,
    relativeTo base: URL,
    match: (SourceLine) -> [Match]
  ) throws -> [Match] {
    try PackageFiles.swiftFileTexts(below: directory, relativeTo: base).flatMap { file in
      matches(inSource: file.text, file: file.path, match: match)
    }
  }

  /// Finds the matches in the code of each Swift file below a directory.
  ///
  /// The scan blanks the comments and the string literals of each file
  /// before it reads the lines (``SwiftLiteralLexer``). Thus a match in a
  /// comment or in a string literal does not count. The line numbers stay.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  ///   - skipped: The files, relative to `base`, that the scan does not read.
  ///   - match: The function that finds the matches on one line.
  /// - Returns: The matches, in the order of the file paths, then in line
  ///   order.
  /// - Throws: The error of `PackageFiles.swiftFileTexts(below:relativeTo:)`.
  static func codeMatches<Match>(
    inSwiftFilesBelow directory: URL,
    relativeTo base: URL,
    skipping skipped: Set<String> = [],
    match: (SourceLine) -> [Match]
  ) throws -> [Match] {
    try codeTexts(inSwiftFilesBelow: directory, relativeTo: base, skipping: skipped).flatMap { file in
      matches(inSource: file.code, file: file.path, match: match)
    }
  }

  /// Finds the line where each match of a pattern starts, in the code of each
  /// Swift file below a directory.
  ///
  /// The scan blanks the comments and the string literals of each file, as
  /// ``codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)`` does. It
  /// then reads each file as one text, so a match can continue on the next
  /// lines, for example a call with one argument on each line.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each match is relative to.
  ///   - skipped: The files, relative to `base`, that the scan does not read.
  /// - Returns: `<file>:<line>` for each match, with the line where the match
  ///   starts, in the order of the file paths, then in line order.
  /// - Throws: The error of `PackageFiles.swiftFileTexts(below:relativeTo:)`.
  static func codeMatchStarts(
    of pattern: Regex<Substring>,
    inSwiftFilesBelow directory: URL,
    relativeTo base: URL,
    skipping skipped: Set<String> = []
  ) throws -> [String] {
    try codeTexts(inSwiftFilesBelow: directory, relativeTo: base, skipping: skipped).flatMap { file in
      matchStartLines(of: pattern, in: file.code).map { "\(file.path):\($0)" }
    }
  }

  /// Finds the line where each match of a pattern starts in a text.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find. A match can continue on the next
  ///     lines.
  ///   - text: The text, for example the code of one file.
  /// - Returns: The line number of the start of each match, in text order.
  ///   The first line is line 1.
  static func matchStartLines(of pattern: Regex<Substring>, in text: String) -> [Int] {
    text.matches(of: pattern).map { match in
      text[..<match.range.lowerBound].count { $0 == "\n" } + 1
    }
  }

  /// Gives the code of each Swift file below a directory, with each comment
  /// and each string literal blanked (``SwiftLiteralLexer``). The line
  /// numbers stay.
  ///
  /// - Parameters:
  ///   - directory: The directory to read. The read includes subdirectories.
  ///   - base: The directory that the path of each file is relative to.
  ///   - skipped: The files, relative to `base`, that the read skips.
  /// - Returns: The path and the code of each file, in the order of the file
  ///   paths.
  /// - Throws: The error of `PackageFiles.swiftFileTexts(below:relativeTo:)`.
  static func codeTexts(
    inSwiftFilesBelow directory: URL,
    relativeTo base: URL,
    skipping skipped: Set<String>
  ) throws -> [(path: String, code: String)] {
    try PackageFiles.swiftFileTexts(below: directory, relativeTo: base)
      .filter { !skipped.contains($0.path) }
      .map { file in
        let code = SwiftLiteralLexer.blankingCommentsAndLiterals(in: Array(file.text.utf8))
        return (path: file.path, code: String(decoding: code, as: UTF8.self))
      }
  }

  /// Finds a use of a pattern on one line, as `<file>:<line>`.
  ///
  /// Each line scan that reports the lines that hold a pattern calls this
  /// function from its match function, so that one place states the match
  /// and the form of a use.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - line: The line.
  /// - Returns: `<file>:<line>` when the line holds `pattern`, or no result.
  static func uses(of pattern: some RegexComponent, on line: SourceLine) -> [String] {
    line.text.contains(pattern) ? ["\(line.file):\(line.number)"] : []
  }

  /// Finds the matches in the text of one Swift file.
  ///
  /// - Parameters:
  ///   - source: The text of the file.
  ///   - file: The file name to write into each line.
  ///   - match: The function that finds the matches on one line.
  /// - Returns: The matches, in line order, and in the order that `match`
  ///   returns them on one line.
  static func matches<Match>(
    inSource source: String,
    file: String,
    match: (SourceLine) -> [Match]
  ) -> [Match] {
    source.split(separator: "\n", omittingEmptySubsequences: false)
      .enumerated()
      .flatMap { offset, text in
        match(SourceLine(file: file, number: offset + 1, text: text))
      }
  }
}
