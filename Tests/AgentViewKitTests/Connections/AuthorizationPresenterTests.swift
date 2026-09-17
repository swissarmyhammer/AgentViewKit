import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import AuthenticationServices
import Foundation
import Testing

@Suite(.hostedSerially) @MainActor struct AuthorizationPresenterTests {
  static let authorizationURL = URL(string: "https://auth.example.com/authorize")!
  static let callbackURL = URL(string: "agentviewkit://callback?code=1")!
  static let callbackScheme = "agentviewkit"

  // MARK: - Result

  @Test func presentReturnsTheCallbackURL() async throws {
    let factory = FakeWebAuthSession(script: .callback(Self.callbackURL))
    let presenter = AuthorizationPresenter(factory: factory)

    let url = try await presenter.present(
      url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)

    #expect(url == Self.callbackURL)
    #expect(
      factory.calls == [
        .makeSession(url: Self.authorizationURL, callbackScheme: Self.callbackScheme),
        .start(ephemeral: false),
      ])
    #expect(!presenter.isPresenting)
  }

  @Test func presentThrowsCancelledWhenTheSessionEndsWithNoCallback() async {
    let factory = FakeWebAuthSession(script: .cancelled)
    let presenter = AuthorizationPresenter(factory: factory)

    await #expect(throws: AuthorizationPresenterError.cancelled) {
      try await presenter.present(
        url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)
    }
    #expect(!presenter.isPresenting)
  }

  @Test func presentThrowsFailedToStartWhenTheSessionDoesNotStart() async {
    let factory = FakeWebAuthSession(script: .failsToStart)
    let presenter = AuthorizationPresenter(factory: factory)

    await #expect(throws: AuthorizationPresenterError.failedToStart) {
      try await presenter.present(
        url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)
    }
    #expect(!presenter.isPresenting)
  }

  // MARK: - Session settings

  @Test func ephemeralSetsTheSessionPreference() async throws {
    let factory = FakeWebAuthSession(script: .callback(Self.callbackURL))
    let presenter = AuthorizationPresenter(factory: factory)

    _ = try await presenter.present(
      url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: true)

    #expect(factory.calls.last == .start(ephemeral: true))
    let session = try #require(factory.sessions.first)
    #expect(session.prefersEphemeralWebBrowserSession)
  }

  @Test func theSessionAnchorIsTheInjectedWindow() async throws {
    let window = NSWindow()
    let factory = FakeWebAuthSession(script: .callback(Self.callbackURL))
    let presenter = AuthorizationPresenter(factory: factory, anchor: window)

    _ = try await presenter.present(
      url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)

    let session = try #require(factory.sessions.first)
    let provider = try #require(session.presentationContextProvider)
    let systemSession = ASWebAuthenticationSession(
      url: Self.authorizationURL, callback: .customScheme(Self.callbackScheme)
    ) { _, _ in }
    #expect(provider.presentationAnchor(for: systemSession) === window)
  }

  // MARK: - Cancel

  @Test func cancelStopsTheOpenSession() async throws {
    let factory = FakeWebAuthSession(script: .waitsForCancel)
    let presenter = AuthorizationPresenter(factory: factory)

    let present = Task {
      try await presenter.present(
        url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)
    }
    try await waitUntilTheSessionWaits(factory)
    #expect(presenter.isPresenting)
    presenter.cancel()

    await #expect(throws: AuthorizationPresenterError.cancelled) {
      try await present.value
    }
    #expect(factory.calls.last == .cancel)
    #expect(!presenter.isPresenting)
  }

  @Test func taskCancellationStopsTheOpenSession() async throws {
    let factory = FakeWebAuthSession(script: .waitsForCancel)
    let presenter = AuthorizationPresenter(factory: factory)

    let present = Task {
      try await presenter.present(
        url: Self.authorizationURL, callbackScheme: Self.callbackScheme, ephemeral: false)
    }
    try await waitUntilTheSessionWaits(factory)
    present.cancel()

    await #expect(throws: AuthorizationPresenterError.cancelled) {
      try await present.value
    }
    #expect(factory.calls.last == .cancel)
  }

  @Test func cancelWithNoOpenSessionDoesNothing() {
    let factory = FakeWebAuthSession(script: .cancelled)
    let presenter = AuthorizationPresenter(factory: factory)

    presenter.cancel()

    #expect(factory.calls.isEmpty)
    #expect(!presenter.isPresenting)
  }

  // MARK: - Default factory

  @Test func theDefaultFactoryMakesASystemSession() {
    let factory = SystemWebAuthSessionFactory()

    let session = factory.makeSession(url: Self.authorizationURL, callbackScheme: Self.callbackScheme)
    session.prefersEphemeralWebBrowserSession = true

    #expect(session is SystemWebAuthSession)
    #expect(session.prefersEphemeralWebBrowserSession)
    #expect(session.presentationContextProvider == nil)
  }

  @Test func aSystemSessionThatIsCancelledBeforeStartThrowsCancelled() async {
    let session = SystemWebAuthSession(url: Self.authorizationURL, callbackScheme: Self.callbackScheme)

    session.cancel()

    await #expect(throws: ASWebAuthenticationSessionError(.canceledLogin)) {
      try await session.start()
    }
  }

  // MARK: - Helpers

  /// Waits until the first session of `factory` waits for a cancel.
  ///
  /// - Parameter factory: The factory that made the session.
  private func waitUntilTheSessionWaits(_ factory: FakeWebAuthSession) async throws {
    while factory.sessions.first?.isWaiting != true {
      try #require(!Task.isCancelled)
      await Task.yield()
    }
  }
}
