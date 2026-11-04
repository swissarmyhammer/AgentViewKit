import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The empty state of ``ConnectionsView``.
///
/// ``MCPServersHostedTests`` shows the rows of the servers of a session
/// model.
@Suite(.serialized, .hostedSerially) @MainActor struct ConnectionsViewHostedTests {
  /// The size of a list that shows each row.
  static let listSize = CGSize(width: 480, height: 640)

  // MARK: - Empty state

  @Test func aViewWithNoSessionModelShowsTheEmptyState() {
    let harness = HostedViewHarness(ConnectionsView(), size: Self.listSize)
    defer { harness.close() }
    harness.render()

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
