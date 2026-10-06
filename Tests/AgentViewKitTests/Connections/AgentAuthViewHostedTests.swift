import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The auth card over a `ConnectionModel` (update.md §4.3).
///
/// The card reads `authMethods`, `authState` and `canLogout` of the model of a
/// scripted agent, and calls `login(_:)` and `logout(_:)`. A terminal method
/// still runs through the thread actions, because the model has no terminal
/// auth runner.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentAuthViewHostedTests {
  /// The id of the agent method in the tests.
  static let agentMethodID = AuthMethodId(rawValue: "agent-login")

  /// The id of the terminal method in the tests.
  static let terminalMethodID = AuthMethodId(rawValue: "terminal-login")

  /// The id of the method whose type the kit does not know.
  static let unknownMethodID = AuthMethodId(rawValue: "passkey")

  /// The JSON text of the agent method.
  static let agentMethodJSON =
    #"{"type": "agent", "methodId": "agent-login", "name": "Sign in with the agent", "description": "The agent opens a browser."}"#

  /// The JSON text of the terminal method.
  static let terminalMethodJSON =
    #"{"type": "terminal", "methodId": "terminal-login", "name": "Terminal login", "args": ["--login"]}"#

  /// The JSON text of a method type that the kit does not know.
  static let unknownMethodJSON = #"{"type": "_passkey", "methodId": "passkey", "name": "Passkey"}"#

  /// The methods that the agent gives: an agent method, a terminal method,
  /// and one method type that the kit does not know.
  static let allMethods = "[\(agentMethodJSON), \(terminalMethodJSON), \(unknownMethodJSON)]"

  /// The methods of an agent that serves no `auth/logout`: one terminal
  /// method.
  static let terminalOnlyMethods = "[\(terminalMethodJSON)]"

  /// The terminal method, as the thread actions get it.
  static let kitTerminalMethod = AgentViewKit.AuthMethod.Terminal(
    id: AuthMethodID(terminalMethodID.rawValue), name: "Terminal login", args: ["--login"])

  /// The method of a logout request.
  static let logoutMethod = "auth/logout"

  /// The message of the error that the scripted agent sends.
  static let scriptedErrorMessage = "failed"

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

  /// Opens a scripted session whose agent gives `authMethods`.
  ///
  /// - Parameters:
  ///   - authMethods: The JSON text of the `authMethods` array.
  ///   - configure: Changes the agent before it starts.
  /// - Returns: The scripted session.
  static func openSession(
    authMethods: String = allMethods, configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    try await ScriptedSession.open {
      $0.results["initialize"] = ScriptedSession.makeInitializeResult(
        info: ScriptedSession.agentInfo, authMethods: authMethods)
      configure($0)
    }
  }

  /// A harness that shows the card of the connection of `session`, with the
  /// session model in the environment.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - actions: The actions that the terminal rows call.
  ///   - thread: The thread of the environment, or `nil`.
  /// - Returns: The harness.
  static func harness(
    _ session: ScriptedSession, actions: NoopThreadActions = NoopThreadActions(), thread: AgentThread? = nil
  ) -> HostedViewHarness<some View> {
    threadViewHarness(size: cardSize, actions: actions, thread: thread) {
      AgentAuthView(connection: session.connection)
        .environment(\.sessionModel, session.model)
    }
  }

  // MARK: - Layout

  @Test func theCardShowsOneRowForEachKnownMethod() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.unknownMethodID)) == nil)
    let rows = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(AgentAuthView.rowIdentifierPrefix) == true
    }
    #expect(rows.count == 2)
  }

  @Test func anAgentRowHasASignInButtonAndNoRunButton() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.agentMethodID)) == nil)
  }

  // MARK: - Terminal method

  @Test func aTerminalRowCallsRunTerminalAuthAndShowsATerminalWithAnInputField() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let actions = NoopThreadActions()
    let thread = AgentThread()
    let terminalID = TerminalRecord.authID(for: Self.kitTerminalMethod.id)
    actions.onRunTerminalAuth = { _ in
      thread.apply(
        .upsertTerminal(
          TerminalPatch(id: terminalID, command: .value(Self.terminalCommand), output: .value(Data()))))
    }
    let harness = Self.harness(session, actions: actions, thread: thread)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: TerminalView.identifier) == nil)
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.terminalMethodID)) == nil)
    try harness.press(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: TerminalView.inputIdentifier) != nil
    }

    #expect(actions.calls == [.runTerminalAuth(Self.kitTerminalMethod)])
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
        .runTerminalAuth(Self.kitTerminalMethod), .writeTerminalLine(Self.inputLine, terminalID),
      ])
  }

  @Test func aTerminalRowWithNoThreadShowsNoTerminal() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let actions = NoopThreadActions()
    let harness = Self.harness(session, actions: actions)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID))
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }
    harness.pump()

    #expect(actions.calls == [.runTerminalAuth(Self.kitTerminalMethod)])
    #expect(harness.element(identifier: TerminalView.identifier) == nil)
  }

  // MARK: - Sign out

  @Test func signOutIsHiddenWhenTheAgentCannotLogOut() async throws {
    let session = try await Self.openSession(authMethods: Self.terminalOnlyMethods)
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(!session.connection.canLogout)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier) == nil)
  }

  @Test func signOutSendsTheLogoutFrameAndShowsTheSignInRowsAgain() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    try await session.connection.login(LoginAuthRequest(methodId: Self.agentMethodID))
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) == nil)

    try harness.press(identifier: AgentAuthView.signOutIdentifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil
    }

    #expect(session.agent.messages(method: Self.logoutMethod).count == 1)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)
  }

  @Test func aFailedSignOutAddsAnErrorEntryToTheSession() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.logoutMethod] }
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: AgentAuthView.signOutIdentifier)
    // The error entry and the end of the progress come in one main-actor
    // turn, but the view draws the enabled button in a later pass.
    await harness.pump(until: Self.waitTimeout) {
      !session.model.transcript.isEmpty
        && harness.element(identifier: AgentAuthView.signOutIdentifier)?.isEnabled == true
    }

    let lastEntry = try #require(session.model.transcript.last)
    let message: String? = if case .error(let entry) = lastEntry { entry.message } else { nil }
    #expect(message == Self.scriptedErrorMessage)
    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier)?.isEnabled == true)
  }
}
