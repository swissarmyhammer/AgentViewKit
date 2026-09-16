import AgentViewKit
import AgentViewKitTestSupport
import AuthenticationServices
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKitACP

/// The number of times that ``waitUntil(_:)`` checks its condition.
private let maximumPolls = 400

/// The time between two checks of ``waitUntil(_:)``, in milliseconds.
private let pollMilliseconds = 5

/// The time between two checks of ``waitUntil(_:)``.
private let pollInterval = Duration.milliseconds(pollMilliseconds)

/// The time that ``AgentProcessLauncherTests`` waits for a process.
private let operationLimit = ScriptedWireAgent.operationLimit

/// The session of each test.
private let sessionID = "s1"

/// The JSON-RPC id of each request that the agent sends to the client.
private let agentRequestID = 100.0

/// The path of the agent program for terminal authentication.
private let agentPath = "/usr/local/bin/agent"

/// The exit status of a failed terminal authentication.
private let failedStatus: Int32 = 3

/// Checks a condition until it is true or the time runs out.
///
/// - Parameter condition: The condition to check.
/// - Returns: The last value of the condition.
private func waitUntil(_ condition: () -> Bool) async -> Bool {
  var polls = 0
  while !condition(), polls < maximumPolls {
    try? await Task.sleep(for: pollInterval)
    polls += 1
  }
  return condition()
}

/// Decodes JSON text into a kit JSON value.
private func json(_ text: String) throws -> AgentViewKit.JSONValue {
  try JSONDecoder().decode(AgentViewKit.JSONValue.self, from: Data(text.utf8))
}

/// A JSON-RPC request from the agent with `method` and `params`.
private func agentRequest(_ method: String, params: String) -> String {
  #"{"jsonrpc":"2.0","id":\#(Int(agentRequestID)),"method":"\#(method)","params":\#(params)}"#
}

