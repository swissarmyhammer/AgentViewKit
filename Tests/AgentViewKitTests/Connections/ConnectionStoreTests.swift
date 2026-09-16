import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

@Suite @MainActor struct ConnectionStoreTests {
  static let serverID = ConnectionID("github")
  static let otherID = ConnectionID("linear")
  static let searchID = ToolToggleID("search")
  static let issueID = ToolToggleID("create_issue")

  /// The decision that records the edge table.
  static let decisionPath = "Docs/decisions/connection-states.md"

  /// A store with one connection in `state`, with two tools.
  static func store(
    state: ConnectionState,
    actions: (any ConnectionActions)? = nil
  ) -> ConnectionStore {
    ConnectionStore(
      connections: [
        Connection(
          id: serverID,
          name: "GitHub",
          state: state,
          tools: [
            ToolToggle(id: searchID, name: "Search", isEnabled: true),
            ToolToggle(id: issueID, name: "Create issue", isEnabled: false),
          ]
        ),
        Connection(
          id: otherID,
          name: "Linear",
          state: .disconnected,
          tools: [ToolToggle(id: searchID, name: "Search", isEnabled: true)]
        ),
      ],
      actions: actions
    )
  }

  /// Each edge that §12 of plan.md allows, as a pair of state kinds.
  static let allowedEdges: Set<Edge> = [
    Edge(.disconnected, .connected),
    Edge(.disconnected, .needsAuth),
    Edge(.disconnected, .error),
    Edge(.connected, .needsAuth),
    Edge(.connected, .expired),
    Edge(.connected, .error),
    Edge(.connected, .disconnected),
    Edge(.needsAuth, .authenticating),
    Edge(.needsAuth, .error),
    Edge(.needsAuth, .disconnected),
    Edge(.authenticating, .connected),
    Edge(.authenticating, .needsAuth),
    Edge(.authenticating, .error),
    Edge(.authenticating, .disconnected),
    Edge(.expired, .authenticating),
    Edge(.expired, .needsAuth),
    Edge(.expired, .error),
    Edge(.expired, .disconnected),
    Edge(.error, .connected),
    Edge(.error, .needsAuth),
    Edge(.error, .error),
    Edge(.error, .disconnected),
  ]

  /// A pair of state kinds.
  nonisolated struct Edge: Hashable, Sendable, CustomTestStringConvertible {
    let from: ConnectionState.Kind
    let to: ConnectionState.Kind

    init(_ from: ConnectionState.Kind, _ to: ConnectionState.Kind) {
      self.from = from
      self.to = to
    }

    var testDescription: String { "\(from.rawValue) -> \(to.rawValue)" }
  }

  /// Each pair of state kinds.
  nonisolated static let everyEdge: [Edge] = ConnectionState.Kind.allCases.flatMap { from in
    ConnectionState.Kind.allCases.map { to in Edge(from, to) }
  }

  // MARK: - Edge table

  @Test func connectedToNeedsAuthSucceeds() {
    let store = Self.store(state: .connected)

    let moved = store.transition(Self.serverID, to: .needsAuth)

    #expect(moved)
    #expect(store.connection(Self.serverID)?.state == .needsAuth)
  }

  @Test func disconnectedToExpiredIsANoOp() {
    let store = Self.store(state: .disconnected)

    let moved = store.transition(Self.serverID, to: .expired)

    #expect(!moved)
    #expect(store.connection(Self.serverID)?.state == .disconnected)
  }

  @Test(arguments: everyEdge)
  func theEdgeTableDecidesEachTransition(edge: Edge) {
    let store = Self.store(state: ConnectionState.sample(edge.from))
    let target = ConnectionState.sample(edge.to, message: "second")

    let moved = store.transition(Self.serverID, to: target)

    let allowed = Self.allowedEdges.contains(edge)
    #expect(moved == allowed)
    #expect(ConnectionState.canTransition(from: edge.from, to: edge.to) == allowed)
    let expected = allowed ? target : ConnectionState.sample(edge.from)
    #expect(store.connection(Self.serverID)?.state == expected)
  }

  @Test func theDecisionTableIsTheEdgeTable() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    let row = /^\| `([a-z-]+)` \| (.+) \|$/.anchorsMatchLineEndings()
    var documented: Set<Edge> = []
    for match in text.matches(of: row) {
      let from = try #require(ConnectionState.Kind(rawValue: String(match.output.1)))
      for name in match.output.2.split(separator: ",") {
        let trimmed = name.trimmingCharacters(in: .whitespaces.union(["`"]))
        let to = try #require(ConnectionState.Kind(rawValue: trimmed))
        documented.insert(Edge(from, to))
      }
    }

