import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ElicitationURLConsentView``.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationURLConsentViewHostedTests {
  /// The longest time that a test waits for a call, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// The size of a hosted card.
  static let cardSize = CGSize(width: 520, height: 320)

  /// The size of a hosted pending request host with two cards.
  static let hostSize = CGSize(width: 520, height: 800)

  /// The objects that a hosted card uses.
  struct Mounted {
    /// The harness of the card.
    let harness: HostedViewHarness<AnyView>
    /// The actions that record each answer.
    let actions: NoopThreadActions
    /// The browser sessions that record each call of the presenter.
    let browser: FakeWebAuthSession

    /// Stops each waiting browser session, then closes the harness.
    func close() {
      for session in browser.sessions where session.isWaiting {
        session.cancel()
      }
      harness.close()
    }
  }

  /// Makes a URL mode request.
  ///
  /// - Parameter url: The location that the request opens.
  /// - Returns: The request.
  static func request(url: URL) -> ElicitationRequest {
    ElicitationRequest(
      id: ElicitationRequestID("url-test"),
      server: "Payments",
      message: "Sign in to continue.",
      mode: .url(url, elicitationId: "url-test")
    )
  }

  /// Mounts a card with a presenter over fake browser sessions that wait
  /// until they are stopped.
  ///
  /// - Parameters:
  ///   - request: The request to show.
  ///   - reporter: The reporter that records each focus move.
  /// - Returns: The mounted card.
  static func mount(
    _ request: ElicitationRequest = ThreadFixtures.urlElicitationRequest(),
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) -> Mounted {
    let actions = NoopThreadActions()
    let browser = FakeWebAuthSession(script: .waitsForCancel)
    let view = ElicitationURLConsentView(request: request)
      .environment(\.threadActions, actions)
      .environment(\.authorizationPresenter, AuthorizationPresenter(factory: browser))
      .environment(\.focusReporter, reporter)
    let harness = HostedViewHarness(AnyView(view), size: cardSize)
    harness.pump()
    return Mounted(harness: harness, actions: actions, browser: browser)
  }

  /// The elicitation results that `actions` recorded.
  static func results(_ actions: NoopThreadActions) -> [ElicitationResult] {
    actions.calls.compactMap { call in
      guard case .respondToElicitation(_, let result) = call else { return nil }
      return result
    }
  }

  /// The URLs that the browser sessions of `browser` opened.
  static func openedURLs(_ browser: FakeWebAuthSession) -> [URL] {
    browser.calls.compactMap { call in
      guard case .makeSession(let url, _) = call else { return nil }
      return url
    }
  }

  /// Presses Open in Browser and waits for the answer and the session start.
  static func open(_ mounted: Mounted) async throws {
    try mounted.harness.press(identifier: ElicitationURLConsentView.openIdentifier)
    await mounted.harness.pump(until: callWaitSeconds) {
      !mounted.actions.calls.isEmpty && mounted.browser.sessions.contains(where: \.isWaiting)
    }
  }

  // MARK: - Identifiers

  @Test func theIdentifiersHaveTheDocumentedForm() {
    #expect(ElicitationURLConsentView.urlIdentifier == "elicitation-url")
    #expect(ElicitationURLConsentView.warningIdentifier == "elicitation-url-warning")
    #expect(ElicitationURLConsentView.openIdentifier == "elicitation-open")
    #expect(ElicitationURLConsentView.retryIdentifier == "elicitation-retry")
    #expect(ElicitationURLConsentView.cancelIdentifier == "elicitation-cancel")
    #expect(ElicitationURLConsentView.declineIdentifier == "elicitation-decline")
    #expect(ElicitationURLConsentView.waitingIdentifier == "elicitation-waiting")
  }

  // MARK: - Content

  @Test func theCardShowsTheServerTheMessageAndTheURL() throws {
    let request = ThreadFixtures.urlElicitationRequest()
    let mounted = Self.mount(request)
    defer { mounted.close() }

    let labels = mounted.harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(ElicitationHeader.title(server: request.server)))
    #expect(labels.contains(request.message))
    let url = try #require(mounted.harness.element(identifier: ElicitationURLConsentView.urlIdentifier))
    // The static text has no title, so its label is its text value.
    #expect(url.label == "https://example.com/continue")
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.warningIdentifier) == nil)
  }

  @Test func aPunycodeHostShowsTheWarning() throws {
    let request = Self.request(url: try #require(URL(string: "https://xn--pple-43d.com/login")))
    let mounted = Self.mount(request)
    defer { mounted.close() }

    let warning = try #require(
      mounted.harness.element(identifier: ElicitationURLConsentView.warningIdentifier))
    #expect(warning.label?.contains("Punycode") == true)
  }

  @Test func theCardOpensNothingBeforeAPress() {
    let mounted = Self.mount()
    defer { mounted.close() }
    mounted.harness.pump()

    #expect(mounted.browser.calls.isEmpty)
    #expect(mounted.actions.calls.isEmpty)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) == nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) == nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.cancelIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.declineIdentifier) != nil)
  }

  @Test func theCardReportsTheFocusOnAppear() {
    let reporter = RecordingFocusReporter()
    let mounted = Self.mount(reporter: reporter)
    defer { mounted.close() }

    #expect(reporter.moves == [ElicitationURLConsentView.identifier])
  }

  // MARK: - Actions

  @Test func openStartsOneBrowserSessionAcceptsAndWaits() async throws {
    let request = ThreadFixtures.urlElicitationRequest()
    let mounted = Self.mount(request)
    defer { mounted.close() }

    try await Self.open(mounted)

    #expect(
      mounted.browser.calls == [
        .makeSession(
          url: try #require(URL(string: "https://example.com/continue")),
          callbackScheme: ElicitationURLConsentView.callbackScheme),
        .start(ephemeral: false),
      ])
    #expect(Self.results(mounted.actions) == [.accept(nil)])
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.cancelIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.openIdentifier) == nil)
  }

  @Test func retryOpensTheBrowserAgainWithNoSecondAnswer() async throws {
    let mounted = Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    try mounted.harness.press(identifier: ElicitationURLConsentView.retryIdentifier)
    await mounted.harness.pump(until: Self.callWaitSeconds) {
      Self.openedURLs(mounted.browser).count == 2 && mounted.browser.sessions.last?.isWaiting == true
    }

    #expect(Self.openedURLs(mounted.browser).count == 2)
    #expect(mounted.browser.sessions.first?.isWaiting == false)
    #expect(mounted.browser.sessions.last?.isWaiting == true)
    #expect(Self.results(mounted.actions) == [.accept(nil)])
  }

  @Test func cancelSendsCancel() async throws {
    let mounted = Self.mount()
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationURLConsentView.cancelIdentifier)
    await mounted.harness.pump(until: Self.callWaitSeconds) { !mounted.actions.calls.isEmpty }

    #expect(Self.results(mounted.actions) == [.cancel])
    #expect(mounted.browser.calls.isEmpty)
  }

  @Test func cancelWhileWaitingStopsTheBrowserAndSendsCancel() async throws {
    let mounted = Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    try mounted.harness.press(identifier: ElicitationURLConsentView.cancelIdentifier)
    await mounted.harness.pump(until: Self.callWaitSeconds) {
      Self.results(mounted.actions).count == 2 && mounted.browser.calls.contains(.cancel)
    }

    #expect(Self.results(mounted.actions) == [.accept(nil), .cancel])
    #expect(mounted.browser.calls.last == .cancel)
  }

  @Test func declineSendsDecline() async throws {
    let mounted = Self.mount()
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationURLConsentView.declineIdentifier)
    await mounted.harness.pump(until: Self.callWaitSeconds) { !mounted.actions.calls.isEmpty }

    #expect(Self.results(mounted.actions) == [.decline])
    #expect(mounted.browser.calls.isEmpty)
  }

  @Test func escapeSendsCancel() async throws {
    let mounted = Self.mount()
    defer { mounted.close() }

    try mounted.harness.sendKey(.escape)
    await mounted.harness.pump(until: Self.callWaitSeconds) { !mounted.actions.calls.isEmpty }

    #expect(Self.results(mounted.actions) == [.cancel])
  }

  // MARK: - Host

  @Test func thePendingHostShowsTheConsentCardForAURLRequest() {
    let thread = AgentThread()
    thread.apply(.addElicitation(ThreadFixtures.urlElicitationRequest(id: "url-1")))
    thread.apply(.addElicitation(ThreadFixtures.formElicitationRequest(id: "form-1")))
    let harness = HostedViewHarness(PendingRequestsHost(thread: thread), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ElicitationURLConsentView.identifier) != nil)
    #expect(harness.element(identifier: ElicitationURLConsentView.openIdentifier) != nil)
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }
}
