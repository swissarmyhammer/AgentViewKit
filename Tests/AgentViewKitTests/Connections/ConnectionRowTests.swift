import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Checks the accessibility identifiers of the status of an MCP server, with
/// no view.
@Suite struct ConnectionRowTests {
  /// Each status of an MCP server, with no reason for the failed status.
  nonisolated static let statuses: [MCPServerStatus] = [
    .notReported, .connecting, .connected, .failed(reason: nil), .closed,
  ]

  @Test func eachServerStatusHasADistinctIdentifier() {
    #expect(Set(Self.statuses.map(ConnectionRow.statusIdentifier(for:))).count == Self.statuses.count)
  }

  @Test(arguments: statuses)
  func eachStatusIdentifierStartsWithThePrefix(status: MCPServerStatus) {
    #expect(ConnectionRow.statusIdentifier(for: status).hasPrefix(ConnectionRow.statusIdentifierPrefix))
  }

  @Test func theReasonOfAFailedServerIsNotInItsIdentifier() {
    #expect(
      ConnectionRow.statusIdentifier(for: .failed(reason: "The command was not found."))
        == ConnectionRow.statusIdentifier(for: .failed(reason: nil)))
  }
}
