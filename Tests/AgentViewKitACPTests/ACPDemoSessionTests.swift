import AgentViewKit
import AgentViewKitACP
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import Testing

@testable import DemoSupport

/// The working directory of each test session.
private let demoCwd = "/tmp/demo"

/// The objects of one test: the model and the agent on the other end.
private struct Harness {
  let session = ACPDemoSession(agentName: InMemoryDemoAgent.name, cwd: demoCwd)
  let agent: ScriptedWireAgent

  /// Starts the in-memory demo agent, or a scripted agent that `configure`
  /// changes before it starts.
  ///
  /// - Parameter configure: Changes a plain scripted agent. When it is
  ///   `nil`, the harness starts ``InMemoryDemoAgent``.
  init(configure: ((ScriptedWireAgent) -> Void)? = nil) {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    if let configure {
      agent = ScriptedWireAgent(transport: agentEnd)
      configure(agent)
      agent.start()
    } else {
      agent = InMemoryDemoAgent.start(on: agentEnd)
    }
    transport = clientEnd
  }

  /// The client end of the transport.
  let transport: InMemoryTransport

  /// Connects the model, with the time limit of the agent.
  func connect() async {
    await agent.bounded { await session.connect(over: transport) }
  }
}

/// The message of the assistant message record `id`, or `nil`.
@MainActor
private func assistantMessage(_ id: String, in thread: AgentThread) -> Message? {
  if case .assistantMessage(let message)? = thread.item(id: id) { message } else { nil }
}

