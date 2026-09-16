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
    /// `start()` returns this callback URL.
    case callback(URL)
    /// `start()` throws `ASWebAuthenticationSessionError(.canceledLogin)`.
    case cancelled
    /// `start()` throws ``WebAuthSessionError/failedToStart``.
    case failsToStart
    /// `start()` waits until `cancel()`, then throws
    /// `ASWebAuthenticationSessionError(.canceledLogin)`.
    case waitsForCancel
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
  /// - Returns: A ``Session`` that did not start.
  public func makeSession(url: URL, callbackScheme: String) -> any WebAuthSession {
    calls.append(.makeSession(url: url, callbackScheme: callbackScheme))
    let session = Session(factory: self, script: script)
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
  public final class Session: WebAuthSession {
    /// The factory that records the calls of the session.
    private weak var factory: FakeWebAuthSession?

    /// The result that the session gives when it starts.
    private let script: Script

    /// The continuation of a ``start()`` that waits for ``cancel()``.
    private var waitingStart: CheckedContinuation<URL, any Error>?

    public var prefersEphemeralWebBrowserSession = false

    public weak var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)?

    /// Whether a ``start()`` waits for ``cancel()`` now.
    public var isWaiting: Bool { waitingStart != nil }

    /// Makes a session.
    ///
    /// - Parameters:
    ///   - factory: The factory that records the calls.
    ///   - script: The result of the session.
    fileprivate init(factory: FakeWebAuthSession, script: Script) {
      self.factory = factory
      self.script = script
    }

    /// Records the start, then gives the scripted result.
    ///
    /// - Returns: The scripted callback URL.
    /// - Throws: The scripted error.
    public func start() async throws -> URL {
      factory?.record(.start(ephemeral: prefersEphemeralWebBrowserSession))
      switch script {
      case .callback(let url):
        return url
      case .cancelled:
        throw ASWebAuthenticationSessionError(.canceledLogin)
      case .failsToStart:
        throw WebAuthSessionError.failedToStart
      case .waitsForCancel:
        return try await withCheckedThrowingContinuation { waitingStart = $0 }
      }
    }

    /// Records the stop. A ``start()`` that waits then throws the cancelled
    /// error.
    public func cancel() {
      factory?.record(.cancel)
      let continuation = waitingStart
      waitingStart = nil
      continuation?.resume(throwing: ASWebAuthenticationSessionError(.canceledLogin))
    }
  }
}
