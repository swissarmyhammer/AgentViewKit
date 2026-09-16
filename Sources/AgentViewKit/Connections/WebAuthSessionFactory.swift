import AuthenticationServices
import Foundation

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
