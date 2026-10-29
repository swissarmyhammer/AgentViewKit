@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommandsUI
import EditorTestSupport
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

  /// The JSON-RPC id of the form elicitation that waits behind the URL
  /// request in the deck tests.
  static let formRequestID = 10

  /// The `elicitationId` of each URL request of the tests.
  static let elicitationID = "url-test"

  /// The URL that the default request opens.
  static let defaultURL = "https://example.com/continue"

  /// The host of ``defaultURL``.
  static let defaultHost = "example.com"

  /// The text of the waiting step of a card for ``defaultURL``.
  static let waitingText = "Waiting for \(defaultHost) to finish"

  /// The `elicitation/complete` notification of the agent for
  /// ``elicitationID``.
  static let completeFrame = #"""
    {"jsonrpc": "2.0", "method": "elicitation/complete", "params": {"elicitationId": "\#(elicitationID)"}}
    """#

  /// The message of each request of the tests.
  static let message = "Sign in to continue."

  /// A URL whose host is Punycode, so that the card shows the URL and the
  /// warning.
  static let punycodeURL = "https://xn--pple-43d.com/login"

  /// A URL with no host, so that the waiting step names the agent.
  static let hostlessURL = "urn:example:continue"

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
     "url": "\#(url)", "elicitationId": "\#(elicitationID)"}
    """#
  }

  /// The URL mode elicitation of ``makeParams(url:)`` with the default URL,
  /// with the id ``agentRequestID``.
  static let urlRequest = ScriptedSession.AgentRequest(
    method: ScriptedSession.elicitationMethod, id: agentRequestID, params: makeParams())

  /// Gets a URL mode elicitation from the agent and shows its card with a
  /// presenter over fake browser sessions.
  ///
  /// - Parameters:
  ///   - params: The JSON text of the params of the request.
  ///   - script: The result of each browser session. The default sessions
  ///     wait until they are stopped.
  ///   - reporter: The reporter that records each focus move.
  /// - Returns: The mounted card.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no elicitation.
  static func mount(
    _ params: String = makeParams(),
    browser script: FakeWebAuthSession.Script = .waitsForCancel,
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) async throws -> Mounted {
    let session = try await ScriptedSession.open()
    let pending = try await session.receiveElicitation(id: agentRequestID, params: params)
    return mount(
      ElicitationURLConsentView(request: pending, owner: session.model), of: session, size: cardSize,
      browser: script, reporter: reporter)
  }

  /// Gets the URL mode elicitation of ``makeParams(url:)`` from the agent and
  /// shows its card under a header override. The override shows
  /// "Banner for <message>" with the identifier
  /// ``ElicitationViewHostedTests/customHeaderIdentifier``.
  ///
  /// - Returns: The mounted card.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no elicitation.
  static func mountWithCustomHeader() async throws -> Mounted {
    let session = try await ScriptedSession.open()
    let pending = try await session.receiveElicitation(id: agentRequestID, params: makeParams())
    let card = ElicitationURLConsentView(request: pending, owner: session.model)
      .elicitationHeader { pending in
        Text("Banner for \(pending.request.message)")
          .accessibilityIdentifier(ElicitationViewHostedTests.customHeaderIdentifier)
      }
    return mount(card, of: session, size: cardSize)
  }

  /// Gets each of `requests` from the agent, in order, and shows them in the
  /// ``RequestDeck`` of the session, with a presenter over fake browser
  /// sessions that wait until they are stopped.
  ///
  /// - Parameters:
  ///   - requests: The requests of the agent.
  ///   - reporter: The reporter that records each focus move.
  /// - Returns: The mounted deck.
  /// - Throws: The error of the transport.
  static func mountDeck(
    _ requests: [ScriptedSession.AgentRequest], reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) async throws -> Mounted {
    let session = try await ScriptedSession.open()
    try await session.sendInOrder(requests)
    return mount(RequestDeck(session: session.model), of: session, size: hostSize, reporter: reporter)
  }

  /// Shows `view` with a presenter over fake browser sessions, and makes one
  /// render pass.
  ///
  /// - Parameters:
  ///   - view: The card or the deck.
  ///   - session: The scripted session whose model holds the requests.
  ///   - size: The size of the harness.
  ///   - script: The result of each browser session. The default sessions
  ///     wait until they are stopped.
  ///   - reporter: The reporter that records each focus move.
  /// - Returns: The mounted view.
  static func mount(
    _ view: some View, of session: ScriptedSession, size: CGSize,
    browser script: FakeWebAuthSession.Script = .waitsForCancel,
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) -> Mounted {
    let browser = FakeWebAuthSession(script: script)
    let browserSteps = ReportRecorder<ElicitationBrowserStep>()
    let content = view
      .environment(\.authorizationPresenter, AuthorizationPresenter(factory: browser))
      .environment(\.focusReporter, reporter)
      .environment(\.elicitationBrowserReport, browserSteps.report)
    let harness = HostedViewHarness(AnyView(content), size: size)
    harness.render()
    return Mounted(harness: harness, session: session, browser: browser, browserSteps: browserSteps)
  }

  /// Presses Open in Browser in a deck, and waits until the browser session
  /// of the card waits.
  ///
  /// The press accepts the request and starts the browser task in the same
  /// step, and the render pass after it keeps the card in the deck. The
  /// function requires each of these before the wait, so a broken path
  /// stops the test at once. Then the browser session is certain to start.
  ///
  /// - Parameter mounted: The mounted deck.
  /// - Throws: An issue when the press did not accept the request, did not
  ///   start the browser task, or removed the card.
  static func openInDeck(_ mounted: Mounted) async throws {
    try await press(ElicitationURLConsentView.openIdentifier, in: mounted) {
      try #require(mounted.browserSteps.values == [.open])
      try #require(mounted.session.model.awaitingURLCompletions.count == 1)
      mounted.harness.render()
      // A deck that removes the card of an accepted request stops the test here.
      try #require(mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) != nil)
    } until: {
      mounted.browser.sessions.contains(where: \.isWaiting)
    }
  }

  /// Presses the button with `identifier`, runs the checks that hold right
  /// after the press, then waits until `condition` is `true` and makes one
  /// render pass.
  ///
  /// A press of Open in Browser, Retry or Cancel changes the model and starts
  /// or stops the browser task in the same step, so `requirements` read the
  /// state of that step. A check that fails stops the test before the wait,
  /// so a broken path does not hang the wait, which has no time limit.
  /// `requirements` has no default, so each press names the checks that
  /// prove it started the work that `condition` waits for.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier of the button.
  ///   - mounted: The mounted card or deck.
  ///   - requirements: The `#require` checks that hold after the press.
  ///   - condition: The condition on observable values to wait for.
  /// - Throws: The error of the press, or the issue of a check of
  ///   `requirements` that fails.
  static func press(
    _ identifier: String,
    in mounted: Mounted,
    requiring requirements: () throws -> Void,
    until condition: @MainActor () -> Bool
  ) async throws {
    try mounted.harness.press(identifier: identifier)
    try requirements()
    await mounted.harness.render(when: condition)
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
    try await press(ElicitationURLConsentView.openIdentifier, in: mounted) {
      try #require(mounted.session.model.pendingElicitations.isEmpty)
    } until: {
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
    #expect(RequestDeck.waitingIdentifier == "request-deck-waiting")
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

  /// The waiting card and the tool call status read the host from
  /// `PendingElicitation.waitingHostName`.
  @Test func theWaitingHostNameIsTheHostOfTheURLOrTheAgent() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let withHost = try await session.receiveElicitation(id: Self.agentRequestID, params: Self.makeParams())
    session.model.cancelElicitation(withHost.id)
    let withoutHost = try await session.receiveElicitation(
      id: Self.formRequestID, params: Self.makeParams(url: Self.hostlessURL))

    #expect(withHost.waitingHostName == Self.defaultHost)
    #expect(withoutHost.waitingHostName == ElicitationHeader.agentServer)
  }

  @Test func theURLDrawsInTheCodeRole() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let pending = try await session.receiveElicitation(id: Self.agentRequestID, params: Self.makeParams())

    try FontRoleExpectations.expectText(
      of: ElicitationURLConsentView(request: pending, owner: session.model),
      identifier: ElicitationURLConsentView.urlIdentifier, drawsIn: .code, size: Self.cardSize)
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

  // MARK: - Header override

  /// The header override of the app replaces the header of a URL card, as it
  /// replaces the header of a form card.
  @Test func aHeaderOverrideReplacesTheHeaderOfTheConsentState() async throws {
    let mounted = try await Self.mountWithCustomHeader()
    defer { mounted.close() }
    let harness = mounted.harness

    #expect(
      harness.element(identifier: ElicitationViewHostedTests.customHeaderIdentifier)?.label
        == "Banner for \(Self.message)")
    #expect(harness.element(identifier: ElicitationView.headerIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationURLConsentView.openIdentifier) != nil)
  }

  /// The waiting state shows the same header override as the consent state.
  @Test func aHeaderOverrideReplacesTheHeaderOfTheWaitingState() async throws {
    let mounted = try await Self.mountWithCustomHeader()
    defer { mounted.close() }
    try await Self.open(mounted)
    let harness = mounted.harness

    #expect(harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
    #expect(
      harness.element(identifier: ElicitationViewHostedTests.customHeaderIdentifier)?.label
        == "Banner for \(Self.message)")
    #expect(harness.element(identifier: ElicitationView.headerIdentifier) == nil)
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
    #expect(mounted.session.model.awaitingURLCompletions.map(\.elicitationId?.rawValue) == [Self.elicitationID])
    #expect(
      mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.cancelIdentifier) != nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.declineIdentifier) == nil)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.openIdentifier) == nil)
  }

  /// In the waiting state, the button that stops the wait is a Cancel button
  /// with the identifier of the Cancel button of the consent state.
  @Test func cancelWhileWaitingKeepsItsTextAsItsLabel() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    mounted.harness.expectButton(identifier: ElicitationURLConsentView.cancelIdentifier, label: "Cancel")
  }

  /// The card reads the waiting step from the model. Thus a card that mounts
  /// again for an accepted request shows the waiting step and no consent
  /// buttons.
  @Test func aNewCardForAnAcceptedRequestShowsTheWaitingStep() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)
    let accepted = try #require(mounted.session.model.awaitingURLCompletions.first)

    let harness = HostedViewHarness(
      ElicitationURLConsentView(request: accepted, owner: mounted.session.model), size: Self.cardSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
    #expect(harness.element(identifier: ElicitationURLConsentView.openIdentifier) == nil)
    #expect(harness.element(identifier: ElicitationURLConsentView.declineIdentifier) == nil)
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

    try await Self.press(ElicitationURLConsentView.retryIdentifier, in: mounted) {
      // Retry starts the browser task in the same step as the press, so a
      // press that started nothing stops the test here.
      try #require(mounted.browserSteps.values == [.open, .open])
    } until: {
      Self.openedURLs(mounted.browser).count == 2 && mounted.browser.sessions.last?.isWaiting == true
    }

    #expect(Self.openedURLs(mounted.browser).count == 2)
    #expect(mounted.browser.sessions.first?.isWaiting == false)
    #expect(mounted.browser.sessions.last?.isWaiting == true)
    #expect(mounted.responses.count == 1)
  }

  /// Presses Open in Browser, and waits until the browser session of the
  /// card ends.
  ///
  /// - Parameter mounted: The mounted card, whose browser sessions end at
  ///   once.
  /// - Throws: An issue when the press did not accept the request.
  static func openAndWaitForTheEndOfTheSession(_ mounted: Mounted) async throws {
    try await press(ElicitationURLConsentView.openIdentifier, in: mounted) {
      try #require(mounted.session.model.awaitingURLCompletions.count == 1)
    } until: {
      mounted.browser.calls.contains(.start(ephemeral: false))
    }
    mounted.harness.render()
  }

  /// Presses Open in Browser, waits until the card records that its browser
  /// session did not open, and makes one render pass.
  ///
  /// - Parameter mounted: The mounted card, whose browser sessions do not
  ///   start.
  /// - Throws: An issue when the press did not start the browser task.
  static func openAndWaitForTheFailureOfTheBrowser(_ mounted: Mounted) async throws {
    try await press(ElicitationURLConsentView.openIdentifier, in: mounted) {
      try #require(mounted.browserSteps.values == [.open])
    } until: {
      mounted.browserSteps.values.contains(.failed)
    }
  }

  /// A browser session that does not open keeps the waiting state, and the
  /// card says that the browser did not open, so that the user presses Retry.
  @Test func aBrowserThatDoesNotOpenShowsItsFailureInTheWaitingState() async throws {
    let mounted = try await Self.mount(browser: .failsToStart)
    defer { mounted.close() }

    try await Self.openAndWaitForTheFailureOfTheBrowser(mounted)

    #expect(
      mounted.harness.element(identifier: ElicitationURLConsentView.browserFailureIdentifier)?.label
        == ElicitationURLConsentView.browserFailureMessage)
    #expect(
      mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.retryIdentifier) != nil)
  }

  /// Retry opens the browser again, and the card no longer shows the
  /// failure of the browser session before it.
  @Test func retryClearsTheFailureOfTheBrowser() async throws {
    let mounted = try await Self.mount(browser: .failsToStart)
    defer { mounted.close() }
    try await Self.openAndWaitForTheFailureOfTheBrowser(mounted)
    try #require(mounted.harness.element(identifier: ElicitationURLConsentView.browserFailureIdentifier) != nil)
    mounted.browser.script = .waitsForCancel

    try await Self.press(ElicitationURLConsentView.retryIdentifier, in: mounted) {
      // Retry starts the browser task in the same step as the press, so a
      // press that started nothing stops the test here.
      try #require(mounted.browserSteps.values == [.open, .failed, .open])
    } until: {
      mounted.browser.sessions.last?.isWaiting == true
    }

    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.browserFailureIdentifier) == nil)
  }

  /// A browser that the user closes is no failure: the card shows only the
  /// waiting state.
  @Test func aClosedBrowserShowsNoFailure() async throws {
    let mounted = try await Self.mount(browser: .cancelled)
    defer { mounted.close() }

    try await Self.openAndWaitForTheEndOfTheSession(mounted)

    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.browserFailureIdentifier) == nil)
    #expect(
      mounted.harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
  }

  @Test func cancelSendsCancel() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }

    try mounted.harness.press(identifier: ElicitationURLConsentView.cancelIdentifier)

    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "cancel"}"#)))
    #expect(mounted.browser.calls.isEmpty)
  }

  @Test func escapeWhileWaitingStopsTheBrowserAndTheWait() async throws {
    let mounted = try await Self.mount()
    defer { mounted.close() }
    try await Self.open(mounted)

    try mounted.harness.sendKey(.escape)
    // Esc stops the browser task and the wait in the same step as the key, so
    // a key that stopped nothing stops the test here.
    try #require(mounted.browserSteps.values == [.open, .stop])
    try #require(mounted.session.model.awaitingURLCompletions.isEmpty)
    await ObservationWait.until { mounted.browser.calls.contains(.cancel) }

    #expect(mounted.browser.calls.last == .cancel)
    #expect(mounted.responses.count == 1)
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

  // MARK: - Deck waiting state (task 41)

  /// The accept keeps the card in the deck, so the browser session of the
  /// card does not stop (bug card ^rkwj84j).
  @Test func openInTheDeckKeepsTheBrowserSessionAndBringsTheNextCardToTheFront() async throws {
    let mounted = try await Self.mountDeck([Self.urlRequest, .formElicitation(id: Self.formRequestID)])
    defer { mounted.close() }

    try await Self.openInDeck(mounted)

    let harness = mounted.harness
    #expect(harness.element(identifier: ElicitationURLConsentView.waitingIdentifier)?.label == Self.waitingText)
    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
    #expect(harness.element(identifier: RequestDeck.waitingIdentifier)?.label == "1 waiting")
    #expect(harness.element(identifier: RequestDeck.positionIdentifier) == nil)
    #expect(mounted.browserSteps.values == [.open])
    #expect(!mounted.browser.calls.contains(.cancel))
  }

  @Test func aCompleteFromTheAgentRemovesTheWaitingCardAndStopsTheBrowser() async throws {
    let mounted = try await Self.mountDeck([Self.urlRequest])
    defer { mounted.close() }
    let model = mounted.session.model
    try await Self.openInDeck(mounted)

    try await mounted.session.agent.send(Self.completeFrame)
    await ObservationWait.until { model.awaitingURLCompletions.isEmpty }
    mounted.harness.render()
    // The card stops its browser task when it goes away, in the same render
    // pass, so a card that stayed or stopped nothing stops the test here.
    try #require(mounted.browserSteps.values == [.open, .stop])
    await ObservationWait.until { mounted.browser.calls.contains(.cancel) }

    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.identifier) == nil)
    #expect(mounted.harness.element(identifier: RequestDeck.waitingIdentifier) == nil)
    #expect(mounted.responses.count == 1)
  }

  @Test func cancelWhileWaitingRemovesTheCardStopsTheBrowserAndSendsNoSecondAnswer() async throws {
    let mounted = try await Self.mountDeck([Self.urlRequest])
    defer { mounted.close() }
    let model = mounted.session.model
    try await Self.openInDeck(mounted)

    try await Self.press(ElicitationURLConsentView.cancelIdentifier, in: mounted) {
      // Cancel in the waiting state stops the browser task and the wait in
      // the same step as the press, so a press that stopped nothing stops
      // the test here.
      try #require(mounted.browserSteps.values == [.open, .stop])
      try #require(model.awaitingURLCompletions.isEmpty)
    } until: {
      mounted.browser.calls.contains(.cancel)
    }

    #expect(mounted.harness.element(identifier: ElicitationURLConsentView.identifier) == nil)
    #expect(mounted.responses.count == 1)
    #expect(try await mounted.result() == (try JSONValue(json: #"{"action": "accept"}"#)))
  }
}
