import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct AgentAuthViewHostedTests {
  /// The agent method in the tests.
  static let agentMethod = AuthMethod.Agent(
    id: AuthMethodID("agent-login"), name: "Sign in with the agent",
    description: "The agent opens a browser.")

  /// The terminal method in the tests.
  static let terminalMethod = AuthMethod.Terminal(
    id: AuthMethodID("terminal-login"), name: "Terminal login", args: ["--login"])

  /// The methods that the agent gives, with one method type that the kit
  /// does not know.
  static let methods: [AuthMethod] = [
    .agent(agentMethod), .terminal(terminalMethod), .unknown("_passkey"),
  ]

  /// The command of the terminal record.
  static let terminalCommand = "/usr/local/bin/agent --login"

  /// The line that the input test types.
  static let inputLine = "yes"

  /// The width of a window that shows the full card, in points.
  static let cardWidth: CGFloat = 480

  /// The height of a window that shows the full card and a terminal, in
  /// points.
  static let cardHeight: CGFloat = 520

  /// The size of a window that shows the full card.
  static let cardSize = CGSize(width: cardWidth, height: cardHeight)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// A harness that shows the card with `actions` and `thread`.
  ///
  /// - Parameters:
  ///   - actions: The actions that the card calls.
  ///   - isAuthenticated: Whether the user is signed in.
  ///   - thread: The thread of the environment, or `nil`.
  /// - Returns: The harness.
  static func harness(
    actions: NoopThreadActions, isAuthenticated: Bool = false, thread: AgentThread? = nil
  ) -> HostedViewHarness<some View> {
    threadViewHarness(size: cardSize, actions: actions, thread: thread) {
      AgentAuthView(methods: methods, isAuthenticated: isAuthenticated)
    }
  }

  /// An error with a fixed description.
  struct LoginError: LocalizedError {
    var errorDescription: String? { "The login failed." }
  }

  // MARK: - Layout

  @Test func theCardShowsOneRowForEachKnownMethod() {
    let harness = Self.harness(actions: NoopThreadActions())
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(
      harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethod.id)) != nil)
    #expect(
      harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethod.id)) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: AuthMethodID("_passkey"))) == nil)
    let rows = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(AgentAuthView.rowIdentifierPrefix) == true
    }
    #expect(rows.count == 2)
  }

  // MARK: - Agent method

  @Test func anAgentRowCallsLoginWithTheMethodId() async throws {
    let actions = NoopThreadActions()
    let harness = Self.harness(actions: actions)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.agentMethod.id)) == nil)
    try harness.press(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethod.id))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.login(Self.agentMethod.id)])
  }

  @Test func aFailedLoginShowsTheErrorUnderTheRow() async throws {
    let actions = NoopThreadActions()
    actions.onLogin = { _ in throw LoginError() }
    let harness = Self.harness(actions: actions)
    defer { harness.close() }
    harness.pump()

    let errorID = AgentAuthView.errorIdentifier(for: Self.agentMethod.id)
    #expect(harness.element(identifier: errorID) == nil)
    try harness.press(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethod.id))
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: errorID) != nil }

    #expect(harness.element(identifier: errorID)?.label == "The login failed.")
    #expect(
      harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethod.id))?.isEnabled
        == true)
  }

  // MARK: - Terminal method

  @Test func aTerminalRowCallsRunTerminalAuthAndShowsATerminalWithAnInputField() async throws {
    let actions = NoopThreadActions()
    let thread = AgentThread()
    let terminalID = TerminalRecord.authID(for: Self.terminalMethod.id)
    actions.onRunTerminalAuth = { _ in
      thread.apply(
        .upsertTerminal(
          TerminalPatch(id: terminalID, command: .value(Self.terminalCommand), output: .value(Data()))))
    }
    let harness = Self.harness(actions: actions, thread: thread)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier) == nil)
    #expect(
      harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.terminalMethod.id)) == nil)
    try harness.press(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethod.id))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: TerminalView.inputIdentifier) != nil
    }

    #expect(actions.calls == [.runTerminalAuth(Self.terminalMethod)])
    #expect(
      harness.element(identifier: TerminalView.identifier)?.label
        == "Terminal, \(Self.terminalCommand)")
    #expect(harness.element(identifier: TerminalView.inputIdentifier) != nil)

    try #require(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type(Self.inputLine)
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { actions.calls.count == 2 }

    #expect(
      actions.calls == [
        .runTerminalAuth(Self.terminalMethod), .writeTerminalLine(Self.inputLine, terminalID),
      ])
  }

  @Test func aTerminalRowWithNoThreadShowsNoTerminal() async throws {
    let actions = NoopThreadActions()
    let harness = Self.harness(actions: actions)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethod.id))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }
    harness.pump()

    #expect(actions.calls == [.runTerminalAuth(Self.terminalMethod)])
    #expect(harness.element(identifier: TerminalView.identifier) == nil)
  }

  // MARK: - Sign out

  @Test func signOutIsHiddenWhenTheUserIsNotSignedIn() {
    let harness = Self.harness(actions: NoopThreadActions(), isAuthenticated: false)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier) == nil)
  }

  @Test func signOutCallsLogout() async throws {
    let actions = NoopThreadActions()
    let harness = Self.harness(actions: actions, isAuthenticated: true)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier) != nil)
    try harness.press(identifier: AgentAuthView.signOutIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.logout])
  }

  @Test func aFailedSignOutShowsTheError() async throws {
    let actions = NoopThreadActions()
    actions.onLogout = { _ in throw LoginError() }
    let harness = Self.harness(actions: actions, isAuthenticated: true)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: AgentAuthView.signOutIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.signOutErrorIdentifier) != nil
    }

    #expect(harness.element(identifier: AgentAuthView.signOutErrorIdentifier)?.label == "The login failed.")
  }
}