@MainActor
@Suite struct ACPDemoSessionTests {
  @Test func connectBindsTheNewSessionWithTheValuesOfTheAgent() async {
    let harness = Harness()
    defer { harness.agent.stop() }

    await harness.connect()

    let session = harness.session
    #expect(session.phase == .ready)
    #expect(session.sessionID == SessionID(InMemoryDemoAgent.sessionID))
    #expect(session.canDeleteSessions)
    #expect(session.actions != nil)
    #expect(session.sessionList?.cwd == demoCwd)
    #expect(
      session.authMethods == [
        .agent(
          AgentViewKit.AuthMethod.Agent(
            id: AuthMethodID(InMemoryDemoAgent.authMethodID), name: "Demo sign-in",
            description: "The in-memory agent accepts each sign-in."))
      ])
    #expect(session.connectionStore.connection(ACPDemoSession.agentConnectionID)?.state == .connected)
    #expect(session.thread.configOptions.map(\.id) == [ConfigOptionID(InMemoryDemoAgent.modeOptionID)])
    #expect(session.thread.items.isEmpty)
    let newSession = harness.agent.messages(method: "session/new").first
    #expect(newSession?["params"]?["cwd"] == .string(demoCwd))
    #expect(harness.agent.messages(method: "initialize").first?["params"]?["protocolVersion"] == .number(2))
  }

  @Test func aSendOfHelloGivesTheReplyOfTheAgent() async throws {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let actions = try #require(harness.session.actions)
    let thread = harness.session.thread
    let replyID = InMemoryDemoAgent.replyID(turn: 1)

    await harness.agent.bounded { await actions.send(UserInput(text: "hello")) }

    #expect(await waitUntil { thread.state == .idle(.endTurn) && assistantMessage(replyID, in: thread) != nil })
    let reply = try #require(assistantMessage(replyID, in: thread))
    #expect(reply.blocks == [AgentViewKit.ContentBlock(text: InMemoryDemoAgent.replyText(to: "hello"))])
    #expect(thread.streaming[replyID] == nil)
    #expect(thread.items.map(\.id) == [InMemoryDemoAgent.userMessageID(turn: 1), replyID])
    #expect(thread.plans[PlanID(InMemoryDemoAgent.planID)]?.entries.count == 2)
    #expect(thread.usage?.used == InMemoryDemoAgent.tokensPerTurn)
    #expect(thread.usage?.size == InMemoryDemoAgent.contextSize)
  }

  @Test func eachTurnGivesANewReply() async throws {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let actions = try #require(harness.session.actions)
    let thread = harness.session.thread

    await harness.agent.bounded { await actions.send(UserInput(text: "one")) }
    #expect(await waitUntil { assistantMessage(InMemoryDemoAgent.replyID(turn: 1), in: thread) != nil })
    await harness.agent.bounded { await actions.send(UserInput(text: "two")) }
    #expect(await waitUntil { assistantMessage(InMemoryDemoAgent.replyID(turn: 2), in: thread) != nil })

    let second = try #require(assistantMessage(InMemoryDemoAgent.replyID(turn: 2), in: thread))
    #expect(second.blocks == [AgentViewKit.ContentBlock(text: InMemoryDemoAgent.replyText(to: "two"))])
    #expect(thread.items.count == 4)
  }

  @Test func theSessionListGivesTheDemoSession() async throws {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let list = try #require(harness.session.sessionList)

    let page = try await harness.agent.bounded { try await list.page(after: nil) }

    #expect(
      page.sessions == [
        SessionSummary(
          id: SessionID(InMemoryDemoAgent.sessionID), title: InMemoryDemoAgent.sessionTitle,
          cwd: InMemoryDemoAgent.sessionCwd)
      ])
    #expect(page.next == nil)
  }

  @Test func selectSessionResumesTheSessionOnANewThread() async {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let firstThread = harness.session.thread

    await harness.agent.bounded { await harness.session.selectSession(SessionID("other")) }

    #expect(harness.session.sessionID == SessionID("other"))
    #expect(harness.session.thread !== firstThread)
    #expect(harness.session.thread.configOptions.count == 1)
    let resume = harness.agent.messages(method: "session/resume").first
    #expect(resume?["params"]?["sessionId"] == .string("other"))
    #expect(resume?["params"]?["cwd"] == .string(demoCwd))
  }

  @Test func selectingTheBoundSessionSendsNothing() async {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let thread = harness.session.thread

    await harness.session.selectSession(SessionID(InMemoryDemoAgent.sessionID))

    #expect(harness.session.thread === thread)
    #expect(harness.agent.messages(method: "session/resume").isEmpty)
  }

  @Test func newSessionBindsANewThread() async {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()
    let thread = harness.session.thread

    await harness.agent.bounded { await harness.session.newSession() }

    #expect(harness.session.thread !== thread)
    #expect(harness.agent.messages(method: "session/new").count == 2)
  }

  @Test func aFailedInitializeMovesTheModelAndTheConnectionToAnError() async {
    let harness = Harness { agent in
      agent.failingMethods = ["initialize"]
    }
    defer { harness.agent.stop() }

    await harness.connect()

    guard case .failed(let message) = harness.session.phase else {
      Issue.record("The phase is \(harness.session.phase), not failed.")
      return
    }
    #expect(!message.isEmpty)
    #expect(harness.session.actions == nil)
    #expect(harness.session.connectionStore.connection(ACPDemoSession.agentConnectionID)?.state.kind == .error)
  }

  @Test func disconnectMovesTheModelToIdle() async {
    let harness = Harness()
    defer { harness.agent.stop() }
    await harness.connect()

    await harness.agent.bounded { await harness.session.disconnect() }

    #expect(harness.session.phase == .idle)
  }

  // MARK: - Launch

  @Test func startWithTheInMemoryAgentBindsTheDemoSession() async {
    let options = DemoLaunchOptions(arguments: ["app", InMemoryDemoAgent.launchArgument, "--cwd", demoCwd])
    let session = ACPDemoSession(options: options)
    // A disconnect closes the connection, so each request that waits fails.
    let watchdog = Task {
      try? await Task.sleep(for: ScriptedWireAgent.operationLimit)
      guard !Task.isCancelled else { return }
      Issue.record("The start did not end in time.")
      await session.disconnect()
    }

    await session.start(options: options)
    watchdog.cancel()

    #expect(session.agentName == InMemoryDemoAgent.name)
    #expect(session.phase == .ready)
    #expect(session.sessionID == SessionID(InMemoryDemoAgent.sessionID))
    await session.disconnect()
    #expect(session.phase == .idle)
  }

  @Test func startWithAProgramThatDoesNotStartMovesToAnError() async {
    let options = DemoLaunchOptions(arguments: ["app", "--agent-command", "relative-agent"])
    let session = ACPDemoSession(options: options)

    await session.start(options: options)

    guard case .failed = session.phase else {
      Issue.record("The phase is \(session.phase), not failed.")
      return
    }
    #expect(session.agentName == DemoLaunchOptions.processAgentName)
    #expect(session.connectionStore.connection(ACPDemoSession.agentConnectionID)?.state.kind == .error)
  }

  @Test func launchOptionsReadTheKnownArgumentsAndIgnoreTheOthers() {
    let options = DemoLaunchOptions(arguments: [
      "app", "-NSDocumentRevisionsDebugMode", "YES", InMemoryDemoAgent.launchArgument,
      DemoLaunchOptions.agentCommandArgument, "/bin/agent", DemoLaunchOptions.cwdArgument, demoCwd,
    ])

    #expect(options.usesInMemoryAgent)
    #expect(options.agentCommand == "/bin/agent")
    #expect(options.cwd == demoCwd)
  }

  @Test func launchOptionsWithNoArgumentsUseTheDefaults() {
    let options = DemoLaunchOptions(arguments: ["app", DemoLaunchOptions.cwdArgument])

    #expect(!options.usesInMemoryAgent)
    #expect(options.agentCommand == DemoLaunchOptions.defaultAgentCommand)
    #expect(options.agentCommand.hasSuffix(DemoLaunchOptions.siblingAgentPath))
    #expect(options.agentCommand.hasPrefix("/"))
    #expect(options.cwd == FileManager.default.homeDirectoryForCurrentUser.path(percentEncoded: false))
  }

  // MARK: - Scripted turn

  @Test func theChunksOfAReplyJoinToTheReply() {
    let reply = InMemoryDemoAgent.replyText(to: "hello")

    let chunks = InMemoryDemoAgent.chunks(of: reply)

    #expect(chunks.count == InMemoryDemoAgent.replyChunkCount)
    #expect(chunks.joined() == reply)
    #expect(InMemoryDemoAgent.chunks(of: "a") == ["a"])
  }

  @Test func thePromptTextJoinsTheTextBlocks() {
    let request = AgentViewKit.JSONValue.object([
      "params": .object([
        "prompt": .array([
          .object(["type": .string("text"), "text": .string("he")]),
          .object(["type": .string("resource_link"), "uri": .string("file:///a")]),
          .object(["type": .string("text"), "text": .string("llo")]),
        ])
      ])
    ])

    #expect(InMemoryDemoAgent.promptText(of: request) == "hello")
    #expect(InMemoryDemoAgent.promptText(of: .object([:])).isEmpty)
  }
}
