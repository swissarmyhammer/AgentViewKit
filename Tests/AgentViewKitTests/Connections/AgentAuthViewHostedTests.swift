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
/// The card reads `authMethods`, `authState`, `canLogin` and `canLogout` of
/// the model of a scripted agent, and calls `login(_:)`, `logout(_:)` and
/// `loginWithTerminal(_:runner:)`. A terminal method runs through the
/// `terminalAuthRunner` environment value, and the Reconnect button calls the
/// `agentReconnect` environment value.
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

  /// The methods of an agent that gives only a terminal method, so the
  /// agent serves no `auth/login`.
  static let terminalOnlyMethods = "[\(terminalMethodJSON)]"

  /// The methods of an agent that serves no `auth/logout`: no method. The
  /// client model follows the ACP rule: an agent that lists an auth method of
  /// any type serves `auth/logout`.
  static let noMethods = "[]"

  /// The run that the model gives to the runner for the terminal method: the
  /// `args` of the method and no environment variable.
  static let terminalRun = FakeTerminalAuthRunner.Run(arguments: ["--login"], environment: [:])

  /// The exit status of a terminal process that succeeded.
  static let successStatus: Int32 = 0

  /// The exit status of a terminal process that failed.
  static let failureStatus: Int32 = 1

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

  /// The text of the error that the throwing runner gives when the agent
  /// program does not start.
  nonisolated static let launchErrorText = "The agent program did not start."

  /// The title that the card shows for a failed terminal sign-in.
  static let terminalFailureTitle = "Terminal sign-in failed"

  /// The error of a runner that cannot start the agent program.
  nonisolated struct LaunchError: Error, CustomStringConvertible {
    /// The text of the error: ``AgentAuthViewHostedTests/launchErrorText``.
    var description: String { AgentAuthViewHostedTests.launchErrorText }
  }

  /// A `TerminalAuthRunner` that cannot start the agent program: each run
  /// throws ``LaunchError``.
  nonisolated struct ThrowingTerminalAuthRunner: TerminalAuthRunner {
    /// Starts no process and throws ``LaunchError``.
    func runTerminalAuth(arguments: [String], environment: [String: String]) async throws -> Int32? {
      throw LaunchError()
    }
  }

  /// What the card shows after a terminal sign-in that failed.
  struct TerminalFailure {
    /// The auth state of the model.
    let authState: AuthState
    /// The label of the failure title, or `nil` when the card shows none.
    let title: String?
    /// The label of the failure text, or `nil` when the card shows none.
    let text: String?
    /// Whether the card shows the text that asks for a reconnect.
    let showsReconnectText: Bool
  }

  /// A host closure that counts its calls, for the Reconnect button.
  @MainActor final class ReconnectRecorder {
    /// The number of calls.
    private(set) var callCount = 0

    /// Records one call.
    func reconnect() async {
      callCount += 1
    }
  }

  /// Opens a scripted session whose agent gives `authMethods`.
  ///
  /// - Parameters:
  ///   - authMethods: The JSON text of the `authMethods` array.
  ///   - runner: The runner of the host, or `nil`. With a runner, the
  ///     `initialize` request advertises `auth.terminal`.
  ///   - configure: Changes the agent before it starts.
  /// - Returns: The scripted session.
  static func openSession(
    authMethods: String = allMethods,
    runner: (any TerminalAuthRunner)? = nil,
    configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    try await ScriptedSession.open(terminalAuthRunner: runner) {
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
  ///   - actions: The actions that the terminal input field calls.
  ///   - thread: The thread of the environment, or `nil`.
  ///   - runner: The terminal auth runner of the environment, or `nil`.
  ///   - reconnect: The Reconnect closure of the environment, or `nil`.
  /// - Returns: The harness.
  static func harness(
    _ session: ScriptedSession,
    actions: NoopThreadActions = NoopThreadActions(),
    thread: AgentThread? = nil,
    runner: (any TerminalAuthRunner)? = nil,
    reconnect: AgentReconnect? = nil
  ) -> HostedViewHarness<some View> {
    threadViewHarness(size: cardSize, actions: actions, thread: thread) {
      AgentAuthView(connection: session.connection)
        .environment(\.sessionModel, session.model)
        .terminalAuthRunner(runner)
        .agentReconnect(reconnect)
    }
  }

  /// Presses the Run button of the terminal method, and waits until the
  /// model records the end of the run.
  ///
  /// - Parameters:
  ///   - harness: The harness of the card.
  ///   - session: The scripted session of the card.
  static func pressRunAndWait(
    in harness: HostedViewHarness<some View>, of session: ScriptedSession
  ) async throws {
    try harness.press(identifier: AgentAuthView.runIdentifier(for: terminalMethodID))
    await harness.pump(until: waitTimeout) {
      session.connection.authState != .required(session.connection.authMethods)
    }
    harness.pump()
  }

  /// Runs the terminal method with `runner` in a new card, and waits until
  /// the card shows a failure.
  ///
  /// - Parameter runner: The runner of the host.
  /// - Returns: The auth state and the texts that the card shows after the
  ///   run.
  static func runTerminalSignIn(with runner: any TerminalAuthRunner) async throws -> TerminalFailure {
    let session = try await openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try await pressRunAndWait(in: harness, of: session)
    await harness.pump(until: waitTimeout) {
      harness.element(identifier: AgentAuthView.failureIdentifier) != nil
    }

    return TerminalFailure(
      authState: session.connection.authState,
      title: harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label,
      text: harness.element(identifier: AgentAuthView.failureIdentifier)?.label,
      showsReconnectText: harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) != nil)
  }

  /// The failure state of a terminal sign-in that ended with `reason`.
  ///
  /// - Parameter reason: The reason of the failure.
  /// - Returns: `.failed` with the terminal method and `reason`.
  static func terminalFailureState(_ reason: AuthFailure.Reason) -> AuthState {
    .failed(AuthFailure(operation: .terminalLogin(terminalMethodID), reason: reason))
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
    let harness = Self.harness(session, runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.agentMethodID)) == nil)
  }

  @Test func anAgentWithOnlyATerminalMethodShowsNoSignInButton() async throws {
    let session = try await Self.openSession(authMethods: Self.terminalOnlyMethods)
    defer { session.close() }
    let harness = Self.harness(session, runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))
    defer { harness.close() }
    harness.pump()

    #expect(!session.connection.canLogin)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID)) != nil)
    let signInButtons = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(AgentAuthView.signInIdentifierPrefix) == true
    }
    #expect(signInButtons.isEmpty)
  }

  // MARK: - Terminal method

  @Test func withNoTerminalAuthRunnerATerminalRowHasNoRunButton() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID)) == nil)
  }

  @Test func theRunButtonGivesTheArgumentsOfTheMethodToTheRunner() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.terminalMethodID)) == nil)

    try await Self.pressRunAndWait(in: harness, of: session)

    #expect(runner.runs == [Self.terminalRun])
    #expect(session.agent.messages(method: ConnectionModelViewsHostedTests.loginMethod).isEmpty)
  }

  @Test func aRunnerWithNoExitStatusShowsTheTerminalFailureText() async throws {
    let failure = try await Self.runTerminalSignIn(with: FakeTerminalAuthRunner(exitStatus: nil))

    #expect(failure.authState == Self.terminalFailureState(.terminal(exitStatus: nil, message: nil)))
    #expect(failure.text == "The sign-in process ended with no exit status.")
    #expect(failure.title == Self.terminalFailureTitle)
    #expect(!failure.showsReconnectText)
  }

  @Test func aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus() async throws {
    let failure = try await Self.runTerminalSignIn(with: FakeTerminalAuthRunner(exitStatus: Self.failureStatus))

    #expect(failure.authState == Self.terminalFailureState(.terminal(exitStatus: Self.failureStatus, message: nil)))
    #expect(failure.text == "The sign-in process ended with exit status 1.")
    #expect(failure.title == Self.terminalFailureTitle)
    #expect(!failure.showsReconnectText)
  }

  @Test func aRunnerThatCannotStartTheProgramShowsTheMessageOfItsError() async throws {
    let failure = try await Self.runTerminalSignIn(with: ThrowingTerminalAuthRunner())

    #expect(failure.authState == Self.terminalFailureState(.terminal(exitStatus: nil, message: Self.launchErrorText)))
    #expect(failure.text == Self.launchErrorText)
    #expect(failure.title == Self.terminalFailureTitle)
    #expect(!failure.showsReconnectText)
  }

  @Test func anExitStatusOfZeroAsksForAReconnectAndTheButtonCallsTheHostClosure() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let recorder = ReconnectRecorder()
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner, reconnect: recorder.reconnect)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) == nil)

    try await Self.pressRunAndWait(in: harness, of: session)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.reconnectIdentifier) != nil
    }

    #expect(session.connection.authState == .reconnectRequired(Self.terminalMethodID))
    #expect(
      harness.element(identifier: AgentAuthView.reconnectMessageIdentifier)?.label
        == "Reconnect to the agent to finish the sign-in")
    #expect(recorder.callCount == 0)

    try harness.press(identifier: AgentAuthView.reconnectIdentifier)
    await harness.pump(until: Self.waitTimeout) { recorder.callCount > 0 }
    harness.pump()

    #expect(recorder.callCount == 1)
  }

  @Test func withNoReconnectClosureTheCardShowsOnlyTheReconnectText() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.pump()

    try await Self.pressRunAndWait(in: harness, of: session)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) != nil
    }

    #expect(harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.reconnectIdentifier) == nil)
  }

  @Test func aTerminalRowShowsTheRecordOfTheThreadWithAnInputField() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let actions = NoopThreadActions()
    let thread = AgentThread()
    let terminalID = TerminalRecord.authID(for: Self.terminalMethodID)
    thread.apply(
      .upsertTerminal(TerminalPatch(id: terminalID, command: .value(Self.terminalCommand), output: .value(Data()))))
    let harness = Self.harness(session, actions: actions, thread: thread)
    defer { harness.close() }
    harness.pump()

    #expect(
      harness.element(identifier: TerminalView.identifier)?.label
        == "Terminal, \(Self.terminalCommand)")
    #expect(harness.element(identifier: TerminalView.inputIdentifier) != nil)

    try #require(harness.focusFirstEditableTextView(of: NSTextField.self))
    harness.type(Self.inputLine)
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.writeTerminalLine(Self.inputLine, terminalID)])
  }

  @Test func aTerminalRowWithNoThreadShowsNoTerminal() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: TerminalView.identifier) == nil)
  }

  // MARK: - Sign out

  @Test func signOutIsHiddenWhenTheAgentCannotLogOut() async throws {
    let session = try await Self.openSession(authMethods: Self.noMethods)
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()

    #expect(!session.connection.canLogout)
    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
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

  @Test func aFailedSignOutShowsItsFailureTextAndAddsNoErrorEntry() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.logoutMethod] }
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try harness.press(identifier: AgentAuthView.signOutIdentifier)
    // The failure and the end of the progress come in one main-actor turn,
    // but the view draws the enabled button in a later pass.
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.failureIdentifier) != nil
        && harness.element(identifier: AgentAuthView.signOutIdentifier)?.isEnabled == true
    }

    #expect(harness.element(identifier: AgentAuthView.failureIdentifier)?.label == Self.scriptedErrorMessage)
    #expect(harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label == "Sign-out failed")
    #expect(session.model.transcript.isEmpty)
    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier)?.isEnabled == true)
  }
}
