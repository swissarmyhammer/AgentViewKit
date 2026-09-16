import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Tests for ``NoopThreadActions`` and the `threadActions` environment value
/// (plan.md §3.4).
@MainActor
struct NoopThreadActionsTests {
  /// The error that a verb closure throws.
  struct ScriptedError: Error, Equatable {}

  static let fileURL = URL(fileURLWithPath: "/tmp/notes.txt")
  static let authorizationURL = URL(string: "https://auth.example.com/authorize")!

  // MARK: - Verbs

  @Test func sendRecordsTheInput() async {
    let actions = NoopThreadActions()
    let input = UserInput(text: "Hello", attachments: [Self.fileURL])

    await actions.send(input)

    #expect(actions.calls == [.send(input)])
  }

  @Test func cancelRecordsTheCall() async {
    let actions = NoopThreadActions()

    await actions.cancel()

    #expect(actions.calls == [.cancel])
  }

  @Test func respondToPermissionRecordsTheRequestAndTheDecision() async {
    let actions = NoopThreadActions()
    let request = ThreadFixtures.permissionRequest()
    let decision = PermissionDecision(outcome: .selected(request.options[0].id), comment: "Yes")

    await actions.respond(to: request, decision)

    #expect(actions.calls == [.respondToPermission(request, decision)])
  }

  @Test func respondToElicitationRecordsTheRequestAndTheResult() async {
    let actions = NoopThreadActions()
    let request = ThreadFixtures.formElicitationRequest()
    let result = ElicitationResult.accept(.object(["name": .string("Ada")]))

    await actions.respond(to: request, result)

    #expect(actions.calls == [.respondToElicitation(request, result)])
  }

  @Test func setConfigOptionRecordsTheIdAndTheValue() async {
    let actions = NoopThreadActions()
    let id = ConfigOptionID("mode")
    let value = ConfigValue.boolean(true)

    await actions.setConfigOption(id, value)

    #expect(actions.calls == [.setConfigOption(id, value)])
  }

  @Test func connectRecordsTheRequest() async throws {
    let actions = NoopThreadActions()
    let request = AuthorizationRequest(
      id: AuthorizationRequestID("auth-1"),
      serverName: "Files",
      authorizationURL: Self.authorizationURL
    )

    try await actions.connect(request)

    #expect(actions.calls == [.connect(request)])
  }

  @Test func loginRecordsTheMethodId() async throws {
    let actions = NoopThreadActions()
    let id = AuthMethodID("oauth")

    try await actions.login(id)

    #expect(actions.calls == [.login(id)])
  }

  @Test func runTerminalAuthRecordsTheMethod() async throws {
    let actions = NoopThreadActions()
    let method = AuthMethod.Terminal(
      id: AuthMethodID("setup"),
      name: "Set up",
      args: ["--setup"],
      env: ["MODE": "login"]
    )

    try await actions.runTerminalAuth(method)

    #expect(actions.calls == [.runTerminalAuth(method)])
  }

  @Test func logoutRecordsTheCall() async throws {
    let actions = NoopThreadActions()

    try await actions.logout()

    #expect(actions.calls == [.logout])
  }

  @Test func callsKeepTheCallOrder() async throws {
    let actions = NoopThreadActions()

    await actions.cancel()
    try await actions.logout()
    await actions.send(UserInput(text: "Again"))

    #expect(actions.calls == [.cancel, .logout, .send(UserInput(text: "Again"))])
  }

  // MARK: - Reset

  @Test func resetRemovesEachCall() async throws {
    let actions = NoopThreadActions()
    await actions.cancel()
    try await actions.logout()

    actions.reset()

    #expect(actions.calls.isEmpty)
  }

  // MARK: - Closures

  @Test func aThrowingClosureMakesTheVerbThrowAfterTheCallIsRecorded() async {
    let actions = NoopThreadActions()
    let id = AuthMethodID("oauth")
    actions.onLogin = { _ in throw ScriptedError() }

    await #expect(throws: ScriptedError.self) {
      try await actions.login(id)
    }
    #expect(actions.calls == [.login(id)])
  }

  @Test func aClosureGetsTheArgumentsOfTheVerb() async {
    let actions = NoopThreadActions()
    var received: [UserInput] = []
    actions.onSend = { received.append($0) }
    let input = UserInput(text: "Hello")

    await actions.send(input)

    #expect(received == [input])
  }

  // MARK: - Environment

  @Test func theDefaultEnvironmentValueIsTheLoggingActions() {
    #expect(EnvironmentValues().threadActions is LoggingThreadActions)
  }

  @Test func theDefaultActionsDoNothingAndDoNotThrow() async throws {
    let actions = LoggingThreadActions()

    await actions.send(UserInput(text: "Hello"))
    await actions.cancel()
    try await actions.connect(
      AuthorizationRequest(
        id: AuthorizationRequestID("auth-1"),
        serverName: "Files",
        authorizationURL: Self.authorizationURL
      ))
    try await actions.login(AuthMethodID("oauth"))
    try await actions.logout()
  }

  @Test func theModifierSetsTheEnvironmentValue() {
    let actions = NoopThreadActions()
    var environment = EnvironmentValues()

    environment.threadActions = actions

    #expect(environment.threadActions === actions)
  }

  @Test func aHostedViewReadsTheActionsThatTheModifierSets() async throws {
    let actions = NoopThreadActions()
    let harness = HostedViewHarness(ActionsProbe().threadActions(actions))
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: ActionsProbe.stopIdentifier)
    await waitForCalls(actions, count: 1, harness: harness)

    #expect(actions.calls == [.cancel])
  }

  /// Pumps the run loop until `actions` has `count` calls, or until
  /// ``waitLimit`` has passed.
  ///
  /// - Parameters:
  ///   - actions: The actions to read.
  ///   - count: The number of calls to wait for.
  ///   - harness: The harness to pump.
  private func waitForCalls(
    _ actions: NoopThreadActions,
    count: Int,
    harness: HostedViewHarness<some View>
  ) async {
    let deadline = Date(timeIntervalSinceNow: Self.waitLimit)
    while actions.calls.count < count, Date() < deadline {
      harness.pump()
      await Task.yield()
    }
  }

  /// The longest time that ``waitForCalls(_:count:harness:)`` waits, in
  /// seconds.
  private static let waitLimit: TimeInterval = 1
}

/// A view that calls ``AgentThreadActions/cancel()`` from its button.
private struct ActionsProbe: View {
  /// The accessibility identifier of the button.
  static let stopIdentifier = "actions-probe-stop"

  @Environment(\.threadActions) private var actions

  var body: some View {
    Button("Stop") {
      Task { await actions.cancel() }
    }
    .accessibilityIdentifier(Self.stopIdentifier)
  }
}
