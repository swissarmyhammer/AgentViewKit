import AppKit
import AuthenticationServices
import Foundation

/// The errors of ``AuthorizationPresenter``.
public enum AuthorizationPresenterError: Error, Equatable, Sendable {
  /// The session ended with no callback URL. The user closed the browser, or
  /// the presenter stopped the session.
  case cancelled
  /// The session did not start.
  case failedToStart
}

/// The object that opens the system browser for an authorization URL and
/// gives back the callback URL (plan.md §12).
///
/// The presenter is a thin wrapper over `ASWebAuthenticationSession`. It
/// supplies the window that the browser sheet presents over, starts the
/// session, and returns the callback URL. It does not know OAuth. Discovery,
/// PKCE, the token exchange, and token storage are the work of the runtime.
///
/// Call ``present(url:callbackScheme:ephemeral:)`` from a user action only,
/// for example from the action of a Connect button.
public final class AuthorizationPresenter {
  /// The object that makes each session.
  private let factory: any WebAuthSessionFactory

  /// The object that gives the presentation anchor to each session.
  ///
  /// A session keeps a weak reference to its provider, so the presenter keeps
  /// the strong reference.
  private let anchorProvider: WindowAnchorProvider

  /// The session that is open now, or `nil`.
  private var openSession: (any WebAuthSession)?

  /// Whether a session is open now.
  public var isPresenting: Bool { openSession != nil }

  /// Makes a presenter.
  ///
  /// - Parameters:
  ///   - factory: The object that makes each session. The default makes
  ///     sessions over `ASWebAuthenticationSession`.
  ///   - anchor: The window that the browser sheet presents over. When the
  ///     value is `nil`, the presenter uses the key window, then the main
  ///     window of the app.
  public init(
    factory: any WebAuthSessionFactory = SystemWebAuthSessionFactory(),
    anchor: NSWindow? = nil
  ) {
    self.factory = factory
    self.anchorProvider = WindowAnchorProvider(window: anchor)
  }

  /// Opens `url` in a browser session and waits for the callback URL.
  ///
  /// When the task that calls this function is cancelled, the presenter
  /// stops the session.
  ///
  /// - Parameters:
  ///   - url: The authorization URL to open.
  ///   - callbackScheme: The URL scheme of the callback.
  ///   - ephemeral: Whether the browser must not share cookies with other
  ///     sessions. The value sets `prefersEphemeralWebBrowserSession`.
  /// - Returns: The callback URL.
  /// - Throws: ``AuthorizationPresenterError/cancelled`` when the session
  ///   ends with no callback URL, ``AuthorizationPresenterError/failedToStart``
  ///   when the session does not start, and the error of the session for all
  ///   other failures.
  public func present(url: URL, callbackScheme: String, ephemeral: Bool) async throws -> URL {
    let session = factory.makeSession(url: url, callbackScheme: callbackScheme)
    session.prefersEphemeralWebBrowserSession = ephemeral
    session.presentationContextProvider = anchorProvider
    openSession = session
    defer {
      if openSession === session {
        openSession = nil
      }
    }
    do {
      return try await withTaskCancellationHandler {
        try await session.start()
      } onCancel: {
        Task { @MainActor [weak self] in
          self?.cancel()
        }
      }
    } catch let error as ASWebAuthenticationSessionError where error.code == .canceledLogin {
      throw AuthorizationPresenterError.cancelled
    } catch WebAuthSessionError.failedToStart {
      throw AuthorizationPresenterError.failedToStart
    }
  }

  /// Stops the open session. The waiting
  /// ``present(url:callbackScheme:ephemeral:)`` then throws
  /// ``AuthorizationPresenterError/cancelled``. When no session is open, the
  /// function does nothing.
  public func cancel() {
    openSession?.cancel()
  }
}

/// The object that gives a window to a web authentication session.
private final class WindowAnchorProvider: NSObject, ASWebAuthenticationPresentationContextProviding {
  /// The injected window, or `nil` to use the windows of the app.
  private weak var window: NSWindow?

  /// Makes a provider.
  ///
  /// - Parameter window: The injected window, or `nil`.
  init(window: NSWindow?) {
    self.window = window
  }

  /// Gives the injected window, else the key window, else the main window of
  /// the app.
  ///
  /// - Parameter session: The session that asks for the anchor.
  /// - Returns: The window that the session presents over.
  func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
    window ?? NSApp?.keyWindow ?? NSApp?.mainWindow ?? ASPresentationAnchor()
  }
}
