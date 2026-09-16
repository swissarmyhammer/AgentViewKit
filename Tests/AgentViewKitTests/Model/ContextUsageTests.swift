import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

@Suite struct ContextUsageTests {
  // MARK: - Fraction

  @Test func fractionIsUsedDividedBySize() {
    let usage = ContextUsage(used: 250, size: 1_000)

    #expect(usage.fraction == 0.25)
  }

  @Test func fractionClampsToOne() {
    let usage = ContextUsage(used: 1_500, size: 1_000)

    #expect(usage.fraction == 1)
  }

  @Test func fractionClampsToZero() {
    let usage = ContextUsage(used: -10, size: 1_000)

    #expect(usage.fraction == 0)
  }

  @Test func zeroSizeGivesZero() {
    #expect(ContextUsage(used: 0, size: 0).fraction == 0)
    #expect(ContextUsage(used: 10, size: 0).fraction == 0)
  }

  @Test func theOptionalPartsDefaultToNil() {
    let usage = ContextUsage(used: 1, size: 2)

    #expect(usage.cost == nil)
    #expect(usage.input == nil)
    #expect(usage.output == nil)
    #expect(usage.quota == nil)
  }

  @Test func theOptionalPartsKeepTheirValues() {
    let usage = ContextUsage(
      used: 1,
      size: 2,
      cost: .init(amount: 0.5, currency: "USD"),
      input: .init(total: 10, cached: 4),
      output: .init(total: 7, reasoning: 3),
      quota: .belowLimit(approaching: true)
    )

    #expect(usage.cost == ContextUsage.Cost(amount: 0.5, currency: "USD"))
    #expect(usage.input == ContextUsage.Input(total: 10, cached: 4))
    #expect(usage.output == ContextUsage.Output(total: 7, reasoning: 3))
    #expect(usage.quota == .belowLimit(approaching: true))
    #expect(usage.quota != .limitReached)
  }

  // MARK: - Decision table

  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/usage-model.md"

  /// The header row of the merge table.
  private static let tableHeader = "| source field | ContextUsage field | note |"

  /// The stored property names of `ContextUsage`, in declaration order.
  private static let storedProperties: [String] =
    Mirror(reflecting: ContextUsage(used: 0, size: 0)).children.compactMap(\.label)

  /// The body rows of the merge table in the decision file.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: The read error, or ``UsageDecisionTable/MissingTable`` when the
  ///   file has no merge table.
  private static func mergeTableRows() throws -> [UsageDecisionTable.Row] {
    let text = try PackageFiles.text(of: decisionPath)
    return try UsageDecisionTable.rows(in: text, header: tableHeader)
  }

  @Test func everyTableRowNamesAStoredPropertyOfContextUsage() throws {
    let rows = try Self.mergeTableRows()
    let storedProperties = Set(Self.storedProperties)

    #expect(!rows.isEmpty, "The merge table has no rows.")
    for row in rows {
      #expect(
        storedProperties.contains(row.target),
        "`\(row.target)` in the row for \(row.source) is not a stored property of ContextUsage."
      )
    }
  }

  @Test func everyStoredPropertyOfContextUsageHasATableRow() throws {
    let targets = Set(try Self.mergeTableRows().map(\.target))

    for property in Self.storedProperties {
      #expect(targets.contains(property), "No row of the merge table fills `\(property)`.")
    }
  }
}

/// Parses the merge table of the usage decision file.
private enum UsageDecisionTable {
  /// One row of the merge table.
  struct Row {
    /// The first cell, without the backticks.
    let source: String
    /// The second cell, without the backticks.
    let target: String
  }

  /// The error when the file has no merge table.
  struct MissingTable: Error {}

  /// The number of cells in a row of the merge table.
  private static let cellCount = 3

  /// The number of lines from the header row to the first body row: the
  /// header row and the separator row.
  private static let linesBeforeBody = 2

  /// The body rows of the table that starts with `header`.
  ///
  /// The rows start after the separator row and stop at the first line that
  /// is not a table row.
  ///
  /// - Parameters:
  ///   - text: The Markdown text.
  ///   - header: The exact header row.
  /// - Returns: The rows, in file order.
  /// - Throws: ``MissingTable`` when the text has no line equal to `header`.
  static func rows(in text: String, header: String) throws -> [Row] {
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
      .map { $0.trimmingCharacters(in: .whitespaces) }
    guard let headerIndex = lines.firstIndex(of: header) else { throw MissingTable() }
    let bodyStart = headerIndex + linesBeforeBody
    guard bodyStart <= lines.count else { return [] }
    return lines[bodyStart...]
      .prefix { $0.hasPrefix("|") }
      .map { line in
        let cells = line.split(separator: "|", omittingEmptySubsequences: false)
          .dropFirst()
          .prefix(cellCount)
          .map { $0.trimmingCharacters(in: CharacterSet.whitespaces.union(["`"])) }
        return Row(source: cells.first ?? "", target: cells.dropFirst().first ?? "")
      }
  }
}
