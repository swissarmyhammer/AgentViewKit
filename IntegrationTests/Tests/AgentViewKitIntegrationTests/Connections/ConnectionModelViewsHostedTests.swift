import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The connection views of a `ConnectionModel` (plan.md §3.3, §3.8
/// "Connection banner", "Login on error `-32000`").
///
/// Each test drives a scripted agent, and the views read the model directly.
/// The connection banner reads `state`, the header reads the agent info of the
/// `initialize` result, the auth card reads `authMethods` and `authState`, and
/// the thread view opens the auth card while `authState` asks for a sign-in,
/// for example after an answer with the code `-32000`.
@Suite(.serialized, .hostedSerially) @MainActor struct ConnectionModelViewsHostedTests {
  /// A size that shows the thread with its header, its banners and the auth
  /// card.
  static let size = CGSize(width: 480, height: 800)

  /// The method of a login request.
  static let loginMethod = "auth/login"

  /// The JSON-RPC code of the error "authentication required".
  static let authenticationRequiredCode = -32000

  /// The error that the scripted agent sends for a failing method with no
  /// code of its own: code `-32603` and the message `failed`.
  static let scriptedRefusal = RequestError(code: .internalError, message: "failed")

  /// The id of the agent auth method of the scripted agent.
  static let agentMethodID = AuthMethodId(rawValue: "agent-login")

  /// The `authMethods` array of the scripted agent: one agent method.
  static let authMethods =
    #"[{"type": "agent", "methodId": "\#(agentMethodID.rawValue)", "name": "Sign in with the agent"}]"#

  /// The `info` member of an agent with a title.
  static let titledAgentInfo = #"{"name": "scripted-agent", "title": "Scripted Agent", "version": "2.1.0"}"#

  /// The text of the error that the failing transport throws.
  nonisolated static let transportFailureText = "The pipe to the agent broke."

  /// The text of the prompt in the `-32000` test.
  static let promptText = "Hello"

  /// An error with a fixed description, which the failing transport throws.
  struct TransportFailure: LocalizedError {
    var errorDescription: String? { ConnectionModelViewsHostedTests.transportFailureText }
  }

  /// A transport whose incoming stream throws at once.
  struct FailingTransport: ACPTransport {
    /// The incoming bytes: no chunk, then ``TransportFailure``.
    let bytes = AsyncThrowingStream<Data, any Error> { $0.finish(throwing: TransportFailure()) }

    /// Discards each chunk.
    ///
    /// - Parameter data: The chunk to discard.
    func write(_ data: Data) async throws {}
  }

  /// Opens a scripted session whose agent gives the auth methods and the
  /// agent info.
  ///
  /// - Parameters:
  ///   - info: The JSON text of the `info` member.
  ///   - configure: Changes the agent before it starts.
  /// - Returns: The scripted session.
  static func openSession(
    info: String = ScriptedSession.agentInfo, configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    try await ScriptedSession.open {
      $0.results["initialize"] = ScriptedSession.makeInitializeResult(info: info, authMethods: authMethods)
      configure($0)
    }
  }

  /// Shows the thread of a session with its connection model.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The harness.
  static func mountThread(_ session: ScriptedSession) -> HostedViewHarness<some View> {
    HostedViewHarness(size: size) {
      AgentThreadView(session: session.model, connection: session.connection)
        .transaction { $0.disablesAnimations = true }
    }
  }

  /// Shows the auth card of a connection model.
  ///
  /// - Parameter connection: The connection model.
  /// - Returns: The harness.
  static func mountAuth(_ connection: ConnectionModel) -> HostedViewHarness<some View> {
    HostedViewHarness(size: size) {
      AgentAuthView(connection: connection)
        .transaction { $0.disablesAnimations = true }
    }
  }

  /// Presses an action button of ``AgentAuthView``, and requires that the
  /// button shows the progress of its call.
  ///
  /// The card disables the button in the same step as the press, and then
  /// runs the call in a task. Thus a press that the card did not handle
  /// stops the test here, and the test does not wait for an end of a call
  /// that did not start.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - harness: The harness of the card.
  /// - Throws: The error of the press, or an issue when the button is still
  ///   enabled.
  static func pressAuthAction(_ identifier: String, in harness: HostedViewHarness<some View>) throws {
    try harness.press(identifier: identifier)
    try #require(harness.element(identifier: identifier)?.isEnabled == false)
  }

  /// Whether the auth state of `connection` is no longer the state that
  /// `initialize` gives: `.required` with the methods of the agent.
  ///
  /// A sign-in, a sign-out or a terminal sign-in from the card changes the
  /// state when the call ends, with success or with a failure. Thus a test
  /// that pressed a button of the card waits for this event.
  ///
  /// - Parameter connection: The connection model.
  /// - Returns: `true` when `authState` is not `.required(authMethods)`.
  static func hasLeftTheRequiredState(_ connection: ConnectionModel) -> Bool {
    connection.authState != .required(connection.authMethods)
  }

  /// Whether the connection state of `connection` is `.failed`.
  ///
  /// - Parameter connection: The connection model.
  /// - Returns: `true` when the read from the agent failed.
  static func hasFailed(_ connection: ConnectionModel) -> Bool {
    if case .failed = connection.state { true } else { false }
  }

  // MARK: - Connection banner

  @Test func aTransportCloseShowsTheDisconnectedBanner() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) == nil)

    session.close()
    let connection = session.connection
    await harness.render { connection.state == .disconnected }

    #expect(session.connection.state == .disconnected)
    #expect(harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) != nil)
  }

  @Test func aTransportFailureShowsTheFailedBannerWithTheErrorText() async throws {
    let connection = ConnectionModel(coalescingCadence: .zero)
    let harness = HostedViewHarness(size: Self.size) { AgentConnectionBanner(connection: connection) }
    defer { harness.close() }

    _ = await connection.connect(over: FailingTransport())
    await harness.render { Self.hasFailed(connection) }

    let label = try #require(harness.element(identifier: AgentConnectionBanner.failedIdentifier)?.label)
    #expect(label.contains(Self.transportFailureText))
    #expect(harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) == nil)
  }

  // MARK: - Agent info

  @Test func theHeaderShowsTheAgentNameAndVersionFromTheInitializeResult() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.render()

    let header = try #require(harness.element(identifier: AgentInfoHeader.identifier))
    #expect(header.label == "scripted-agent")
    #expect(header.value == "Version 1.0.0")
  }

  @Test func theHeaderShowsTheTitleOfTheAgentWhenTheAgentGivesOne() async throws {
    let session = try await Self.openSession(info: Self.titledAgentInfo)
    defer { session.close() }
    let harness = HostedViewHarness(size: Self.size) { AgentInfoHeader(connection: session.connection) }
    defer { harness.close() }
    harness.render()

    let header = try #require(harness.element(identifier: AgentInfoHeader.identifier))
    #expect(header.label == "Scripted Agent")
    #expect(header.value == "Version 2.1.0")
  }

  @Test func theHeaderShowsNothingBeforeInitialize() {
    let connection = ConnectionModel(coalescingCadence: .zero)
    let harness = HostedViewHarness(size: Self.size) { AgentInfoHeader(connection: connection) }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: AgentInfoHeader.identifier) == nil)
  }

  // MARK: - Login

  @Test func aRefusedLoginShowsTheErrorOfTheAuthState() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.loginMethod] }
    defer { session.close() }
    let harness = Self.mountAuth(session.connection)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try Self.pressAuthAction(AgentAuthView.signInIdentifier(for: Self.agentMethodID), in: harness)
    // The failure and the end of the progress come in one main-actor turn.
    let connection = session.connection
    await harness.render { Self.hasLeftTheRequiredState(connection) }

    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) != nil)
    #expect(
      session.connection.authState
        == .failed(AuthFailure(operation: .login(Self.agentMethodID), reason: .request(Self.scriptedRefusal))))
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier)?.label == Self.scriptedRefusal.message)
    #expect(harness.element(identifier: AgentAuthView.failureTitleIdentifier)?.label == "Sign-in failed")
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID))?.isEnabled == true)
  }

  @Test func theSignInButtonSendsTheLoginFrameAndALoginHidesTheSignInRows() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountAuth(session.connection)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)

    try Self.pressAuthAction(AgentAuthView.signInIdentifier(for: Self.agentMethodID), in: harness)
    let connection = session.connection
    await harness.render { Self.hasLeftTheRequiredState(connection) }

    let login = try #require(session.agent.messages(method: Self.loginMethod).first)
    #expect(login["params"]?["methodId"]?.stringValue == Self.agentMethodID.rawValue)
    #expect(session.agent.messages(method: Self.loginMethod).count == 1)
    #expect(session.connection.authState == .authenticated(Self.agentMethodID))
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) == nil)
  }

  // MARK: - Authentication required

  /// Opens a scripted session and signs in with the agent method, so that
  /// `authState` is `.authenticated` and the thread shows no login card.
  ///
  /// - Parameter configure: Changes the agent before it starts.
  /// - Returns: The scripted session.
  static func openSignedInSession(configure: (ScriptedWireAgent) -> Void) async throws -> ScriptedSession {
    let session = try await openSession(configure: configure)
    try await session.connection.login(LoginAuthRequest(methodId: agentMethodID))
    return session
  }

  @Test func theRequiredAuthStateOfInitializeOpensTheLoginViewWithNoErrorEntry() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.render()

    #expect(session.connection.authState == .required(session.connection.authMethods))
    #expect(session.model.transcript.isEmpty)
    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
  }

  @Test func aPromptThatFailsWithAuthenticationRequiredOpensTheLoginView() async throws {
    let session = try await Self.openSignedInSession {
      $0.failingMethods = [ScriptedSession.promptMethod]
      $0.errorCodes[ScriptedSession.promptMethod] = Self.authenticationRequiredCode
    }
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.render()
    #expect(harness.element(identifier: AgentAuthView.identifier) == nil)

    _ = try? await session.model.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptText))])
    // The connection model records the `-32000` answer before the prompt
    // call throws it again, so `authState` is final when the call returns.
    harness.render()

    #expect(session.connection.authState == .required(session.connection.authMethods))
    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
  }

  @Test func aPromptThatFailsWithAnotherCodeDoesNotOpenTheLoginView() async throws {
    let session = try await Self.openSignedInSession { $0.failingMethods = [ScriptedSession.promptMethod] }
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.render()

    _ = try? await session.model.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptText))])
    let lastEntry = try #require(session.model.transcript.last)
    let lastErrorCode: ErrorCode? = if case .error(let entry) = lastEntry { entry.code } else { nil }
    // The connection model reads the error of the prompt before the prompt
    // call throws it again, so `authState` is final when the call returns.
    harness.render()

    #expect(lastErrorCode == .internalError)

    #expect(harness.element(identifier: AgentAuthView.identifier) == nil)
  }
}
