import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

/// Checks that the R13 table in `Docs/decisions/checkpoints.md` and the
/// `CheckpointCapabilities` values agree.
@Suite struct CheckpointCapabilitiesTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/checkpoints.md"

  /// The header row of the capability table.
  private static let header =
    "| source | restores code | restores conversation | granularity | wire call |"

  /// The number of cells in one row of the capability table.
  private static let columnCount = 5

  /// One parsed row of the capability table.
  private struct Row: Equatable {
    /// The source name, without backticks.
    let source: String
    /// The value of the `restores code` cell.
    let restoresCode: Bool
    /// The value of the `restores conversation` cell.
    let restoresConversation: Bool
    /// The granularity name, without backticks.
    let granularity: String
    /// The wire call, without backticks.
    let wireCall: String
  }

  /// The errors that the table parser can report.
  private enum TableError: Error {
    /// The file has no capability table header.
    case missingHeader
    /// A row does not have ``CheckpointCapabilitiesTests/columnCount`` cells.
    case wrongCellCount(String)
    /// A yes-or-no cell has a different value.
    case notYesOrNo(String)
  }

  /// Removes the surrounding spaces and backticks from one cell.
  ///
  /// - Parameter cell: The raw cell text.
  /// - Returns: The cell value.
  private static func value(of cell: Substring) -> String {
    cell.trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
  }

  /// Reads a `yes` or `no` cell.
  ///
  /// - Parameter cell: The cell value.
  /// - Returns: `true` for `yes`, `false` for `no`.
  /// - Throws: ``TableError/notYesOrNo(_:)`` for a different value.
  private static func flag(_ cell: String) throws -> Bool {
    switch cell {
    case "yes": return true
    case "no": return false
    default: throw TableError.notYesOrNo(cell)
    }
  }

  /// Parses the rows of the capability table.
  ///
  /// - Returns: The rows, in file order.
  /// - Throws: ``TableError`` when the table is not in the expected form.
  private static func tableRows() throws -> [Row] {
    let text = try PackageFiles.text(of: decisionPath)
    let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
    guard let headerIndex = lines.firstIndex(where: { $0 == header }) else {
      throw TableError.missingHeader
    }
    // The line after the header is the separator row.
    let body = lines[(headerIndex + 2)...].prefix { $0.hasPrefix("|") }
    return try body.map { line in
      let cells = line.split(separator: "|").map(value(of:))
      guard cells.count == columnCount else {
        throw TableError.wrongCellCount(String(line))
      }
      return Row(
        source: cells[0],
        restoresCode: try flag(cells[1]),
        restoresConversation: try flag(cells[2]),
        granularity: cells[3],
        wireCall: cells[4]
      )
    }
  }

  @Test func tableHasOneRowForEachSource() throws {
    let rows = try Self.tableRows()
    #expect(
      rows.map(\.source).sorted()
        == CheckpointCapabilities.Source.allCases.map(\.rawValue).sorted())
  }

  @Test func routerMatchesItsRow() throws {
    let rows = try Self.tableRows()
    let row = try #require(rows.first { $0.source == "router" })
    #expect(row == Self.row(for: .router))
  }

  @Test func acpMatchesItsRow() throws {
    let rows = try Self.tableRows()
    let row = try #require(rows.first { $0.source == "acp" })
    #expect(row == Self.row(for: .acp))
  }

  @Test func allHasOneValuePerSource() {
    #expect(CheckpointCapabilities.all.map(\.source) == CheckpointCapabilities.Source.allCases)
    for source in CheckpointCapabilities.Source.allCases {
      #expect(CheckpointCapabilities.capabilities(for: source).source == source)
    }
  }

  @Test func noV1SourceRestoresCode() {
    #expect(CheckpointCapabilities.all.allSatisfy { !$0.restoresCode })
  }

  @Test func anUnavailableSourceRestoresNothing() {
    for capabilities in CheckpointCapabilities.all where capabilities.granularity == .unavailable {
      #expect(!capabilities.restoresCode)
      #expect(!capabilities.restoresConversation)
    }
  }

  /// Makes the table row that a capability value states.
  ///
  /// - Parameter capabilities: The capability value.
  /// - Returns: The row, in the parsed form.
  private static func row(for capabilities: CheckpointCapabilities) -> Row {
    Row(
      source: capabilities.source.rawValue,
      restoresCode: capabilities.restoresCode,
      restoresConversation: capabilities.restoresConversation,
      granularity: capabilities.granularity.rawValue,
      wireCall: capabilities.wireCall
    )
  }
}