    #expect(documented == Self.allowedEdges)
  }

  @Test func theDisconnectedStateIsTheInitialStateOfAConnection() {
    let connection = Connection(id: Self.serverID, name: "GitHub")

    #expect(connection.state == .disconnected)
    #expect(connection.tools.isEmpty)
  }

  @Test func aTransitionChangesOnlyItsConnection() {
    let store = Self.store(state: .disconnected)

    store.transition(Self.serverID, to: .connected)

    #expect(store.connection(Self.otherID)?.state == .disconnected)
  }

  @Test func aTransitionOfAnUnknownConnectionIsANoOp() {
    let store = Self.store(state: .disconnected)
    let before = store.connections

    let moved = store.transition(ConnectionID("missing"), to: .connected)

    #expect(!moved)
    #expect(store.connections == before)
  }

  // MARK: - State kinds

  @Test func eachKindHasADistinctNameAndLabel() {
    let kinds = ConnectionState.Kind.allCases

    #expect(kinds.count == 6)
    #expect(Set(kinds.map(\.rawValue)).count == 6)
    #expect(Set(kinds.map(\.label)).count == 6)
    #expect(ConnectionState.Kind.needsAuth.rawValue == "needs-auth")
  }

  @Test func theErrorStateKeepsItsMessage() {
    let state = ConnectionState.error("Server unreachable")

    #expect(state.kind == .error)
    #expect(state.errorMessage == "Server unreachable")
    #expect(ConnectionState.connected.errorMessage == nil)
  }

  // MARK: - Tool toggles

  @Test func setToolEnabledChangesOneToolOfOneConnection() {
    let store = Self.store(state: .connected)

    store.setToolEnabled(Self.serverID, Self.issueID, true)
    store.setToolEnabled(Self.serverID, Self.searchID, false)

    let tools = store.connection(Self.serverID)?.tools
    #expect(tools?.map(\.isEnabled) == [false, true])
    #expect(store.connection(Self.otherID)?.tools.map(\.isEnabled) == [true])
  }

  @Test func setToolEnabledForAnUnknownToolIsANoOp() {
    let store = Self.store(state: .connected)
    let before = store.connections

    store.setToolEnabled(Self.serverID, ToolToggleID("missing"), true)
    store.setToolEnabled(ConnectionID("missing"), Self.searchID, false)

    #expect(store.connections == before)
  }

  // MARK: - Actions

  @Test func connectAndDisconnectGoToTheActions() async {
    let actions = RecordingConnectionActions()
    let store = Self.store(state: .disconnected, actions: actions)

    await store.connect(Self.serverID)
    await store.disconnect(Self.otherID)

    #expect(actions.calls == [.connect(Self.serverID), .disconnect(Self.otherID)])
    #expect(store.connection(Self.serverID)?.state == .disconnected)
  }

  @Test func aFailedConnectMovesTheConnectionToError() async {
    let actions = RecordingConnectionActions(failure: RecordingConnectionActions.Failure())
    let store = Self.store(state: .needsAuth, actions: actions)

    await store.connect(Self.serverID)

    #expect(store.connection(Self.serverID)?.state == .error("The host failed."))
  }

  @Test func aFailedDisconnectMovesTheConnectionToError() async {
    let actions = RecordingConnectionActions(failure: RecordingConnectionActions.Failure())
    let store = Self.store(state: .connected, actions: actions)

    await store.disconnect(Self.serverID)

    #expect(store.connection(Self.serverID)?.state == .error("The host failed."))
  }

  @Test func connectWithNoActionsDoesNothing() async {
    let store = Self.store(state: .disconnected)
    let before = store.connections

    await store.connect(Self.serverID)
    await store.disconnect(Self.serverID)

    #expect(store.connections == before)
  }
}

extension ConnectionState {
  /// A state of `kind`. An error state has `message`.
  static func sample(_ kind: Kind, message: String = "first") -> ConnectionState {
    switch kind {
    case .disconnected: .disconnected
    case .connected: .connected
    case .needsAuth: .needsAuth
    case .authenticating: .authenticating
    case .expired: .expired
    case .error: .error(message)
    }
  }
}

/// The host actions of a test. The object records each call.
@MainActor
final class RecordingConnectionActions: ConnectionActions {
  /// One call to the actions.
  enum Call: Equatable {
    case connect(ConnectionID)
    case disconnect(ConnectionID)
  }

  /// The error that a failing host throws.
  struct Failure: LocalizedError {
    var errorDescription: String? { "The host failed." }
  }

  /// The calls, in order.
  private(set) var calls: [Call] = []

  /// The error that each call throws, or `nil`.
  private let failure: Failure?

  init(failure: Failure? = nil) {
    self.failure = failure
  }

  func connect(_ id: ConnectionID) async throws {
    calls.append(.connect(id))
    if let failure { throw failure }
  }

  func disconnect(_ id: ConnectionID) async throws {
    calls.append(.disconnect(id))
    if let failure { throw failure }
  }
}
