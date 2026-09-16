import Foundation

/// Reads the body rows of one Markdown table in a decision file.
///
/// The decision tests use this parser to compare a table in `Docs/decisions/`
/// with the code. Each test maps the cells of a row to its own row type.
enum MarkdownTable {
  /// The error when the text has no line equal to the header row.
  struct MissingTable: Error {}

  /// The number of lines from the header row to the first body row: the
  /// header row and the separator row.
  private static let linesBeforeBody = 2

  /// The body rows of the table that starts with `header`, as cell values.
  ///
  /// The rows start after the separator row and stop at the first line that
  /// is not a table row. Each cell value has no surrounding white space and
  /// no surrounding backticks.
  ///
  /// - Parameters:
  ///   - text: The Markdown text.
  ///   - header: The exact header row.
  /// - Returns: The cells of each row, in file order.
  /// - Throws: ``MissingTable`` when the text has no line equal to `header`.
  static func rows(in text: String, header: String) throws -> [[String]] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    guard let headerIndex = lines.firstIndex(of: header) else { throw MissingTable() }
    let bodyStart = headerIndex + linesBeforeBody
    guard bodyStart <= lines.count else { return [] }
    return lines[bodyStart...]
      .prefix { $0.hasPrefix("|") }
      .map(cells(of:))
  }

  /// Gives the cell values of one table row.
  ///
  /// - Parameter row: A line that starts with `|`.
  /// - Returns: The cell values. The empty text before the first `|` and
  ///   after the last `|` is not a cell.
  private static func cells(of row: String) -> [String] {
    var parts = row.split(separator: "|", omittingEmptySubsequences: false).dropFirst()
    if row.hasSuffix("|") {
      parts = parts.dropLast()
    }
    return parts.map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(["`"])) }
  }
}
