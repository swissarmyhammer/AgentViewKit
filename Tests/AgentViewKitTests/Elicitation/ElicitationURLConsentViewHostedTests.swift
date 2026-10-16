@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import SwiftUI
import Testing

/// Hosted tests of ``ElicitationURLConsentView``.
///
/// Each card test gets a URL mode `PendingElicitation` from the session model
/// of a ``ScriptedSession``, shows it in an ``ElicitationURLConsentView``, and
/// reads the response that the scripted agent receives.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationURLConsentViewHostedTests {
  /// The size of a hosted card.
  static let cardSize = CGSize(width: 520, height: 320)

  /// The size of a hosted request deck with two cards.
  static let hostSize = CGSize(width: 520, height: 800)

  /// The JSON-RPC id of the elicitation request of the agent.
  static let agentRequestID = 9

  /// The URL that the default request opens.
  static let defaultURL = "https://example.com/continue"

  /// The message of each request of the tests.
  static let message = "Sign in to continue."

  /// A URL whose host is Punycode, so that the card shows the URL and the
  /// warning.
  static let punycodeURL = "https://xn--pple-43d.com/login"

  /// The objects that a hosted card uses.
  struct Mounted {
    /// The harness of the card.
    let harness: HostedViewHarness<AnyView>
    /// The scripted session whose model holds the request.
    let session: ScriptedSession
    /// The browser sessions that record each call of the presenter.
    let browser: FakeWebAuthSession
    /// The recorder of each start and each stop of the browser task of the card.
    let browserSteps: ReportRecorder<ElicitationBrowserStep>

    /// Stops each waiting browser session, closes the harness, then stops the
    /// scripted agent.
    func close() {
      for session in browser.sessions where session.isWaiting {
        session.cancel()
      }
      harness.close()
      session.close()
    }

    /// The response frames that the agent received for the request.
    var responses: [JSONValue] {
      session.agent.received.filter {
        $0["method"] == nil && $0["id"] == .number(Double(ElicitationURLConsentViewHostedTests.agentRequestID))
      }
    }

    /// Calls ``ScriptedSession/resultOfAnsweredElicitation(ofRequest:sourceLocation:)``
    /// with ``ElicitationURLConsentViewHostedTests/agentRequestID``.
    ///
    /// - Parameter sourceLocation: The location of the caller, for the
    ///   failure report.
    /// - Returns: The `result` member of the response, or `nil` when the
    ///   response has no `result` member.
    /// - Throws: An issue when the model holds a pending elicitation.
    func result(sourceLocation: SourceLocation = #_sourceLocation) async throws -> JSONValue? {
      try await session.resultOfAnsweredElicitation(
        ofRequest: ElicitationURLConsentViewHostedTests.agentRequestID, sourceLocation: sourceLocation)
    }
  }

  /// The params of a URL mode elicitation of the scripted session.
  ///
  /// - Parameter url: The text of the location that the request opens.
  /// - Returns: The JSON text of the params.
  static func makeParams(url: String = defaultURL) -> String {
    #"""
    {"sessionId": "\#(ScriptedSession.sessionID)", "message": "\#(message)", "mode": "url",
     "url": "\#(url)", "elicitationId": "url-test"}
    """#
  }

  /// Gets a URL mode elicitation from the agent and shows its card with a
  /// presenter over fake browser sessions that wait until they are stopped.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - reporter: The reporter that records each focus move.
  /// - Returns: The mounted card.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no elicitation.
  static func mount(
    _ params: String = makeParams(),
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) async throws -> Mounted {
    let session = try await ScriptedSession.open()
    let pending = try await session.receiveElicitation(id: agentRequestID, params: params)
    let browser = FakeWebAuthSession(script: .waitsForCancel)
    let browserSteps = ReportRecorder<ElicitationBrowserStep>()
    let view = ElicitationURLConsentView(request: pending, owner: session.model)
      .environment(\.authorizationPresenter, AuthorizationPresenter(factory: browser))
      .environment(\.focusReporter, reporter)
      .environment(\.elicitationBrowserReport, browserSteps.report)
    let harness = HostedViewHarness(AnyView(view), size: cardSize)
    harness.render()
    return Mounted(harness: harness, session: session, browser: browser, browserSteps: browserSteps)
  }

  /// The URLs that the browser sessions of `browser` opened.
  static func openedURLs(_ browser: FakeWebAuthSession) -> [URL] {
    browser.calls.compactMap { call in
      guard case .makeSession(let url, _) = call else { return nil }
      return url
    }
  }

  /// Presses Open in Browser, waits for the answer and the session start,
  /// and makes one render pass.
  ///
  /// The scripted agent and the browser sessions are observable. The press
  /// accepts the request in the same step, so the function requires that the
  /// model holds no pending elicitation before the wait. Then the press is
  /// certain to send the answer and to start a session.
  static func open(_ mounted: Mounted) async throws {
    try mounted.harness.press(identifier: ElicitationURLConsentView.openIdentifier)
    try #require(mounted.session.model.pendingElicitations.isEmpty)
    await mounted.harness.render {
      !mounted.responses.isEmpty && mounted.browser.sessions.contains(where: \.isWaiting)
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

  @Test func theCardShowsTheAgentTheMessageAndTheURL() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    let labels = mounted.harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains(ElicitationHeader.title(server: ElicitationHeader.agentServer)))
    #expect(labels.contains(Self.message))
    let url = try #require(mounted.harness.element(identifier: ElicitationURLConsentView.urlIdentifier))
    // The static text has no title, so its label is its text value.
    #expect(url.label == Self.defaultURL)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.warningIdentifier) == nil)
  }

  @Test func aPunycodeHostShowsTheWarning() async throws {
    let mounted = try await Self.mount(Self.makeParams(url: Self.punycodeURL))
    defer { mounted.close() }

    let warning = try #require(
      mounted.harness.element(identifier: ElicitationURLConsentView.warningIdentifier))
    #expect(warning.label?.contains("Punycode") == true)
  }

  @Test func theURLUsesTheEditorFontOfTheEditorTheme() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let pending = try await session.receiveElicitation(id: Self.agentRequestID, params: Self.makeParams())

    try ThemeHeightExpectations.expectThemeIncreasesHeight(
      of: ElicitationURLConsentView(request: pending, owner: session.model),
      identifier: ElicitationURLConsentView.urlIdentifier, size: Self.cardSize)
  }

  @Test func theMinimumHeightOfTheCardIsNotMoreThanItsHeightAtTheCardWidth() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let pending = try await session.receiveElicitation(
      id: Self.agentRequestID, params: Self.makeParams(url: Self.punycodeURL))

    HostedLayoutExpectations.expectMinimumHeightFitsWidth(
      of: ElicitationURLConsentView(request: pending, owner: session.model), width: Self.cardSize.width)
  }

  @Test func theCardOpensNothingBeforeAPress() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    mounted.harness.render()

    #expect(mounted.browser.calls.isEmpty)
    #expect(mounted.responses.isEmpty)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) == nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) == nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.cancelIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.declineIdentifier) != nil)
  }

  /// A new card does not take the focus. The ``RequestDeck`` moves the focus.
  @Test func theCardMovesNoFocusOnAppear() async throws {
    let reporter = RecordingFocusReporter()
    let mounted = try await Self.mount(reporter: reporter)
    defer { mounted.close() }

    #expect(reporter.moves.isEmpty)
  }

  // MARK: - Actions

  @Test func openStartsOneBrowserSessionAcceptsAndWaits() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    try await Self.open(mounted)

    #expect(
      mounted.browser.calls == [
        .makeSession(
          url: try #require(URL(string: Self.defaultURL)),
          callbackScheme: ElicitationURLConsentView.callbackScheme),
        .start(ephemeral: false),
      ])
    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "accept"}"#)))
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.cancelIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.openIdentifier) == nil)
  }

  @Test func theButtonsBeforeThePressKeepTheirTextAsTheirLabels() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    let harness = mounted.harness

    harness.expectButton(identifier: ElicitationURLConsentView.cancelIdentifier, label: "Cancel")
    harness.expectButton(identifier: ElicitationURLConsentView.declineIdentifier, label: "Decline")
    harness.expectButton(identifier: ElicitationURLConsentView.openIdentifier, label: "Open in Browser")
  }

  @Test func retryKeepsItsAccessibilityLabel() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    mounted.harness.expectButton(
      identifier: ElicitationURLConsentView.retryIdentifier,
      label: "Open \(ElicitationHeader.agentServer) in the browser again")
  }

  @Test func retryOpensTheBrowserAgainWithNoSecondAnswer() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    try mounted.harness.press(identifier: ElicitationURLConsentView.retryIdentifier)
    // Retry starts the browser task in the same step as the press, so a press
    // that started nothing stops the test here.
    try #require(mounted.browserSteps.values == [.open, .open])
    await ObservationWait.until {
      Self.openedURLs(mounted.browser).count == 2 && mounted.browser.sessions.last?.isWaiting == true
    }

    #expect(Self.openedURLs(mounted.browser).count == 2)
    #expect(mounted.browser.sessions.first?.isWaiting == false)
    #expect(mounted.browser.sessions.last?.isWaiting == true)
    #expect(mounted.responses.count == 1)
  }

  @Test func cancelSendsCancel() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationURLConsentView.cancelIdentifier)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
    #expect(mounted.browser.calls.isEmpty)
  }

  @Test func cancelWhileWaitingStopsTheBrowserAndSendsNoSecondAnswer() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    try mounted.harness.press(identifier: ElicitationURLConsentView.cancelIdentifier)
    // Cancel stops the browser task in the same step as the press, so a press
    // that stopped nothing stops the test here.
    try #require(mounted.browserSteps.values == [.open, .stop])
    await ObservationWait.until { mounted.browser.calls.contains(.cancel) }

    #expect(mounted.browser.calls.last == .cancel)
    #expect(mounted.responses.count == 1)
    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "accept"}"#)))
  }

  @Test func declineSendsDecline() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationURLConsentView.declineIdentifier)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "decline"}"#)))
    #expect(mounted.browser.calls.isEmpty)
  }

  @Test func escapeSendsCancel() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    try mounted.harness.sendKey(.escape)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
  }

  // MARK: - Deck

  @Test func theDeckShowsTheConsentCardForAURLRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(RequestDeck(session: session.model), size: Self.hostSize)
    defer { harness.close() }

    // The client handles each request in its own task, so the test sends the
    // second request only after the model holds the first.
    let model = session.model
    try await session.sendRequest("elicitation/create", id: 1, params: Self.makeParams(url: "https://example.com/auth"))
    await ObservationWait.until { model.pendingElicitations.count == 1 }
    try await session.sendRequest("elicitation/create", id: 2, params: ScriptedSession.formElicitationParams)
    await harness.render { model.pendingElicitations.count == 2 }

    #expect(harness.element(identifier: ElicitationURLConsentView.identifier) != nil)
    #expect(harness.element(identifier: ElicitationURLConsentView.openIdentifier) != nil)
    // Only the front card is in the accessibility tree.
    #expect(harness.element(identifier: ElicitationView.formIdentifier) == nil)

    try harness.press(identifier: RequestDeck.nextIdentifier)

    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
  }
}
