import AgentViewKit
import AgentViewKitRouter
import AgentViewKitTestSupport
import Foundation
import FoundationModelsExtras
import FoundationModelsRouter
import Testing

/// The callback URL that the fake browser session gives.
private let callbackURL = URL(string: "agentviewkit://done")!

/// A failure of a prompt stream.
private struct PromptFailure: Error, CustomStringConvertible {
  var description: String { "The model is not ready" }
}

/// The session, the source, the actions, and the fake browser of one test.
@MainActor
private struct Harness {
  let session = FakeRouterSession()
  let browser = FakeWebAuthSession(script: .callback(callbackURL))
  let source: RouterThreadSource
  let actions: RouterThreadActions

  init() {
    source = RouterThreadSource(port: session)
    actions = RouterThreadActions(source: source, presenter: AuthorizationPresenter(factory: browser))
  }
}

/// The kit request of the form fixture.
@MainActor
private func formRequest() throws -> AgentViewKit.ElicitationRequest {
  let thread = AgentThread()
  let event = SessionEvent.elicitationRequested(try RouterFixtures.formElicitation())
  for change in SessionEventMapping.changes(for: event) {
    thread.apply(change)
  }
  return try #require(thread.pendingElicitations.first)
}

/// An authorization request with the meta values.
private func authorizationRequest(meta: AgentViewKit.JSONValue?) -> AuthorizationRequest {
  AuthorizationRequest(
    id: AuthorizationRequestID("auth-1"),
    serverName: "GitHub",
    authorizationURL: RouterFixtures.url,
    meta: meta
  )
}

/// One test for each verb of ``RouterThreadActions``.
@MainActor
@Suite struct RouterThreadActionsTests {
  @Test func sendAddsTheUserMessageAndStreamsTheTextOfTheTurn() async throws {
    let harness = Harness()
    harness.session.promptScript = [
      .turnStarted(RouterFixtures.turnStart),
      .textDelta("Hi "),
      .textDelta("there"),
      .turnEnded(RouterFixtures.usage),
    ]
    await harness.actions.send(UserInput(text: "Hello"))
    #expect(harness.session.calls == [.promptEvents("Hello")])
    let thread = harness.source.thread
    #expect(thread.items.map(\.id) == ["user-1", "provisional-1"])
    guard case .userMessage(let message)? = thread.item(id: "user-1") else {
      Issue.record("Expected a user message")
      return
    }
    #expect(message.blocks == [ContentBlock(text: "Hello")])
    let stream = try #require(thread.streaming["provisional-1"])
    stream.flush()
    #expect(stream.text == "Hi there")
    #expect(thread.state == .running)
  }

  @Test func sendReportsAFailedTurnAsAnError() async throws {
    let harness = Harness()
    harness.session.promptError = PromptFailure()
    await harness.actions.send(UserInput(text: "Hello"))
    let thread = harness.source.thread
    guard case .error(let error)? = thread.item(id: "error-1") else {
      Issue.record("Expected an error item")
      return
    }
    #expect(error.kind == .unknown(message: "The model is not ready"))
    #expect(thread.state == .idle(nil))
  }

  @Test func sendIgnoresACancelledTurn() async {
    let harness = Harness()
    harness.session.promptError = CancellationError()
    await harness.actions.send(UserInput(text: "Hello"))
    #expect(harness.source.thread.items.map(\.id) == ["user-1"])
  }

  @Test func cancelStopsTheCurrentTurn() async {
    let harness = Harness()
    await harness.actions.cancel()
    #expect(harness.session.calls == [.cancelCurrentTurn])
  }

