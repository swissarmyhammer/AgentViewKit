import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct ConnectionsViewHostedTests {
  static let githubID = ConnectionID("github")
  static let linearID = ConnectionID("linear")
  static let searchID = ToolToggleID("search")
  static let issueID = ToolToggleID("create_issue")

  /// A store with two connections and three tools.
  static func twoConnections(actions: (any ConnectionActions)? = nil) -> ConnectionStore {
    ConnectionStore(
      connections: [
        Connection(
          id: githubID,
          name: "GitHub",
          state: .connected,
          tools: [
            ToolToggle(id: searchID, name: "Search code", isEnabled: true),
            ToolToggle(id: issueID, name: "Create issue", isEnabled: false),
          ]
        ),
        Connection(
          id: linearID,
          name: "Linear",
          state: .needsAuth,
          tools: [ToolToggle(id: searchID, name: "Search issues", isEnabled: true)]
        ),
      ],
      actions: actions
    )
  }

  /// The size of a list that shows each row.
  static let listSize = CGSize(width: 480, height: 640)

  // MARK: - Chip

  @Test func eachStateMountsAChipWithADistinctIdentifierAndLabel() {
    var identifiers: Set<String> = []
    var labels: Set<String> = []
    for kind in ConnectionState.Kind.allCases {
      let state = ConnectionState.sample(kind)
      let harness = HostedViewHarness(ConnectionStatusChip(state: state))
      defer { harness.close() }
      harness.pump()

      let identifier = ConnectionStatusChip.identifier(for: kind)
      let element = harness.element(identifier: identifier)
      #expect(identifier == "connection-chip-\(kind.rawValue)")
      #expect(element?.label == kind.label)
      identifiers.insert(identifier)
      labels.insert(element?.label ?? "")
    }

    #expect(identifiers.count == 6)
    #expect(labels.count == 6)
  }

  @Test func theErrorChipGivesTheMessageAsItsValue() {
    let harness = HostedViewHarness(ConnectionStatusChip(state: .error("Server unreachable")))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: ConnectionStatusChip.identifier(for: .error))
    #expect(element?.value == "Server unreachable")
  }

  // MARK: - List

  @Test func twoConnectionsMountTwoRowsAndThreeToolToggles() {
    let store = Self.twoConnections()
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(store), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    let rows = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(ConnectionRow.identifierPrefix) == true
    }
    let toggles = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(ConnectionRow.toolIdentifierPrefix) == true
    }
    #expect(Set(rows.compactMap(\.identifier)) == [
      ConnectionRow.identifier(for: Self.githubID),
      ConnectionRow.identifier(for: Self.linearID),
    ])
    #expect(Set(toggles.compactMap(\.identifier)).count == 3)
    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .connected)) != nil)
    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) != nil)
  }

  @Test func aTogglePressCallsSetToolEnabled() throws {
    let store = Self.twoConnections()
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(store), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(
      identifier: ConnectionRow.toolIdentifier(for: Self.githubID, tool: Self.issueID))

    #expect(store.connection(Self.githubID)?.tools.map(\.isEnabled) == [true, true])
    #expect(store.connection(Self.linearID)?.tools.map(\.isEnabled) == [true])
  }

  @Test func theToggleHasTheToolNameAsItsLabel() {
    let store = Self.twoConnections()
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(store), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(
      identifier: ConnectionRow.toolIdentifier(for: Self.linearID, tool: Self.searchID))
    #expect(element?.label == "Search issues")
  }

  @Test func connectAndDisconnectButtonsCallTheActions() async throws {
    let actions = RecordingConnectionActions()
    let store = Self.twoConnections(actions: actions)
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(store), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionRow.connectIdentifier(for: Self.githubID)) == nil)
    #expect(
      harness.element(identifier: ConnectionRow.disconnectIdentifier(for: Self.linearID)) == nil)
    try harness.press(identifier: ConnectionRow.disconnectIdentifier(for: Self.githubID))
    try harness.press(identifier: ConnectionRow.connectIdentifier(for: Self.linearID))
    await waitForCalls(actions, count: 2, harness: harness)

    #expect(actions.calls == [.disconnect(Self.githubID), .connect(Self.linearID)])
  }

  @Test func aStateChangeUpdatesTheRow() {
    let store = Self.twoConnections()
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(store), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    store.transition(Self.linearID, to: .authenticating)
    harness.pump()

    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .authenticating)) != nil)
    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) == nil)
  }

  @Test func aViewWithNoStoreShowsTheEmptyState() {
    let harness = HostedViewHarness(ConnectionsView(), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionsView.emptyIdentifier) != nil)
  }

  @Test func aStoreWithNoConnectionsShowsTheEmptyState() {
    let harness = HostedViewHarness(
      ConnectionsView().connectionStore(ConnectionStore()), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionsView.emptyIdentifier) != nil)
  }

  /// Pumps the run loop until `actions` has `count` calls, for at most one
  /// second.
  private func waitForCalls(
    _ actions: RecordingConnectionActions,
    count: Int,
    harness: HostedViewHarness<some View>
  ) async {
    let deadline = Date(timeIntervalSinceNow: 1)
    while actions.calls.count < count, Date() < deadline {
      harness.pump()
      await Task.yield()
    }
  }
}
