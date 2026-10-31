import AgentViewKit
import FoundationModelsACP
import FoundationModelsACPClient

/// A connection state or a sign-in state that the Gallery tab of the demo
/// app shows.
///
/// The recorded sessions of FoundationModelsACPAgent have no sign-in and no
/// lost connection: the agent gives no auth method, and the Gallery keeps
/// its connection open. Each case starts its own ``InMemoryDemoACPAgent``
/// with ``open()``, resumes the session of ``InMemoryDemoAgent`` from the
/// start, and then puts the real `ConnectionModel` in its state with the
/// calls of a host. The kit views of the thread then show the state:
///
/// - ``signInRequired``: the agent gives a sign-in method, so `authState` is
///   `.required`, and the thread shows the sign-in card.
/// - ``signedIn``: a sign-in that the agent accepts, so `authState` is
///   `.authenticated`.
/// - ``signInFailed``: a sign-in that the agent rejects, so `authState` is
///   `.failed`, and the sign-in card shows the failure.
/// - ``disconnected``: the host stops the agent, so the state of the
///   connection is `.disconnected`, and the thread shows the connection
///   banner. Then a prompt fails, so the transcript shows a failed user
///   message and an error entry.
public enum DemoConnectionState: String, CaseIterable, Sendable {
  /// The agent requires a sign-in.
  case signInRequired

  /// The sign-in succeeded.
  case signedIn

  /// The sign-in failed.
  case signInFailed

  /// The connection to the agent closed.
  case disconnected

  /// The text of the prompt that the ``disconnected`` state sends after the
  /// close of the connection.
  static let promptAfterDisconnect = "Are you still there?"

  /// The title of the state in the list of the Gallery.
  public var title: String {
    switch self {
    case .signInRequired: "Sign-in required"
    case .signedIn: "Signed in"
    case .signInFailed: "Sign-in failed"
    case .disconnected: "Disconnected"
    }
  }

  /// The script of the agent of the state.
  var script: InMemoryDemoScript {
    switch self {
    case .signInRequired, .signedIn: .standard
    case .signInFailed: .rejectedSignIn
    case .disconnected: .noSignIn
    }
  }

  /// Starts the agent of the state, resumes the session of
  /// ``InMemoryDemoAgent`` from the start, and puts the models in the state.
  ///
  /// - Returns: The agent and the resumed session. The caller stops the
  ///   agent when it does not show the session any more.
  /// - Throws: The error of `initialize`, of `session/resume`, or of a
  ///   sign-in that the agent accepts.
  public func open() async throws -> (agent: DemoAgent, session: SessionModel) {
    let agent = try await DemoAgent.makeInProcess(script: script)
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: InMemoryDemoAgent.sessionID),
      replayFrom: .start(ReplayFromStart()))
    let session = try await agent.connection.resumeSession(request)
    try await enter(with: agent, session: session)
    return (agent, session)
  }

  /// Puts the models of the agent and of the session in the state, with the
  /// calls of a host.
  ///
  /// - Parameters:
  ///   - agent: The started agent.
  ///   - session: The resumed session.
  /// - Throws: The error of a sign-in that the agent accepts.
  private func enter(with agent: DemoAgent, session: SessionModel) async throws {
    let signIn = LoginAuthRequest(methodId: AuthMethodId(rawValue: InMemoryDemoAgent.authMethodID))
    switch self {
    case .signInRequired:
      break
    case .signedIn:
      try await agent.connection.login(signIn)
    case .signInFailed:
      // The failure is the state to show: the connection model records it
      // in `authState`, so the error of the call has no other use.
      _ = try? await agent.connection.login(signIn)
    case .disconnected:
      await agent.stop()
      // The failure is the state to show: the session model adds the error
      // entry, so the error of the call has no other use.
      _ = try? await session.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptAfterDisconnect))])
    }
  }
}
