import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Synchronization
import Testing

/// The auth card over a `ConnectionModel` (plan.md §3.3).
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

  /// The text of the error that the throwing runner gives when the agent
  /// program does not start.
  nonisolated static let launchErrorText = "The agent program did not start."

  /// The title that the card shows for a failed terminal sign-in.
  static let terminalFailureTitle = "Terminal sign-in failed"

  /// The title that the card shows for a failed sign-in.
  static let signInFailureTitle = "Sign-in failed"

  /// The title that the card shows for a failed sign-out.
  static let signOutFailureTitle = "Sign-out failed"

  /// The id of a method that the agent does not list.
  static let unlistedMethodID = AuthMethodId(rawValue: "unlisted-login")

  /// The texts that the card shows for a failure in `authState`.
  struct FailureTexts: Equatable {
    /// The label of the failure title, or `nil` when the card shows none.
    let title: String?
    /// The label of the failure text, or `nil` when the card shows none.
    let text: String?
  }

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
  ///
  /// The class is `@Observable`, so that a test can wait for a call with an
  /// observation wait and no clock.
  @MainActor @Observable final class ReconnectRecorder {
    /// The number of calls.
    private(set) var callCount = 0

    /// Records one call.
    func reconnect() async {
      callCount += 1
    }
  }

  /// A host Reconnect closure that waits until its task is cancelled.
  ///
  /// The class is `@Observable`, so that a test can wait for the start of a
  /// call with an observation wait and no clock. The cancel handler records
  /// the cancel in the same step as the cancel, so a test reads it with no
  /// wait.
  @MainActor @Observable final class WaitingReconnect {
    /// Whether a call waits for its cancel now.
    private(set) var isWaiting = false

    /// Whether the task of a call was cancelled.
    nonisolated var wasCancelled: Bool {
      cancelled.withLock { $0 }
    }

    /// The flag that the cancel handler sets, on the thread of the cancel.
    @ObservationIgnored nonisolated private let cancelled = Mutex(false)

    /// The continuation of the call that waits.
    @ObservationIgnored private var waiting: CheckedContinuation<Void, Never>?

    /// Waits until the task of the call is cancelled.
    func reconnect() async {
      await withTaskCancellationHandler {
        await withCheckedContinuation { continuation in
          waitForCancel(continuation)
        }
      } onCancel: {
        self.cancelled.withLock { $0 = true }
        Task { @MainActor in self.endWait() }
      }
    }

    /// Keeps the continuation of a call, or resumes it at once when the task
    /// was cancelled before the call waited.
    ///
    /// - Parameter continuation: The continuation of the call.
    private func waitForCancel(_ continuation: CheckedContinuation<Void, Never>) {
      guard !wasCancelled else {
        continuation.resume()
        return
      }
      waiting = continuation
      isWaiting = true
    }

    /// Ends the call that waits.
    private func endWait() {
      isWaiting = false
      waiting?.resume()
      waiting = nil
    }
  }

  /// Whether the host shows the auth card.
  @MainActor @Observable final class CardPresence {
    /// Whether the card is in the view tree.
    var isShown = true
  }

  /// The auth card of the connection of a scripted session, with the
  /// environment of the host: the session model, the terminal auth runner
  /// and the Reconnect closure. Each test shows the card through this view,
  /// so the environment of the card is set in one place.
  ///
  /// The card shows with no animation, so that one render pass shows each
  /// change. With a presence, the card is in the view tree only while
  /// ``CardPresence/isShown`` is `true`.
  struct HostedAuthCard: View {
    /// The scripted session of the card.
    let session: ScriptedSession

    /// The runner of the host, or `nil`.
    var runner: (any TerminalAuthRunner)?

    /// The Reconnect closure of the host, or `nil`.
    var reconnect: AgentReconnect?

    /// The presence of the card, or `nil` for a card that always shows.
    var presence: CardPresence?

    var body: some View {
      if presence?.isShown ?? true {
        AgentAuthView(connection: session.connection)
          .environment(\.sessionModel, session.model)
          .terminalAuthRunner(runner)
          .agentReconnect(reconnect)
          .transaction { $0.disablesAnimations = true }
      }
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

  /// A harness that shows the ``HostedAuthCard`` of `session`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - runner: The terminal auth runner of the environment, or `nil`.
  ///   - reconnect: The Reconnect closure of the environment, or `nil`.
  ///   - presence: The presence of the card, or `nil` for a card that always
  ///     shows.
  /// - Returns: The harness.
  static func harness(
    _ session: ScriptedSession,
    runner: (any TerminalAuthRunner)? = nil,
    reconnect: AgentReconnect? = nil,
    presence: CardPresence? = nil
  ) -> HostedViewHarness<HostedAuthCard> {
    HostedViewHarness(size: cardSize) {
      HostedAuthCard(session: session, runner: runner, reconnect: reconnect, presence: presence)
    }
  }

  /// Presses the Run button of the terminal method, waits until the model
  /// records the end of the run, and makes one render pass.
  ///
  /// - Parameters:
  ///   - harness: The harness of the card.
  ///   - session: The scripted session of the card.
  static func pressRunAndWait(
    in harness: HostedViewHarness<some View>, of session: ScriptedSession
  ) async throws {
    try ConnectionModelViewsHostedTests.pressAuthAction(AgentAuthView.runIdentifier(for: terminalMethodID), in: harness)
    let connection = session.connection
    await harness.render { ConnectionModelViewsHostedTests.hasLeftTheRequiredState(connection) }
  }

  /// Runs the terminal method with `runner` in a new card, and gives what
  /// the card shows when the model records the end of the run.
  ///
  /// - Parameter runner: The runner of the host.
  /// - Returns: The auth state and the texts that the card shows after the
  ///   run.
  static func runTerminalSignIn(with runner: any TerminalAuthRunner) async throws -> TerminalFailure {
    let session = try await openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try await pressRunAndWait(in: harness, of: session)

    return TerminalFailure(
      authState: session.connection.authState,
      title: harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label,
      text: harness.element(identifier: AgentAuthView.failureIdentifier)?.label,
      showsReconnectText: harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) != nil)
  }

  /// Shows the card of `session`, runs an auth call that the agent does not
  /// advertise, and gives the failure that the card shows.
  ///
  /// The model records the refusal in `authState` before the call throws, so
  /// one render pass after the call shows the failure.
  ///
  /// - Parameters:
  ///   - session: The scripted session of the card.
  ///   - error: The error that `call` must throw.
  ///   - call: The auth call on the connection model of `session`.
  /// - Returns: The texts of the failure that the card shows.
  static func runUnsupportedCall(
    in session: ScriptedSession,
    expecting error: ConnectionModelError,
    call: @MainActor (ConnectionModel) async throws -> Void
  ) async -> FailureTexts {
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    await #expect(throws: error) { try await call(session.connection) }
    harness.render()

    return FailureTexts(
      title: harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label,
      text: harness.element(identifier: AgentAuthView.failureIdentifier)?.label)
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
    harness.render()

    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.unknownMethodID)) == nil)
    let rows = harness.accessibilityElements().filter {
      $0.identifier?.hasPrefix(AgentAuthView.rowIdentifierPrefix) == true
    }
    #expect(rows.count == 2)
  }

  @Test func theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth() async throws {
    let session = try await Self.openSession()
    defer { session.close() }

    HostedLayoutExpectations.expectMinimumHeightFitsWidth(
      of: HostedAuthCard(session: session),
      width: Self.cardWidth)
  }

  @Test func anAgentRowHasASignInButtonAndNoRunButton() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session, runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.agentMethodID)) == nil)
  }

  @Test func theSignInRunAndSignOutButtonsKeepTheirTextAsTheirLabels() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session, runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))
    defer { harness.close() }
    harness.render()

    #expect(
      harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID))?.label
        == "Sign in with Sign in with the agent")
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID))?.label == "Run Terminal login")
    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier)?.label == "Sign out of the agent")
  }

  @Test func anAgentWithOnlyATerminalMethodShowsNoSignInButton() async throws {
    let session = try await Self.openSession(authMethods: Self.terminalOnlyMethods)
    defer { session.close() }
    let harness = Self.harness(session, runner: FakeTerminalAuthRunner(exitStatus: Self.successStatus))
    defer { harness.close() }
    harness.render()

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
    harness.render()

    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: AgentAuthView.runIdentifier(for: Self.terminalMethodID)) == nil)
  }

  @Test func theRunButtonGivesTheArgumentsOfTheMethodToTheRunner() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.terminalMethodID)) == nil)

    try await Self.pressRunAndWait(in: harness, of: session)

    #expect(runner.runs == [Self.terminalRun])
    #expect(session.agent.messages(method: ConnectionModelViewsHostedTests.loginMethod).isEmpty)
  }

  @Test func aRunnerWithNoExitStatusShowsTheTerminalFailureText() async throws {
    let reason = AuthFailure.Reason.terminal(exitStatus: nil, message: nil)
    let failure = try await Self.runTerminalSignIn(with: FakeTerminalAuthRunner(exitStatus: nil))

    #expect(failure.authState == Self.terminalFailureState(reason))
    #expect(failure.text == reason.message)
    #expect(failure.title == Self.terminalFailureTitle)
    #expect(!failure.showsReconnectText)
  }

  @Test func aNonZeroExitStatusShowsTheTerminalFailureTextWithTheStatus() async throws {
    let reason = AuthFailure.Reason.terminal(exitStatus: Self.failureStatus, message: nil)
    let failure = try await Self.runTerminalSignIn(with: FakeTerminalAuthRunner(exitStatus: Self.failureStatus))

    #expect(failure.authState == Self.terminalFailureState(reason))
    #expect(failure.text == reason.message)
    #expect(failure.text?.contains(String(Self.failureStatus)) == true)
    #expect(failure.title == Self.terminalFailureTitle)
    #expect(!failure.showsReconnectText)
  }

  @Test func aRunnerThatCannotStartTheProgramShowsTheMessageOfItsError() async throws {
    let reason = AuthFailure.Reason.terminal(exitStatus: nil, message: Self.launchErrorText)
    let failure = try await Self.runTerminalSignIn(with: ThrowingTerminalAuthRunner())

    #expect(failure.authState == Self.terminalFailureState(reason))
    #expect(failure.text == reason.message)
    #expect(failure.text?.contains(Self.launchErrorText) == true)
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
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) == nil)

    try await Self.pressRunAndWait(in: harness, of: session)

    #expect(session.connection.authState == .reconnectRequired(Self.terminalMethodID))
    #expect(
      harness.element(identifier: AgentAuthView.reconnectMessageIdentifier)?.label
        == "Reconnect to the agent to finish the sign-in")
    #expect(harness.element(identifier: AgentAuthView.reconnectIdentifier)?.label == "Reconnect to the agent")
    #expect(recorder.callCount == 0)

    try ConnectionModelViewsHostedTests.pressAuthAction(AgentAuthView.reconnectIdentifier, in: harness)
    await harness.render { recorder.callCount > 0 }

    #expect(recorder.callCount == 1)
  }

  @Test func withNoReconnectClosureTheCardShowsOnlyTheReconnectText() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner)
    defer { harness.close() }
    harness.render()

    try await Self.pressRunAndWait(in: harness, of: session)

    #expect(harness.element(identifier: AgentAuthView.reconnectMessageIdentifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.reconnectIdentifier) == nil)
  }

  /// A call that runs when the card goes away is cancelled with the card, so
  /// it does not outlive the view that started it.
  @Test func theCardCancelsTheCallThatRunsWhenItGoesAway() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let recorder = WaitingReconnect()
    let presence = CardPresence()
    let session = try await Self.openSession(runner: runner)
    defer { session.close() }
    let harness = Self.harness(session, runner: runner, reconnect: recorder.reconnect, presence: presence)
    defer { harness.close() }
    harness.render()
    try await Self.pressRunAndWait(in: harness, of: session)
    try ConnectionModelViewsHostedTests.pressAuthAction(AgentAuthView.reconnectIdentifier, in: harness)
    await harness.render { recorder.isWaiting }
    try #require(recorder.isWaiting)

    presence.isShown = false
    // The card cancels its calls when it goes away, in the same render pass,
    // so a card that cancelled nothing fails the test here.
    harness.render()

    #expect(harness.element(identifier: AgentAuthView.identifier) == nil)
    #expect(recorder.wasCancelled)
  }

  @Test func aTerminalRowShowsNoTerminalView() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.terminalMethodID)) != nil)
    #expect(harness.element(identifier: TerminalView.identifier) == nil)
  }

  // MARK: - Sign out

  @Test func signOutIsHiddenWhenTheAgentCannotLogOut() async throws {
    let session = try await Self.openSession(authMethods: Self.noMethods)
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.render()

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
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) == nil)

    try ConnectionModelViewsHostedTests.pressAuthAction(AgentAuthView.signOutIdentifier, in: harness)
    let connection = session.connection
    await harness.render { !ConnectionModelViewsHostedTests.hasLeftTheRequiredState(connection) }

    #expect(session.agent.messages(method: Self.logoutMethod).count == 1)
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)
  }

  @Test func aFailedSignOutShowsItsFailureTextAndAddsNoErrorEntry() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.logoutMethod] }
    defer { session.close() }
    let harness = Self.harness(session)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try ConnectionModelViewsHostedTests.pressAuthAction(AgentAuthView.signOutIdentifier, in: harness)
    // The failure and the end of the progress come in one main-actor turn,
    // so one render pass after the failure shows the enabled button.
    let connection = session.connection
    await harness.render { ConnectionModelViewsHostedTests.hasLeftTheRequiredState(connection) }

    #expect(harness.element(identifier: AgentAuthView.failureIdentifier)?.label == Self.scriptedErrorMessage)
    #expect(harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label == Self.signOutFailureTitle)
    #expect(session.model.transcript.isEmpty)
    #expect(harness.element(identifier: AgentAuthView.signOutIdentifier)?.isEnabled == true)
  }

  // MARK: - Unsupported operations

  @Test func aLoginWithAnUnlistedMethodShowsTheUnsupportedFailureText() async throws {
    let session = try await Self.openSession()
    defer { session.close() }

    let method = ConnectionModelViewsHostedTests.loginMethod
    let failure = await Self.runUnsupportedCall(
      in: session, expecting: .unsupported(method: method)
    ) { try await $0.login(LoginAuthRequest(methodId: Self.unlistedMethodID)) }

    #expect(
      failure
        == FailureTexts(title: Self.signInFailureTitle, text: AuthFailure.Reason.unsupported(method: method).message))
    #expect(session.agent.messages(method: ConnectionModelViewsHostedTests.loginMethod).isEmpty)
  }

  @Test func aLogoutThatTheAgentDoesNotServeShowsTheUnsupportedFailureText() async throws {
    let session = try await Self.openSession(authMethods: Self.noMethods)
    defer { session.close() }

    let method = Self.logoutMethod
    let failure = await Self.runUnsupportedCall(
      in: session, expecting: .unsupported(method: method)
    ) { try await $0.logout(LogoutAuthRequest()) }

    #expect(
      failure
        == FailureTexts(title: Self.signOutFailureTitle, text: AuthFailure.Reason.unsupported(method: method).message))
    #expect(session.agent.messages(method: Self.logoutMethod).isEmpty)
  }

  @Test func aTerminalLoginWithNoTerminalCapabilityShowsTheUnsupportedFailureText() async throws {
    let runner = FakeTerminalAuthRunner(exitStatus: Self.successStatus)
    let session = try await Self.openSession()
    defer { session.close() }

    let method = ConnectionModelError.terminalAuthOperation
    let failure = await Self.runUnsupportedCall(
      in: session, expecting: .unsupported(method: method)
    ) { try await $0.loginWithTerminal(Self.terminalMethodID, runner: runner) }

    #expect(
      failure
        == FailureTexts(title: Self.terminalFailureTitle, text: AuthFailure.Reason.unsupported(method: method).message))
    #expect(runner.runs.isEmpty)
  }
}
