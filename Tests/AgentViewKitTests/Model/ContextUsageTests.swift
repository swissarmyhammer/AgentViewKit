import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

@Suite struct ContextUsageTests {
  // MARK: - Fields

  @Test func theStoredPropertiesAreTheFieldsOfAUsageUpdate() {
    #expect(Self.storedProperties == ["used", "size", "cost"])
  }

  @Test func theValuesOfAUsageUpdateStayInTheUsage() {
    let usage = ContextUsage(
      used: 1_200, size: 200_000, cost: ContextUsage.Cost(amount: 0.25, currency: "USD"))

    #expect(usage.used == 1_200)
    #expect(usage.size == 200_000)
    #expect(usage.cost == ContextUsage.Cost(amount: 0.25, currency: "USD"))
    #expect(ContextUsage(used: 1, size: 2).cost == nil)
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
  /// - Throws: The read error, or ``MarkdownTable/MissingTable`` when the
  ///   file has no merge table.
  private static func mergeTableRows() throws -> [MergeTableRow] {
    let text = try PackageFiles.text(of: decisionPath)
    return try MarkdownTable.rows(in: text, header: tableHeader).map { cells in
      MergeTableRow(source: cells.first ?? "", target: cells.dropFirst().first ?? "")
    }
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

/// One row of the merge table of the usage decision file.
private struct MergeTableRow {
  /// The first cell, without the backticks.
  let source: String
  /// The second cell, without the backticks.
  let target: String
}
