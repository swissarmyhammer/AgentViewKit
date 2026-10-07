import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The connection views of a `ConnectionModel` (update.md §4.3, §4.7
/// "Connection banner", §9.4).
///
/// Each test drives a scripted agent, and the views read the model directly.
/// The connection banner reads `state`, the header reads the agent info of the
/// `initialize` result, the auth card reads `authMethods` and `authState`, and
/// the thread view opens the auth card while `authState` asks for a sign-in,
/// for example after an answer with the code `-32000`.
@Suite(.serialized, .hostedSerially) @MainActor struct ConnectionModelViewsHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

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

  // MARK: - Connection banner

  @Test func aTransportCloseShowsTheDisconnectedBanner() async throws {
    let session = try await Self.openSession()
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) == nil)

    session.close()
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) != nil
    }

    #expect(session.connection.state == .disconnected)
    #expect(harness.element(identifier: AgentConnectionBanner.disconnectedIdentifier) != nil)
  }

  @Test func aTransportFailureShowsTheFailedBannerWithTheErrorText() async throws {
    let connection = ConnectionModel(coalescingCadence: .zero)
    let harness = HostedViewHarness(size: Self.size) { AgentConnectionBanner(connection: connection) }
    defer { harness.close() }

    _ = await connection.connect(over: FailingTransport())
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentConnectionBanner.failedIdentifier) != nil
    }

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
    harness.pump()

    #expect(harness.element(identifier: AgentInfoHeader.nameIdentifier)?.label == "scripted-agent")
    #expect(harness.element(identifier: AgentInfoHeader.versionIdentifier)?.label == "Version 1.0.0")
  }

  @Test func theHeaderShowsTheTitleOfTheAgentWhenTheAgentGivesOne() async throws {
    let session = try await Self.openSession(info: Self.titledAgentInfo)
    defer { session.close() }
    let harness = HostedViewHarness(size: Self.size) { AgentInfoHeader(connection: session.connection) }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentInfoHeader.nameIdentifier)?.label == "Scripted Agent")
    #expect(harness.element(identifier: AgentInfoHeader.versionIdentifier)?.label == "Version 2.1.0")
  }

  @Test func theHeaderShowsNothingBeforeInitialize() {
    let connection = ConnectionModel(coalescingCadence: .zero)
    let harness = HostedViewHarness(size: Self.size) { AgentInfoHeader(connection: connection) }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: AgentInfoHeader.identifier) == nil)
  }

  // MARK: - Login

  @Test func aRefusedLoginShowsTheErrorOfTheAuthState() async throws {
    let session = try await Self.openSession { $0.failingMethods = [Self.loginMethod] }
    defer { session.close() }
    let harness = Self.mountAuth(session.connection)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.failureIdentifier) == nil)

    try harness.press(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.failureIdentifier) != nil
        && harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID))?.isEnabled == true
    }

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
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) != nil)

    try harness.press(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID))
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: AgentAuthView.rowIdentifier(for: Self.agentMethodID)) == nil
    }

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
    harness.pump()

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
    harness.pump()
    #expect(harness.element(identifier: AgentAuthView.identifier) == nil)

    _ = try? await session.model.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptText))])
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: AgentAuthView.identifier) != nil }

    #expect(session.connection.authState == .required(session.connection.authMethods))
    #expect(harness.element(identifier: AgentAuthView.identifier) != nil)
    #expect(harness.element(identifier: AgentAuthView.signInIdentifier(for: Self.agentMethodID)) != nil)
  }

  @Test func aPromptThatFailsWithAnotherCodeDoesNotOpenTheLoginView() async throws {
    let session = try await Self.openSignedInSession { $0.failingMethods = [ScriptedSession.promptMethod] }
    defer { session.close() }
    let harness = Self.mountThread(session)
    defer { harness.close() }
    harness.pump()

    _ = try? await session.model.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptText))])
    let lastEntry = try #require(session.model.transcript.last)
    let lastErrorCode: ErrorCode? = if case .error(let entry) = lastEntry { entry.code } else { nil }
    harness.pump()

    #expect(lastErrorCode == .internalError)

    #expect(harness.element(identifier: AgentAuthView.identifier) == nil)
  }
}
