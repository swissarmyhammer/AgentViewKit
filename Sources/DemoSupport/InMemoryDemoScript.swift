/// The script that ``InMemoryDemoACPAgent`` serves.
///
/// - ``standard`` is the script of the ACP tab and of the wire tests: one
///   session, and one sign-in method that the agent accepts.
/// - ``gallery`` adds the scripted sessions of ``DemoGallery`` for the
///   Gallery tab, and advertises no sign-in, so that no thread of the Gallery
///   shows the sign-in card.
/// - ``noSignIn`` and ``rejectedSignIn`` are the scripts of the connection
///   states of ``DemoConnectionState``.
///
/// The value is constant data, so the type is not isolated to the main
/// actor, and ``InMemoryDemoACPAgent`` reads it from its own actor.
nonisolated public struct InMemoryDemoScript: Sendable {
  /// What the agent does for a sign-in.
  public enum SignIn: Sendable {
    /// `initialize` gives no auth method.
    case notAdvertised

    /// `initialize` gives one `agent` method, and `auth/login` succeeds.
    case accepted

    /// `initialize` gives one `agent` method, and `auth/login` fails.
    case rejected
  }

  /// The script of the ACP tab: one sign-in method that the agent accepts,
  /// and no scripted session.
  public static let standard = InMemoryDemoScript(signIn: .accepted, sessions: [])

  /// The script of the Gallery tab: no sign-in, and each session of
  /// ``DemoGallery``.
  public static let gallery = InMemoryDemoScript(signIn: .notAdvertised, sessions: DemoGallery.sessions)

  /// No sign-in, and no scripted session.
  public static let noSignIn = InMemoryDemoScript(signIn: .notAdvertised, sessions: [])

  /// One sign-in method that the agent rejects, and no scripted session.
  public static let rejectedSignIn = InMemoryDemoScript(signIn: .rejected, sessions: [])

  /// What the agent does for a sign-in.
  public let signIn: SignIn

  /// The scripted sessions that `session/list` adds after the session of
  /// ``InMemoryDemoAgent``.
  public let sessions: [DemoGallerySession]

  /// The requests that the agent sends at once after the result of each
  /// `session/new`. Each request waits for the answer of the user. Only the
  /// tests set requests here, so that a request can come to the client
  /// before the client opens the session model. The scripts of the demo app
  /// have none.
  let newSessionRequests: [DemoAgentRequest]

  /// Makes a script.
  ///
  /// - Parameters:
  ///   - signIn: What the agent does for a sign-in.
  ///   - sessions: The scripted sessions that `session/list` adds.
  ///   - newSessionRequests: The requests that the agent sends at once after
  ///     the result of each `session/new`. The default is none.
  init(signIn: SignIn, sessions: [DemoGallerySession], newSessionRequests: [DemoAgentRequest] = []) {
    self.signIn = signIn
    self.sessions = sessions
    self.newSessionRequests = newSessionRequests
  }

  /// Whether `initialize` gives the sign-in method.
  var advertisesSignIn: Bool {
    signIn != .notAdvertised
  }

  /// The scripted session with an id.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The session, or `nil` when the script has no session with
  ///   that id.
  func session(id: String) -> DemoGallerySession? {
    sessions.first { $0.id == id }
  }
}
