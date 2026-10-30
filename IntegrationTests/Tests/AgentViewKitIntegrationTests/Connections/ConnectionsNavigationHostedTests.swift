import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The selection of ``ConnectionsView``, which comes from the command scopes
/// of its rows and the `nav.*` commands of EditorKit, and not from a native
/// list.
///
/// The test shows the MCP servers of a scripted session in a window with a
/// command system that the test holds, so that it can read the geometry of
/// the rows. A key goes to the window, as a typed key does, and the list
/// routes it to the registry at the focused scope.
@Suite(.serialized, .hostedSerially) @MainActor struct ConnectionsNavigationHostedTests {
  /// Shows a ``ConnectionsView`` over the session model in a window with
  /// `system`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  /// - Returns: The harness.
  static func mount(session: ScriptedSession, system: CommandSystem) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: ConnectionsViewHostedTests.listSize) {
      ConnectionsView()
        .environment(\.sessionModel, session.model)
        .commandSystem(system)
    }
    harness.render()
    return harness
  }

  /// The paths of the scopes of the rows of the two servers, in list order.
  ///
  /// - Parameter model: The session model of the list.
  /// - Returns: The row paths, at the root of the window.
  static func rowPaths(of model: SessionModel) -> [FocusPath] {
    let scope = ConnectionsView.scope(for: model)
    return [MCPServersHostedTests.webName, MCPServersHostedTests.filesName].map {
      FocusPath.root(scope.list).appending(scope.rowSegment(for: $0))
    }
  }

  @Test func theDownArrowSelectsTheNextServerAndTheUpArrowTheServerBefore() async throws {
    let session = try await MCPServersHostedTests.openSessionWithTwoServers()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    let rows = Self.rowPaths(of: session.model)
    try #require(system.geometry.requestFocus(at: rows[0]))
    harness.render()
    try #require(SessionListNavigationHostedTests.selectedRow(among: rows, in: system, harness: harness) == rows[0])

    try harness.sendKey(.downArrow)
    #expect(SessionListNavigationHostedTests.selectedRow(among: rows, in: system, harness: harness) == rows[1])

    try harness.sendKey(.upArrow)
    #expect(SessionListNavigationHostedTests.selectedRow(among: rows, in: system, harness: harness) == rows[0])
  }
}