/// A permission request with an allow option and a reject option.
private let permissionParams = #"""
  {"sessionId": "s1", "title": "Edit a.swift",
   "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"},
               {"optionId": "no", "name": "Reject", "kind": "reject_once"}]}
  """#

/// A form elicitation of the session.
private let formElicitationParams = #"""
  {"sessionId": "s1", "message": "Your name?", "mode": "form",
   "requestedSchema": {"type": "object", "properties": {"name": {"type": "string"}}}}
  """#

/// A URL elicitation of the session with the wire id `e1`.
private let urlElicitationParams = #"""
  {"sessionId": "s1", "message": "Sign in", "mode": "url",
   "url": "https://example.com/auth", "elicitationId": "e1"}
  """#

/// The response of `session/set_config_option`.
private let configOptionsResult = #"""
  {"configOptions": [{"configId": "mode", "name": "Mode", "type": "select", "currentValue": "code",
                      "options": [{"value": "plan", "name": "Plan"}, {"value": "code", "name": "Code"}]},
                     {"configId": "web", "name": "Web", "type": "boolean", "currentValue": true}]}
  """#

/// A web authentication factory that records the connection state when
/// each session is made. It makes the sessions with a
/// ``FakeWebAuthSession``.
private final class StateRecordingFactory: WebAuthSessionFactory {
  /// The factory that makes the sessions.
  let fake: FakeWebAuthSession

  /// The store to read.
  let store: ConnectionStore

  /// The connection to read.
  let connectionID: ConnectionID

  /// The state of the connection when each session was made.
  private(set) var states: [AgentViewKit.ConnectionState?] = []

  init(fake: FakeWebAuthSession, store: ConnectionStore, connectionID: ConnectionID) {
    self.fake = fake
    self.store = store
    self.connectionID = connectionID
  }

  func makeSession(url: URL, callbackScheme: String) -> any WebAuthSession {
    states.append(store.connection(connectionID)?.state)
    return fake.makeSession(url: url, callbackScheme: callbackScheme)
  }
}

/// The objects of one test: the client, the scripted agent, and the actions.
private struct Harness {
  let thread = AgentThread()
  let client = SwiftUIACPClient()
  let agent: ScriptedWireAgent
  let actions: ACPThreadActions

  /// Connects a client to a scripted agent and makes the actions.
  init(
    presenter: AuthorizationPresenter = AuthorizationPresenter(factory: FakeWebAuthSession(script: .cancelled)),
    launcher: FakeProcessLauncher = FakeProcessLauncher(),
    store: ConnectionStore? = nil,
    agentProgram: ACPAgentProgram? = ACPAgentProgram(path: agentPath, arguments: ["--acp"])
  ) async {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let connection = await client.connect(over: clientEnd)
    agent = ScriptedWireAgent(transport: agentEnd)
    agent.start()
    actions = ACPThreadActions(
      thread: thread,
      client: client,
      connection: connection,
      sessionId: SessionId(rawValue: sessionID),
      presenter: presenter,
      processLauncher: launcher,
      connectionStore: store,
      agentProgram: agentProgram
    )
  }

  /// The observable state of the session.
  var session: ACPSessionState { client.session(for: SessionId(rawValue: sessionID)) }

  /// Runs `operation` with the time limit of the agent.
  ///
  /// - Parameter operation: The operation to run.
  func bounded<Result>(_ operation: () async throws -> Result) async rethrows -> Result {
    try await agent.bounded(operation)
  }
}

@MainActor
@Suite struct ACPThreadActionsTests {
  // MARK: - Turn

  @Test func sendSendsAPromptWithTextImageAndResourceLinkBlocks() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    let folder = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let image = folder.appending(path: "shot.png")
    let imageBytes = Data([0x89, 0x50, 0x4E, 0x47])
    try imageBytes.write(to: image)
    let notes = folder.appending(path: "notes.txt")

    await harness.bounded { await harness.actions.send(UserInput(text: "Hi", attachments: [image, notes])) }

    let prompt = try #require(harness.agent.messages(method: "session/prompt").first)
    let expected = AgentViewKit.JSONValue.object([
      "sessionId": .string(sessionID),
      "prompt": .array([
        .object(["type": .string("text"), "text": .string("Hi")]),
        .object([
          "type": .string("image"), "data": .string(imageBytes.base64EncodedString()),
          "mimeType": .string("image/png"), "uri": .string(image.absoluteString),
        ]),
        .object([
          "type": .string("resource_link"), "name": .string("notes.txt"),
          "uri": .string(notes.absoluteString), "mimeType": .string("text/plain"),
        ]),
      ]),
    ])
    #expect(prompt["params"] == expected)
    #expect(harness.thread.items.isEmpty)
  }

  @Test func sendThatFailsAddsAnErrorRecord() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["session/prompt"]

    await harness.bounded { await harness.actions.send(UserInput(text: "Hi")) }

    let item = harness.thread.item(id: ACPThreadActions.errorIDPrefix + "1")
    guard case .error(let record)? = item else {
      Issue.record("Expected an error record, got \(String(describing: item)).")
      return
    }
    guard case .unknown(let message) = record.kind else {
      Issue.record("Expected an unknown error kind, got \(record.kind).")
      return
    }
    #expect(message.contains("failed"))
  }

  @Test func cancelSendsSessionCancel() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }

    await harness.bounded { await harness.actions.cancel() }

    #expect(await waitUntil { !harness.agent.messages(method: "session/cancel").isEmpty })
    let cancel = try #require(harness.agent.messages(method: "session/cancel").first)
    #expect(cancel["params"] == .object(["sessionId": .string(sessionID)]))
    #expect(cancel["id"] == nil)
  }

  // MARK: - Permission

  /// Sends the permission request and gives its kit request.
  private func pendingPermission(_ harness: Harness) async throws -> PermissionRequest {
    try await harness.agent.send(agentRequest("session/request_permission", params: permissionParams))
    #expect(await waitUntil { !harness.session.pendingPermissionRequests.isEmpty })
    let pending = try #require(harness.session.pendingPermissionRequests.first)
    let request = SessionUpdateMapping.permissionRequest(pending)
    harness.thread.apply(.addPermission(request))
    return request
  }

  @Test func permissionSelectionSendsTheSelectedOption() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    let request = try await pendingPermission(harness)

    await harness.bounded { await harness.actions.respond(to: request, PermissionDecision(outcome: .selected(PermissionOptionID("yes")))) }

    #expect(await waitUntil { harness.agent.response(to: agentRequestID) != nil })
    let response = try #require(harness.agent.response(to: agentRequestID))
    #expect(response["result"] == (try json(#"{"outcome": {"outcome": "selected", "optionId": "yes"}}"#)))
    #expect(harness.thread.pendingPermissions.isEmpty)
    #expect(harness.agent.messages(method: "session/prompt").isEmpty)
  }

  @Test func permissionCancelSendsTheCancelledOutcome() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    let request = try await pendingPermission(harness)

    await harness.bounded { await harness.actions.respond(to: request, PermissionDecision(outcome: .cancelled)) }

    #expect(await waitUntil { harness.agent.response(to: agentRequestID) != nil })
    let response = try #require(harness.agent.response(to: agentRequestID))
    #expect(response["result"] == (try json(#"{"outcome": {"outcome": "cancelled"}}"#)))
    #expect(harness.thread.pendingPermissions.isEmpty)
  }

  @Test func rejectionWithACommentSendsTheAnswerThenAPrompt() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    let request = try await pendingPermission(harness)
    let comment = "Write the tests first."

    await harness.bounded { await harness.actions.respond(to: request, PermissionDecision(outcome: .selected(PermissionOptionID("no")), comment: comment)) }

    let answer = try #require(harness.agent.index(ofResponseTo: agentRequestID))
    let prompt = try #require(harness.agent.index(ofMethod: "session/prompt"))
    #expect(answer < prompt)
    let blocks = harness.agent.received[prompt]["params"]?["prompt"]
    #expect(blocks == .array([.object(["type": .string("text"), "text": .string(comment)])]))
    #expect(
      harness.agent.received[answer]["result"]
        == (try json(#"{"outcome": {"outcome": "selected", "optionId": "no"}}"#)))
  }

  // MARK: - Elicitation

  /// Sends an elicitation request and gives its kit request.
  private func pendingElicitation(_ harness: Harness, params: String) async throws
    -> AgentViewKit.ElicitationRequest
  {
    try await harness.agent.send(agentRequest("elicitation/create", params: params))
    #expect(await waitUntil { !harness.client.pendingElicitations.isEmpty })
    let pending = try #require(harness.client.pendingElicitations.first)
    let request = try #require(SessionUpdateMapping.elicitationRequest(pending, server: "Agent"))
    harness.thread.apply(.addElicitation(request))
    return request
  }

  @Test(arguments: [
    (ElicitationResult.accept(.object(["name": .string("Ada")])), #"{"action": "accept", "content": {"name": "Ada"}}"#),
    (ElicitationResult.decline, #"{"action": "decline"}"#),
    (ElicitationResult.cancel, #"{"action": "cancel"}"#),
  ])
  func elicitationResultSendsTheAction(result: ElicitationResult, expected: String) async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    let request = try await pendingElicitation(harness, params: formElicitationParams)

    await harness.bounded { await harness.actions.respond(to: request, result) }

    #expect(await waitUntil { harness.agent.response(to: agentRequestID) != nil })
    let response = try #require(harness.agent.response(to: agentRequestID))
    #expect(response["result"] == (try json(expected)))
    #expect(harness.thread.pendingElicitations.isEmpty)
    #expect(harness.client.pendingElicitations.isEmpty)
  }

  // MARK: - Config

  @Test func setConfigOptionSendsTheValueAndReplacesTheOptions() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.results["session/set_config_option"] = configOptionsResult
    harness.thread.apply(
      .setConfigOptions([ConfigOption(id: ConfigOptionID("old"), name: "Old", kind: .boolean(current: false))]))

    await harness.bounded { await harness.actions.setConfigOption(ConfigOptionID("mode"), .id("code")) }

    let message = try #require(harness.agent.messages(method: "session/set_config_option").first)
    #expect(
      message["params"]
        == .object([
          "sessionId": .string(sessionID), "configId": .string("mode"),
          "type": .string("id"), "value": .string("code"),
        ]))
    #expect(
      harness.thread.configOptions == [
        ConfigOption(
          id: ConfigOptionID("mode"), name: "Mode",
          kind: .select(
            current: "code",
            choices: .flat([SelectOption(id: "plan", name: "Plan"), SelectOption(id: "code", name: "Code")]))),
        ConfigOption(id: ConfigOptionID("web"), name: "Web", kind: .boolean(current: true)),
      ])
  }

  @Test func setConfigOptionSendsABooleanValue() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.results["session/set_config_option"] = configOptionsResult

    await harness.bounded { await harness.actions.setConfigOption(ConfigOptionID("web"), .boolean(true)) }

    let message = try #require(harness.agent.messages(method: "session/set_config_option").first)
    #expect(message["params"]?["type"] == .string("boolean"))
    #expect(message["params"]?["value"] == .bool(true))
  }

  // MARK: - Auth

  @Test func loginSendsAuthLogin() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }

    try await harness.bounded { try await harness.actions.login(AuthMethodID("agent-login")) }

    let message = try #require(harness.agent.messages(method: "auth/login").first)
    #expect(message["params"] == .object(["methodId": .string("agent-login")]))
  }

  @Test func loginThatFailsThrows() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["auth/login"]

    await #expect(throws: (any Error).self) {
      try await harness.bounded { try await harness.actions.login(AuthMethodID("agent-login")) }
    }
  }

  @Test func logoutSendsAuthLogout() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }

    try await harness.bounded { try await harness.actions.logout() }

    let message = try #require(harness.agent.messages(method: "auth/logout").first)
    #expect(message["params"] == .object([:]))
  }

  @Test func runTerminalAuthLaunchesTheAgentAndShowsTheOutput() async throws {
    let launcher = FakeProcessLauncher(scriptedOutput: [Data("Open the URL\n".utf8), Data("Done\n".utf8)])
    let harness = await Harness(launcher: launcher)
    defer { harness.agent.stop() }
    let method = AgentViewKit.AuthMethod.Terminal(
      id: AuthMethodID("terminal-login"), name: "Terminal", args: ["--login"], env: ["MODE": "login"])

    try await harness.bounded { try await harness.actions.runTerminalAuth(method) }

    #expect(
      launcher.calls == [
        .launch(program: agentPath, arguments: ["--acp", "--login"], environment: ["MODE": "login"])
      ])
    let terminal = try #require(harness.thread.terminals[TerminalID("auth-terminal-login")])
    #expect(terminal.output == Data("Open the URL\nDone\n".utf8))
    #expect(terminal.command == "\(agentPath) --acp --login")
    #expect(terminal.exitStatus == TerminalRecord.ExitStatus(code: 0))
    await harness.bounded { await harness.actions.cancel() }
    #expect(await waitUntil { !harness.agent.messages(method: "session/cancel").isEmpty })
    #expect(harness.agent.messages(method: "auth/login").isEmpty)
  }

  @Test func runTerminalAuthWithAFailedStatusThrows() async throws {
    let launcher = FakeProcessLauncher(scriptedOutput: [], scriptedExitStatus: failedStatus)
    let harness = await Harness(launcher: launcher)
    defer { harness.agent.stop() }
    let method = AgentViewKit.AuthMethod.Terminal(id: AuthMethodID("terminal-login"), name: "Terminal")

    await #expect(throws: ACPThreadActionsError.terminalAuthFailed(status: failedStatus)) {
      try await harness.bounded { try await harness.actions.runTerminalAuth(method) }
    }
    let terminal = try #require(harness.thread.terminals[TerminalID("auth-terminal-login")])
    #expect(terminal.exitStatus == TerminalRecord.ExitStatus(code: Int(failedStatus)))
  }

  @Test func runTerminalAuthWithNoAgentProgramThrows() async throws {
    let launcher = FakeProcessLauncher()
    let harness = await Harness(launcher: launcher, agentProgram: nil)
    defer { harness.agent.stop() }
    let method = AgentViewKit.AuthMethod.Terminal(id: AuthMethodID("terminal-login"), name: "Terminal")

    await #expect(throws: ACPThreadActionsError.noAgentProgram) {
      try await harness.bounded { try await harness.actions.runTerminalAuth(method) }
    }
    #expect(launcher.calls.isEmpty)
  }

  @Test func writeTerminalLineWritesTheLineAndANewlineToTheRunningProcess() async throws {
    let launcher = FakeProcessLauncher(keepsOutputOpen: true)
    let harness = await Harness(launcher: launcher)
    defer { harness.agent.stop() }
    let method = AgentViewKit.AuthMethod.Terminal(id: AuthMethodID("terminal-login"), name: "Terminal")
    let terminalID = TerminalRecord.authID(for: method.id)
    let actions = harness.actions
    let run = Task { try await actions.runTerminalAuth(method) }
    defer { launcher.processes.first?.finishOutput() }
    #expect(await waitUntil { harness.thread.terminals[terminalID] != nil })

    try await actions.writeTerminalLine("yes", to: terminalID)

    let process = try #require(launcher.processes.first)
    #expect(process.writes == [Data("yes\n".utf8)])
    process.finishOutput()
    try await harness.bounded { try await run.value }
    await #expect(throws: ACPThreadActionsError.noRunningTerminal(terminalID)) {
      try await actions.writeTerminalLine("again", to: terminalID)
    }
    #expect(process.writes == [Data("yes\n".utf8)])
  }

  @Test func writeTerminalLineWithNoRunningProcessThrows() async throws {
    let launcher = FakeProcessLauncher()
    let harness = await Harness(launcher: launcher)
    defer { harness.agent.stop() }
    let terminalID = TerminalRecord.authID(for: AuthMethodID("terminal-login"))

    await #expect(throws: ACPThreadActionsError.noRunningTerminal(terminalID)) {
      try await harness.actions.writeTerminalLine("yes", to: terminalID)
    }
    #expect(launcher.calls.isEmpty)
  }

  // MARK: - Connect

  /// A store with one connection that needs authorization.
  private func makeStore() -> ConnectionStore {
    ConnectionStore(connections: [Connection(id: ConnectionID("github"), name: "GitHub", state: .needsAuth)])
  }

  /// An authorization request for the `github` server with `meta`.
  private func authorizationRequest(meta: AgentViewKit.JSONValue?) -> AuthorizationRequest {
    AuthorizationRequest(
      id: AuthorizationRequestID("auth-1"), serverName: "github",
      authorizationURL: URL(string: "https://example.com/authorize")!, meta: meta)
  }

  @Test func connectMovesThroughAuthenticatingAndAcceptsTheElicitation() async throws {
    let store = makeStore()
    let fake = FakeWebAuthSession(script: .callback(URL(string: "agentviewkit://done")!))
    let factory = StateRecordingFactory(fake: fake, store: store, connectionID: ConnectionID("github"))
    let harness = await Harness(presenter: AuthorizationPresenter(factory: factory), store: store)
    defer { harness.agent.stop() }
    _ = try await pendingElicitation(harness, params: urlElicitationParams)
    let request = authorizationRequest(meta: .object(["elicitationId": .string("e1")]))
    harness.thread.apply(.addAuthorization(request))

    try await harness.bounded { try await harness.actions.connect(request) }

    #expect(factory.states == [.authenticating])
    #expect(fake.calls.first == .makeSession(url: request.authorizationURL, callbackScheme: "agentviewkit"))
    #expect(store.connection(ConnectionID("github"))?.state == .connected)
    #expect(harness.thread.pendingAuthorizations.isEmpty)
    #expect(await waitUntil { harness.agent.response(to: agentRequestID) != nil })
    let response = try #require(harness.agent.response(to: agentRequestID))
    #expect(response["result"] == (try json(#"{"action": "accept"}"#)))
    #expect(harness.client.pendingElicitations.isEmpty)
  }

  @Test func connectUsesTheCallbackSchemeOfTheMeta() async throws {
    let fake = FakeWebAuthSession(script: .callback(URL(string: "custom://done")!))
    let harness = await Harness(presenter: AuthorizationPresenter(factory: fake))
    defer { harness.agent.stop() }
    let request = authorizationRequest(meta: .object(["callbackScheme": .string("custom")]))

    try await harness.bounded { try await harness.actions.connect(request) }

    #expect(fake.calls.first == .makeSession(url: request.authorizationURL, callbackScheme: "custom"))
  }

  @Test func connectThatFailsMovesToErrorAndThrows() async throws {
    let store = makeStore()
    let fake = FakeWebAuthSession(script: .failsToStart)
    let harness = await Harness(presenter: AuthorizationPresenter(factory: fake), store: store)
    defer { harness.agent.stop() }

    await #expect(throws: AuthorizationPresenterError.failedToStart) {
      try await harness.bounded { try await harness.actions.connect(authorizationRequest(meta: nil)) }
    }
    #expect(store.connection(ConnectionID("github"))?.state.kind == .error)
  }

  @Test func connectThatTheUserCancelsMovesBackToNeedsAuth() async throws {
    let store = makeStore()
    let fake = FakeWebAuthSession(script: .cancelled)
    let harness = await Harness(presenter: AuthorizationPresenter(factory: fake), store: store)
    defer { harness.agent.stop() }

    await #expect(throws: AuthorizationPresenterError.cancelled) {
      try await harness.bounded { try await harness.actions.connect(authorizationRequest(meta: nil)) }
    }
    #expect(store.connection(ConnectionID("github"))?.state == .needsAuth)
  }
}

@MainActor
@Suite struct AgentProcessLauncherTests {
  /// Reads the output of `process` until it ends, with a time limit.
  ///
  /// When the time runs out, the function records an issue and stops the
  /// process. The stop ends the output.
  private func collectOutput(of process: any LaunchedProcess) async -> Data {
    let watchdog = Task {
      try? await Task.sleep(for: operationLimit)
      guard !Task.isCancelled else { return }
      Issue.record("The process did not end in time.")
      process.terminate()
    }
    defer { watchdog.cancel() }
    var output = Data()
    for await chunk in process.output {
      output.append(chunk)
    }
    return output
  }

  @Test func commandWithNoEnvironmentIsTheProgram() throws {
    let command = try AgentProcessLauncher.command(program: "/bin/agent", arguments: ["--x"], environment: [:])
    #expect(command.program == "/bin/agent")
    #expect(command.arguments == ["--x"])
  }

  @Test func commandWithAnEnvironmentStartsEnvWithSortedPairs() throws {
    let command = try AgentProcessLauncher.command(
      program: "/bin/agent", arguments: ["--x"], environment: ["ZED": "2", "ALPHA": "1"])
    #expect(command.program == AgentProcessLauncher.environmentProgram)
    #expect(command.arguments == ["ALPHA=1", "ZED=2", "/bin/agent", "--x"])
  }

  @Test func commandRefusesAnInvalidName() {
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("A=B")) {
      try AgentProcessLauncher.command(program: "/bin/agent", arguments: [], environment: ["A=B": "1"])
    }
    #expect(throws: AgentProcessLauncherError.invalidEnvironmentName("")) {
      try AgentProcessLauncher.command(program: "/bin/agent", arguments: [], environment: ["": "1"])
    }
  }

  @Test func commandRefusesAProgramPathWithAnEqualSign() {
    #expect(throws: AgentProcessLauncherError.programPathHasEqualSign("/bin/a=b")) {
      try AgentProcessLauncher.command(program: "/bin/a=b", arguments: [], environment: ["A": "1"])
    }
  }

  @Test func launchRunsTheProgramWithTheEnvironment() async throws {
    let process = try AgentProcessLauncher().launch(
      program: "/bin/sh", arguments: ["-c", "echo \"$AVK_VALUE\""], environment: ["AVK_VALUE": "hello"])
    let output = await collectOutput(of: process)
    #expect(String(decoding: output, as: UTF8.self) == "hello\n")
    #expect(process.exitStatus == nil)
    process.terminate()
  }

  @Test func launchWritesToTheStandardInput() async throws {
    let process = try AgentProcessLauncher().launch(
      program: "/usr/bin/head", arguments: ["-n", "1"], environment: [:])
    try process.write(Data("line\n".utf8))
    let output = await collectOutput(of: process)
    #expect(String(decoding: output, as: UTF8.self) == "line\n")
    process.terminate()
    #expect(throws: AgentProcessError.agentUnavailable) {
      try process.write(Data("more\n".utf8))
    }
  }

  @Test func launchOfARelativePathThrows() {
    #expect(throws: AgentProcessError.commandNotAbsolute("agent")) {
      try AgentProcessLauncher().launch(program: "agent", arguments: [], environment: [:])
    }
  }
}
