import AgentViewKit
import AuthenticationServices
import Foundation

/// A ``WebAuthSessionFactory`` that makes sessions with a scripted result.
///
/// The factory and each session that it makes write to one call list, so a
/// test can read the full order of calls.
public final class FakeWebAuthSession: WebAuthSessionFactory {
  /// The result that a session gives when it starts.
  public enum Script: Equatable, Sendable {
    /// The session completes with this callback URL.
    case callback(URL)
    /// The session completes with
    /// `ASWebAuthenticationSessionError(.canceledLogin)`.
    case cancelled
    /// The session does not start. `start()` returns `false`, and the
    /// session does not call its completion.
    case failsToStart
  }

  /// One recorded call.
  public enum Call: Equatable, Sendable {
    /// The factory made a session.
    case makeSession(url: URL, callbackScheme: String)
    /// A session started, with this value of
    /// `prefersEphemeralWebBrowserSession`.
    case start(ephemeral: Bool)
    /// A session was stopped.
    case cancel
  }

  /// The result of each session that the factory makes after this value is
  /// set.
  public var script: Script

  /// Each call, in call order.
  public private(set) var calls: [Call] = []

  /// Each session that the factory made, in make order.
  public private(set) var sessions: [Session] = []

  /// Makes a factory.
  ///
  /// - Parameter script: The result of each session.
  public init(script: Script) {
    self.script = script
  }

  /// Makes a session that gives ``script`` when it starts.
  ///
  /// - Parameters:
  ///   - url: The authorization URL.
  ///   - callbackScheme: The URL scheme of the callback.
  ///   - completion: The closure that the session calls when it ends.
  /// - Returns: A ``Session`` that did not start.
  public func makeSession(
    url: URL,
    callbackScheme: String,
    completion: @escaping WebAuthSessionCompletion
  ) -> any WebAuthSession {
    calls.append(.makeSession(url: url, callbackScheme: callbackScheme))
    let session = Session(factory: self, script: script, completion: completion)
    sessions.append(session)
    return session
  }

  /// Removes each recorded call and session.
  public func reset() {
    calls.removeAll()
    sessions.removeAll()
  }

  /// Adds `call` to the call list.
  ///
  /// - Parameter call: The call to record.
  fileprivate func record(_ call: Call) {
    calls.append(call)
  }

  /// A session that ``FakeWebAuthSession`` made.
  ///
  /// The session calls its completion synchronously, in ``start()`` or in
  /// ``cancel()``, and only one time.
  public final class Session: WebAuthSession {
    /// The factory that records the calls of the session.
    private weak var factory: FakeWebAuthSession?

    /// The result that the session gives when it starts.
    private let script: Script

    /// The completion, or `nil` after the session called it.
    private var completion: WebAuthSessionCompletion?

    public var prefersEphemeralWebBrowserSession = false

    public weak var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)?

    /// Makes a session.
    ///
    /// - Parameters:
    ///   - factory: The factory that records the calls.
    ///   - script: The result of the session.
    ///   - completion: The closure to call when the session ends.
    fileprivate init(
      factory: FakeWebAuthSession,
      script: Script,
      completion: @escaping WebAuthSessionCompletion
    ) {
      self.factory = factory
      self.script = script
      self.completion = completion
    }

    /// Records the start, then gives the scripted result.
    ///
    /// - Returns: `false` for ``Script/failsToStart``, otherwise `true`.
    public func start() -> Bool {
      factory?.record(.start(ephemeral: prefersEphemeralWebBrowserSession))
      switch script {
      case .callback(let url):
        finish(url: url, error: nil)
        return true
      case .cancelled:
        finish(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
        return true
      case .failsToStart:
        return false
      }
    }

    /// Records the stop, then completes with the cancelled error when the
    /// session did not complete before.
    public func cancel() {
      factory?.record(.cancel)
      finish(url: nil, error: ASWebAuthenticationSessionError(.canceledLogin))
    }

    /// Calls the completion one time.
    ///
    /// - Parameters:
    ///   - url: The callback URL, or `nil`.
    ///   - error: The error, or `nil`.
    private func finish(url: URL?, error: (any Error)?) {
      guard let completion else { return }
      self.completion = nil
      completion(url, error)
    }
  }
}
