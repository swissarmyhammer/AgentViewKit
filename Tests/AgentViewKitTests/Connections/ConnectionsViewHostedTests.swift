import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The status chip and the empty state of ``ConnectionsView``.
///
/// ``MCPServersHostedTests`` shows the rows of the servers of a session
/// model.
@Suite(.serialized, .hostedSerially) @MainActor struct ConnectionsViewHostedTests {
  /// The size of a list that shows each row.
  static let listSize = CGSize(width: 480, height: 640)

  /// Each status of an MCP server, with no reason for the failed status.
  static let statuses: [MCPServerStatus] = [
    .notReported, .connecting, .connected, .failed(reason: nil), .closed,
  ]

  // MARK: - Chip

  @Test func eachStatusMountsAChipWithADistinctIdentifierAndLabel() {
    var identifiers: Set<String> = []
    var labels: Set<String> = []
    for status in Self.statuses {
      let harness = HostedViewHarness(ConnectionStatusChip(status: status))
      defer { harness.close() }
      harness.pump()

      let identifier = ConnectionStatusChip.identifier(for: status)
      let element = harness.element(identifier: identifier)
      #expect(identifier.hasPrefix(ConnectionStatusChip.identifierPrefix))
      #expect(element != nil, "No chip has the identifier \(identifier).")
      identifiers.insert(identifier)
      labels.insert(element?.label ?? "")
    }

    #expect(identifiers.count == Self.statuses.count)
    #expect(labels.count == Self.statuses.count)
  }

  @Test func aFailedChipWithNoReasonHasNoValue() {
    let harness = HostedViewHarness(ConnectionStatusChip(status: .failed(reason: nil)))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: ConnectionStatusChip.identifier(for: .failed(reason: nil)))
    #expect(element?.label == "Failed")
    #expect(element?.value?.isEmpty ?? true)
  }

  // MARK: - Empty state

  @Test func aViewWithNoSessionModelShowsTheEmptyState() {
    let harness = HostedViewHarness(ConnectionsView(), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionsView.emptyIdentifier) != nil)
  }

  @Test func aSessionWithNoServersShowsTheEmptyState() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = MCPServersHostedTests.mount(session: session)
    defer { harness.close() }

    #expect(session.model.mcpServers.isEmpty)
    #expect(harness.element(identifier: ConnectionsView.emptyIdentifier) != nil)
  }
}
