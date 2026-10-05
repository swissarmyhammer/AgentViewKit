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
  /// - Returns: The matches, in file order, then in line order.
  /// - Throws: An error when the directory or a file cannot be read.
  static func matches<Match>(
    inSwiftFilesBelow directory: URL,
    relativeTo base: URL,
    match: (SourceLine) -> [Match]
  ) throws -> [Match] {
    let baseDepth = base.standardizedFileURL.pathComponents.count
    return try PackageFiles.swiftFiles(in: directory).flatMap { url in
      let relative = url.standardizedFileURL.pathComponents.dropFirst(baseDepth).joined(separator: "/")
      let text = try String(contentsOf: url, encoding: .utf8)
      return matches(inSource: text, file: relative, match: match)
    }
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
