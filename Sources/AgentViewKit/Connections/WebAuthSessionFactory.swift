import AuthenticationServices
import Foundation

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

  /// Starts the session.
  ///
  /// - Returns: `true` when the session started.
  func start() -> Bool

  /// Stops the session. The session then calls its completion with the
  /// cancelled error.
  func cancel()
}

/// The completion of a ``WebAuthSession``: the callback URL, or an error.
///
/// The shape is the same as the completion of `ASWebAuthenticationSession`.
/// A session that the user stops gives
/// `ASWebAuthenticationSessionError(.canceledLogin)`.
public typealias WebAuthSessionCompletion = @Sendable (URL?, (any Error)?) -> Void

/// The object that makes a ``WebAuthSession``.
///
/// The authorization presenter gets a factory, so that a test can give a
/// fake that completes with a scripted URL or with the cancelled error.
public protocol WebAuthSessionFactory: AnyObject {
  /// Makes a session that opens `url` and waits for a callback URL with
  /// `callbackScheme`.
  ///
  /// - Parameters:
  ///   - url: The authorization URL to open.
  ///   - callbackScheme: The URL scheme of the callback.
  ///   - completion: The closure that the session calls one time when it
  ///     ends.
  /// - Returns: A session that did not start.
  func makeSession(
    url: URL,
    callbackScheme: String,
    completion: @escaping WebAuthSessionCompletion
  ) -> any WebAuthSession
}
