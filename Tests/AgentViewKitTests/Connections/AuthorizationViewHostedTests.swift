import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct AuthorizationViewHostedTests {
  static let requestID = AuthorizationRequestID("auth-1")
  static let githubID = ConnectionID("github")

  /// A request to connect to the GitHub server with two scopes.
  static let request = AuthorizationRequest(
    id: requestID,
    serverName: "GitHub",
    scopes: ["repo", "read:org"],
    authorizationURL: URL(string: "https://github.com/login/oauth/authorize")!
  )

  /// The size of a window that shows the full card.
  static let cardSize = CGSize(width: 480, height: 320)

  /// A store with the GitHub server in `state`.
  static func store(state: ConnectionState) -> ConnectionStore {
    ConnectionStore(connections: [Connection(id: githubID, name: "GitHub", state: state)])
  }

  /// A harness that shows the card of ``request`` with `actions` and `store`.
  static func harness(
    actions: NoopThreadActions, store: ConnectionStore?
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(
      AuthorizationView(request: request)
        .threadActions(actions)
        .connectionStore(store)
        .transaction { $0.disablesAnimations = true },
      size: cardSize
    )
  }

  /// An error with a fixed description.
  struct ExchangeError: LocalizedError {
    var errorDescription: String? { "The token exchange failed." }
  }

  // MARK: - Layout

  @Test func theCardNamesTheServerAndShowsEachScope() {
    let harness = Self.harness(actions: NoopThreadActions(), store: Self.store(state: .needsAuth))
    defer { harness.close() }
    harness.pump()

    let card = harness.element(identifier: AuthorizationView.identifier(for: Self.requestID))
    let title = harness.element(identifier: AuthorizationView.titleIdentifier(for: Self.requestID))
    #expect(card != nil)
    #expect(title?.label == "Connect to GitHub")
    #expect(
      harness.element(identifier: AuthorizationView.scopeIdentifier(for: Self.requestID, scope: "repo"))?
        .label == "repo")
    #expect(
      harness.element(
        identifier: AuthorizationView.scopeIdentifier(for: Self.requestID, scope: "read:org"))?
        .label == "read:org")
  }

  // MARK: - Connect

  @Test func aPressOnConnectCallsConnectWithTheRequest() async throws {
    let actions = NoopThreadActions()
    let harness = Self.harness(actions: actions, store: Self.store(state: .needsAuth))
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: AuthorizationView.connectIdentifier(for: Self.requestID))
    await harness.pump(until: 2) { !actions.calls.isEmpty }

    #expect(actions.calls == [.connect(Self.request)])
  }

  @Test func whileConnectRunsTheButtonShowsProgressAndTheChipShowsAuthenticating() async throws {
    let actions = NoopThreadActions()
    let gate = Gate()
    actions.onConnect = { _ in await gate.wait(timeout: 2) }
    let harness = Self.harness(actions: actions, store: Self.store(state: .needsAuth))
    defer {
      gate.open()
      harness.close()
    }
    harness.pump()

    let connectID = AuthorizationView.connectIdentifier(for: Self.requestID)
    try harness.press(identifier: connectID)
    await harness.pump(until: 2) {
      harness.element(identifier: ConnectionStatusChip.identifier(for: .authenticating)) != nil
    }

    let button = harness.element(identifier: connectID)
    // SwiftUI merges the button into its progress view, so the element has the
    // busy indicator role while the call runs.
    #expect(button?.role == "AXBusyIndicator")
    #expect(button?.isEnabled == false)
    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .authenticating)) != nil)

    gate.open()
    await harness.pump(until: 2) {
      harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) != nil
    }
    let idleButton = harness.element(identifier: connectID)
    #expect(idleButton?.role == "AXButton")
    #expect(idleButton?.isEnabled == true)
    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) != nil)
  }

  // MARK: - Store state

  @Test func theChipFollowsTheStoreStateForTheServer() {
    let store = Self.store(state: .needsAuth)
    let harness = Self.harness(actions: NoopThreadActions(), store: store)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) != nil)

    store.transition(Self.githubID, to: .authenticating)
    harness.pump()
    #expect(
      harness.element(identifier: ConnectionStatusChip.identifier(for: .authenticating)) != nil)

    store.transition(Self.githubID, to: .connected)
    harness.pump()
    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .connected)) != nil)
    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) == nil)
  }

  @Test func theStoreFindsTheServerByDisplayNameWhenNoIdentifierMatches() {
    let store = ConnectionStore(connections: [
      Connection(id: ConnectionID("gh-enterprise"), name: "GitHub", state: .expired)
    ])
    let harness = Self.harness(actions: NoopThreadActions(), store: store)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .expired)) != nil)
  }

  @Test func aServerThatIsNotInTheStoreShowsNeedsAuth() {
    let harness = Self.harness(actions: NoopThreadActions(), store: nil)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ConnectionStatusChip.identifier(for: .needsAuth)) != nil)
  }

  // MARK: - Error

  @Test func aThrownErrorShowsTheMessageAndARetryButton() async throws {
    let actions = NoopThreadActions()
    actions.onConnect = { _ in throw ExchangeError() }
    let harness = Self.harness(actions: actions, store: Self.store(state: .needsAuth))
    defer { harness.close() }
    harness.pump()

    let errorID = AuthorizationView.errorIdentifier(for: Self.requestID)
    let retryID = AuthorizationView.retryIdentifier(for: Self.requestID)
    #expect(harness.element(identifier: errorID) == nil)
    #expect(harness.element(identifier: retryID) == nil)

    try harness.press(identifier: AuthorizationView.connectIdentifier(for: Self.requestID))
    await harness.pump(until: 2) { harness.element(identifier: retryID) != nil }

    #expect(harness.element(identifier: errorID)?.label == "The token exchange failed.")
    #expect(harness.element(identifier: retryID) != nil)
    #expect(harness.element(identifier: AuthorizationView.connectIdentifier(for: Self.requestID)) == nil)

    actions.onConnect = nil
    try harness.press(identifier: retryID)
    await harness.pump(until: 2) {
      actions.calls.count == 2
        && harness.element(identifier: AuthorizationView.connectIdentifier(for: Self.requestID))?
          .isEnabled == true
    }

    #expect(actions.calls == [.connect(Self.request), .connect(Self.request)])
    #expect(harness.element(identifier: errorID) == nil)
    #expect(harness.element(identifier: AuthorizationView.connectIdentifier(for: Self.requestID)) != nil)
  }
}

/// A gate that a test opens to let a waiting closure go on.
@MainActor
private final class Gate {
  /// Whether the gate is open.
  private(set) var isOpen = false

  /// Opens the gate.
  func open() {
    isOpen = true
  }

  /// Waits until the gate is open, or until `timeout` goes by.
  ///
  /// - Parameter timeout: The longest time to wait, in seconds.
  func wait(timeout: TimeInterval) async {
    let deadline = Date(timeIntervalSinceNow: timeout)
    while !isOpen, Date() < deadline {
      try? await Task.sleep(for: .milliseconds(10))
    }
  }
}
