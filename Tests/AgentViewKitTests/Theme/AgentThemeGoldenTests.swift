import AgentViewKit
import CoreGraphics
import PackageFileSupport
import SwiftUI
import Testing

/// Checks that the R12 token table in `Docs/decisions/visual-audit.md` and
/// ``AgentTheme/default`` agree.
@Suite struct AgentThemeGoldenTests {
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
    /// A row does not have ``AgentThemeGoldenTests/columnCount`` cells.
    case wrongCellCount([String])
    /// A point cell is not a number.
    case notANumber(String)
  }

  /// A comparison of one table value with the token of a theme.
  ///
  /// The comparison returns `true` when the value equals the token.
  private typealias Check = (AgentTheme, String) throws -> Bool

  /// A comparison for a point value, such as a spacing step.
  ///
  /// - Parameter token: Gives the token of a theme.
  /// - Returns: The comparison.
  private static func point(_ token: @escaping (AgentTheme) -> CGFloat) -> Check {
    { theme, cell in
      guard let value = Double(cell) else { throw TableError.notANumber(cell) }
      return token(theme) == CGFloat(value)
    }
  }

  /// A comparison for a value that has a raw name, such as a density.
  ///
  /// - Parameter token: Gives the raw name of the token of a theme.
  /// - Returns: The comparison.
  private static func name(_ token: @escaping (AgentTheme) -> String) -> Check {
    { theme, cell in token(theme) == cell }
  }

  /// The comparison for each token that the table must name.
  private static let checks: [String: Check] = [
    "spacing.xs": point { $0.spacing.xs },
    "spacing.s": point { $0.spacing.s },
    "spacing.m": point { $0.spacing.m },
    "spacing.l": point { $0.spacing.l },
    "radii.s": point { $0.radii.s },
    "radii.m": point { $0.radii.m },
    "radii.l": point { $0.radii.l },
    "symbolWeight": { theme, cell in theme.symbolWeight == (try ThemeTokenNames.weight(named: cell)) },
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
  /// `theme`.
  ///
  /// - Parameters:
  ///   - rows: The table rows.
  ///   - theme: The theme to compare.
  /// - Returns: The token names that do not match, in file order.
  /// - Throws: ``TableError`` when a cell is not in the expected form.
  private static func mismatches(in rows: [Row], for theme: AgentTheme) throws -> [String] {
    try rows.filter { row in
      guard let check = checks[row.token] else { return true }
      return try !check(theme, row.value)
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
    var theme = AgentTheme.default
    theme.spacing.l += 1
    theme.density = .detailed
    #expect(try Self.mismatches(in: rows, for: theme) == ["spacing.l", "density"])
  }
}
