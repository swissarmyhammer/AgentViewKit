import AuthenticationServices
import Foundation
import Synchronization

/// The errors of a ``WebAuthSession`` that are not errors of
/// `ASWebAuthenticationSession`.
///
/// A session that the user stops throws
/// `ASWebAuthenticationSessionError(.canceledLogin)`.
public enum WebAuthSessionError: Error, Equatable, Sendable {
  /// The session did not start.
  case failedToStart
}

/// A web authentication session, with the part of
/// `ASWebAuthenticationSession` that the kit uses (plan.md §12).
public protocol WebAuthSession: AnyObject {
  /// Whether the session asks the browser not to share cookies with other
  /// sessions.
  var prefersEphemeralWebBrowserSession: Bool { get set }

  /// The object that gives the window that the session presents over.
  var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)? {
    get set
  }

  /// Starts the session and waits until it ends.
  ///
  /// - Returns: The callback URL.
  /// - Throws: ``WebAuthSessionError/failedToStart`` when the session does
  ///   not start, and `ASWebAuthenticationSessionError(.canceledLogin)` when
  ///   the session ends with no callback.
  func start() async throws -> URL

  /// Stops the session. A ``start()`` that waits then throws the cancelled
  /// error.
  func cancel()
}

/// The object that makes a ``WebAuthSession``.
///
/// The authorization presenter gets a factory, so that a test can give a
/// fake that gives a scripted URL or throws the cancelled error.
public protocol WebAuthSessionFactory: AnyObject {
  /// Makes a session that opens `url` and waits for a callback URL with
  /// `callbackScheme`.
  ///
  /// - Parameters:
  ///   - url: The authorization URL to open.
  ///   - callbackScheme: The URL scheme of the callback.
  /// - Returns: A session that did not start.
  func makeSession(url: URL, callbackScheme: String) -> any WebAuthSession
}

// MARK: - System session

/// The default ``WebAuthSessionFactory``. It makes a ``SystemWebAuthSession``
/// for each request.
public final class SystemWebAuthSessionFactory: WebAuthSessionFactory {
  /// Makes a factory.
  public init() {}

  /// Makes a ``SystemWebAuthSession`` that did not start.
  ///
  /// - Parameters:
  ///   - url: The authorization URL to open.
  ///   - callbackScheme: The URL scheme of the callback.
  /// - Returns: A ``SystemWebAuthSession``.
  public func makeSession(url: URL, callbackScheme: String) -> any WebAuthSession {
    SystemWebAuthSession(url: url, callbackScheme: callbackScheme)
  }
}

/// A ``WebAuthSession`` over `ASWebAuthenticationSession`.
///
/// `ASWebAuthenticationSession` takes its completion handler when it is made,
/// so this session makes the system session in ``start()``. The session
/// applies ``prefersEphemeralWebBrowserSession`` and
/// ``presentationContextProvider`` to the system session before it starts it.
/// The session can start one time only.
public final class SystemWebAuthSession: WebAuthSession {
  /// The authorization URL to open.
  private let url: URL

  /// The URL scheme of the callback.
  private let callbackScheme: String

  /// The system session, after ``start()``.
  private var systemSession: ASWebAuthenticationSession?

  /// Whether ``cancel()`` was called before ``start()``.
  private var isCancelledBeforeStart = false

  public var prefersEphemeralWebBrowserSession = false

  public weak var presentationContextProvider: (any ASWebAuthenticationPresentationContextProviding)?

  /// Makes a session that did not start.
  ///
  /// - Parameters:
  ///   - url: The authorization URL to open.
  ///   - callbackScheme: The URL scheme of the callback.
  public init(url: URL, callbackScheme: String) {
    self.url = url
    self.callbackScheme = callbackScheme
  }

  /// Makes and starts the system session, and waits until it ends.
  ///
  /// - Returns: The callback URL.
  /// - Throws: ``WebAuthSessionError/failedToStart`` when the system session
  ///   does not start or when this session started before, the error of the
  ///   system session when it ends with an error, and
  ///   `ASWebAuthenticationSessionError(.canceledLogin)` when ``cancel()``
  ///   was called before this call.
  public func start() async throws -> URL {
    guard !isCancelledBeforeStart else {
      throw ASWebAuthenticationSessionError(.canceledLogin)
    }
    guard systemSession == nil else {
      throw WebAuthSessionError.failedToStart
    }
    let result = WebAuthResult()
    let session = ASWebAuthenticationSession(
      url: url,
      callback: .customScheme(callbackScheme),
      completionHandler: Self.completionHandler(for: result)
    )
    session.prefersEphemeralWebBrowserSession = prefersEphemeralWebBrowserSession
    session.presentationContextProvider = presentationContextProvider
    systemSession = session
    return try await withCheckedThrowingContinuation { continuation in
      result.set(continuation)
      if !session.start() {
        result.resume(with: .failure(WebAuthSessionError.failedToStart))
      }
    }
  }

  /// Stops the system session. A ``start()`` that waits then throws the
  /// cancelled error. A later ``start()`` throws the cancelled error too.
  public func cancel() {
    guard let systemSession else {
      isCancelledBeforeStart = true
      return
    }
    systemSession.cancel()
  }

  /// Makes the completion handler of the system session.
  ///
  /// The system can call the handler on a queue that is not the main queue,
  /// so the handler is not isolated to the main actor.
  ///
  /// - Parameter result: The object that resumes the waiting ``start()``.
  /// - Returns: A handler that gives the URL or the error to `result`.
  nonisolated private static func completionHandler(for result: WebAuthResult)
    -> ASWebAuthenticationSession.CompletionHandler
  {
    { url, error in
      if let url {
        result.resume(with: .success(url))
      } else {
        result.resume(with: .failure(error ?? ASWebAuthenticationSessionError(.canceledLogin)))
      }
    }
  }
}

/// The continuation of one ``SystemWebAuthSession/start()``.
///
/// The object resumes the continuation one time only. The system session can
/// call its completion handler after `start()` returns `false`, and the
/// object ignores that second result.
nonisolated private final class WebAuthResult: Sendable {
  /// The continuation that waits, or `nil` after it resumed.
  private let continuation = Mutex<CheckedContinuation<URL, any Error>?>(nil)

  /// Keeps `continuation` until the result is known.
  ///
  /// - Parameter continuation: The continuation of `start()`.
  nonisolated func set(_ continuation: CheckedContinuation<URL, any Error>) {
    self.continuation.withLock { $0 = continuation }
  }

  /// Resumes the continuation with `result`, if it did not resume before.
  ///
  /// - Parameter result: The callback URL or the error.
  nonisolated func resume(with result: Result<URL, any Error>) {
    let waiting = continuation.withLock { value in
      defer { value = nil }
      return value
    }
    waiting?.resume(with: result)
  }
}
