import CoreGraphics
import EditorStyle
import PackageFileSupport
import SwiftUI
import Testing

/// Checks that the R12 token table in `Docs/decisions/visual-audit.md` and
/// `EditorStyle.default` agree.
///
/// The kit reads its layout tokens from the shared style of the EditorKit
/// `EditorStyle` target (`\.editorStyle`). The R12 audit of the kit chose the
/// default values, and EditorKit took them. The table records the audit, so
/// it must name the values that the kit shows with the default style.
@Suite struct StyleTokenGoldenTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/visual-audit.md"

  /// The header row of the token table.
  private static let header = "| token | default | Xcode 27 | Claude Desktop |"

  /// The number of cells in one row of the token table.
  private static let columnCount = 4

  /// One parsed row of the token table.
  private struct Row {
    /// The token name, such as `spacing.xs`, without backticks.
    let token: String
    /// The default value of the token, without backticks.
    let value: String
  }

  /// The errors that the row parser can report.
  private enum TableError: Error {
    /// A row does not have ``StyleTokenGoldenTests/columnCount`` cells.
    case wrongCellCount([String])
    /// A point cell is not a number.
    case notANumber(String)
  }

  /// A comparison of one table value with the token of a style.
  ///
  /// The comparison returns `true` when the value equals the token.
  private typealias Check = (EditorStyle, String) throws -> Bool

  /// A comparison for a point value, such as a spacing step.
  ///
  /// - Parameter token: Gives the token of a style.
  /// - Returns: The comparison.
  private static func point(_ token: @escaping (EditorStyle) -> CGFloat) -> Check {
    { style, cell in
      guard let value = Double(cell) else { throw TableError.notANumber(cell) }
      return token(style) == CGFloat(value)
    }
  }

  /// A comparison for a value that has a raw name, such as a density.
  ///
  /// - Parameter token: Gives the raw name of the token of a style.
  /// - Returns: The comparison.
  private static func name(_ token: @escaping (EditorStyle) -> String) -> Check {
    { style, cell in token(style) == cell }
  }

  /// The comparison for each token that the table must name. The window
  /// corner of the scale is not in the R12 audit, so the table has no row
  /// for it.
  private static let checks: [String: Check] = [
    "spacing.xs": point { $0.spacing.xs },
    "spacing.s": point { $0.spacing.s },
    "spacing.m": point { $0.spacing.m },
    "spacing.l": point { $0.spacing.l },
    "radii.s": point { $0.radii.s },
    "radii.m": point { $0.radii.m },
    "radii.l": point { $0.radii.l },
    "symbolWeight": { style, cell in style.symbolWeight == (try ThemeTokenNames.weight(named: cell)) },
    "density": name { $0.density.rawValue },
  ]

  /// Parses the rows of the token table.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: ``MarkdownTable/MissingTable`` when the file has no token
  ///   table, or ``TableError`` when a row is not in the expected form.
  private static func tableRows() throws -> [Row] {
    let text = try PackageFiles.text(of: decisionPath)
    return try MarkdownTable.rows(in: text, header: header).map { cells in
      guard cells.count == columnCount else {
        throw TableError.wrongCellCount(cells)
      }
      return Row(token: cells[0], value: cells[1])
    }
  }

  /// The tokens of the table rows whose value is not equal to the token of
  /// `style`.
  ///
  /// - Parameters:
  ///   - rows: The table rows.
  ///   - style: The style to compare.
  /// - Returns: The token names that do not match, in file order.
  /// - Throws: ``TableError`` when a cell is not in the expected form.
  private static func mismatches(in rows: [Row], for style: EditorStyle) throws -> [String] {
    try rows.filter { row in
      guard let check = checks[row.token] else { return true }
      return try !check(style, row.value)
    }
    .map(\.token)
  }

  @Test func tableHasOneRowForEachToken() throws {
    let tokens = try Self.tableRows().map(\.token)
    NameChecks.expectDistinctNames(tokens)
    #expect(Set(tokens) == Set(Self.checks.keys))
  }

  @Test func everyTokenEqualsTheDefault() throws {
    let rows = try Self.tableRows()
    #expect(try Self.mismatches(in: rows, for: .default) == [])
  }

  @Test func aChangedTokenDoesNotMatchTheTable() throws {
    let rows = try Self.tableRows()
    var style = EditorStyle.default
    style.spacing.l += 1
    style.density = .detailed
    #expect(try Self.mismatches(in: rows, for: style) == ["spacing.l", "density"])
  }
}