  @Test func respondToAFormElicitationSendsTheAnswerWithTheSameID() async throws {
    let harness = Harness()
    harness.source.apply(.elicitationRequested(try RouterFixtures.formElicitation()))
    let request = try #require(harness.source.thread.pendingElicitations.first)
    await harness.actions.respond(to: request, .accept(.object(["name": .string("a.swift")])))
    #expect(
      harness.session.calls == [
        .respond(
          elicitationId: RouterFixtures.elicitationId.ulidString,
          response: .accept(content: ["name": .string("a.swift")])
        )
      ])
    #expect(harness.source.thread.pendingElicitations.isEmpty)
  }

  @Test func acceptOfAURLElicitationSendsTheAcceptAndThenCompletes() async throws {
    let harness = Harness()
    harness.source.apply(.elicitationRequested(RouterFixtures.urlElicitation()))
    let request = try #require(harness.source.thread.pendingElicitations.first)
    await harness.actions.respond(to: request, .accept(nil))
    let id = RouterFixtures.elicitationId.ulidString
    #expect(
      harness.session.calls == [
        .respond(elicitationId: id, response: .accept(content: nil)), .complete(elicitationId: id),
      ])
    #expect(harness.source.thread.pendingElicitations.isEmpty)
    #expect(harness.browser.calls.isEmpty)
  }

  @Test func cancelOfAURLElicitationSendsTheCancelOnly() async throws {
    let harness = Harness()
    harness.source.apply(.elicitationRequested(RouterFixtures.urlElicitation()))
    let request = try #require(harness.source.thread.pendingElicitations.first)
    await harness.actions.respond(to: request, .cancel)
    let id = RouterFixtures.elicitationId.ulidString
    #expect(harness.session.calls == [.respond(elicitationId: id, response: .cancel)])
  }

  @Test func declineOfAFormElicitationSendsTheDecline() async throws {
    let harness = Harness()
    await harness.actions.respond(to: try formRequest(), .decline)
    #expect(
      harness.session.calls == [
        .respond(elicitationId: RouterFixtures.elicitationId.ulidString, response: .decline)
      ])
  }

  @Test func connectPresentsTheURLOneTimeAndThenCompletesTheMetaID() async throws {
    let harness = Harness()
    let request = authorizationRequest(meta: .object(["elicitationId": .string("E1")]))
    harness.source.thread.apply(.addAuthorization(request))
    try await harness.actions.connect(request)
    #expect(
      harness.browser.calls == [
        .makeSession(url: RouterFixtures.url, callbackScheme: RouterThreadActions.defaultCallbackScheme),
        .start(ephemeral: false),
      ])
    #expect(
      harness.session.calls == [
        .respond(elicitationId: "E1", response: .accept(content: nil)), .complete(elicitationId: "E1"),
      ])
    #expect(harness.source.thread.pendingAuthorizations.isEmpty)
  }

  @Test func connectUsesTheCallbackSchemeOfTheMeta() async throws {
    let harness = Harness()
    let request = authorizationRequest(
      meta: .object(["elicitationId": .string("E1"), "callbackScheme": .string("myapp")]))
    try await harness.actions.connect(request)
    #expect(harness.browser.calls.first == .makeSession(url: RouterFixtures.url, callbackScheme: "myapp"))
  }

  @Test func connectWithNoElicitationIDThrowsAndOpensNothing() async {
    let harness = Harness()
    let request = authorizationRequest(meta: nil)
    await #expect(throws: RouterThreadActionsError.missingElicitationId(request.id)) {
      try await harness.actions.connect(request)
    }
    #expect(harness.browser.calls.isEmpty)
    #expect(harness.session.calls.isEmpty)
  }

  @Test func connectThatTheUserCancelsCompletesNothing() async {
    let harness = Harness()
    harness.browser.script = .cancelled
    let request = authorizationRequest(meta: .object(["elicitationId": .string("E1")]))
    await #expect(throws: AuthorizationPresenterError.cancelled) {
      try await harness.actions.connect(request)
    }
    #expect(harness.session.calls.isEmpty)
  }

  @Test func respondToAPermissionDoesNothing() async {
    let harness = Harness()
    await harness.actions.respond(
      to: ThreadFixtures.permissionRequest(), PermissionDecision(outcome: .cancelled))
    #expect(harness.session.calls.isEmpty)
  }

  @Test func setConfigOptionDoesNothing() async {
    let harness = Harness()
    await harness.actions.setConfigOption(ConfigOptionID("mode"), .boolean(true))
    #expect(harness.session.calls.isEmpty)
  }

  @Test func loginDoesNothing() async throws {
    let harness = Harness()
    try await harness.actions.login(AuthMethodID("agent"))
    #expect(harness.session.calls.isEmpty)
  }

  @Test func runTerminalAuthDoesNothing() async throws {
    let harness = Harness()
    try await harness.actions.runTerminalAuth(AuthMethod.Terminal(id: AuthMethodID("term"), name: "Terminal"))
    #expect(harness.session.calls.isEmpty)
  }

  @Test func logoutDoesNothing() async throws {
    let harness = Harness()
    try await harness.actions.logout()
    #expect(harness.session.calls.isEmpty)
  }
}
