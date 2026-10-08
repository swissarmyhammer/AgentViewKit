import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests of ``InProcessAgent``: the helper connects a `ConnectionModel` to an
/// ACP agent that runs in the process of the host (plan.md §3.9).
///
/// The agent is ``InMemoryDemoACPAgent``, the `Agent` form of the in-memory
/// demo agent. Each test reads the state of the returned `ConnectionModel`
/// and of its `SessionModel` directly. The helper keeps no state of its own.
@Suite struct InProcessAgentTests {
  /// The text of the prompt of the round trip.
  static let promptText = "hello"

  /// The number of the first turn of a session.
  static let firstTurn = 1

  /// The `info` of the `initialize` request of the tests.
  static let clientInfo = Implementation(name: "InProcessAgentTests", version: "1.0.0")

  /// The working directory of the new session.
  static let workingDirectory = "/tmp/in-process-agent"

  /// Connects a model to a new in-memory demo agent through the helper.
  ///
  /// - Returns: The model that the helper returned, and the box with the agent
  ///   side of the connection.
  private static func makeDemoConnection() async -> (model: ConnectionModel, agent: AgentConnectionBox) {
    let agent = AgentConnectionBox()
    let model = await InProcessAgent.makeConnection { agentConnection in
      agent.keep(agentConnection)
      return InMemoryDemoACPAgent(connection: agentConnection)
    }
    return (model, agent)
  }

  @Test func theReturnedModelIsConnected() async {
    let (model, _) = await Self.makeDemoConnection()

    #expect(model.state == .connected)
    await model.disconnect()
  }

  @Test func aPromptRoundTripPutsTheReplyOfTheAgentInTheTranscript() async throws {
    let (model, agent) = await Self.makeDemoConnection()

    let session = try await ACPTestTimeLimit.run(stopping: agent.close) {
      _ = try await model.initialize(InitializeRequest.makeAgentViewKitRequest(info: Self.clientInfo))
      let session = try await model.newSession(NewSessionRequest(cwd: AbsolutePath(rawValue: Self.workingDirectory)))
      _ = try await session.prompt([.text(FoundationModelsACP.TextContent(text: Self.promptText))])
      return session
    }

    let expected = InMemoryDemoAgent.replyText(to: Self.promptText)
    let replyID = InMemoryDemoAgent.replyID(turn: Self.firstTurn)
    #expect(await waitUntil { session.agentMessageText(id: replyID) == expected })
    await model.disconnect()
  }

  @Test func theStateOfTheModelBecomesDisconnectedAfterTheAgentCloses() async {
    let (model, agent) = await Self.makeDemoConnection()

    await agent.close()

    #expect(await waitUntil { model.state == .disconnected })
  }

  /// A disconnect of the model stops the read of the client end of the pair.
  /// `InMemoryTransport.pair()` then ends the input of the agent side, so the
  /// agent side closes because of the end of its input. When the pair does
  /// not end the input, the time limit stops the agent side, and the reason
  /// is `closedLocally`.
  @Test func aDisconnectOfTheModelClosesTheAgentSide() async throws {
    let (model, agent) = await Self.makeDemoConnection()

    await model.disconnect()

    let reason = try #require(await ACPTestTimeLimit.run(stopping: agent.close) { await agent.closed })
    #expect(Self.isEndOfInput(reason))
    #expect(model.state == .disconnected)
  }

  /// Tells if a connection closed because its input ended.
  ///
  /// `ConnectionCloseReason` is not `Equatable`, because a transport failure
  /// holds `any Error`.
  ///
  /// - Parameter reason: The reason of the close.
  /// - Returns: `true` when the reason is `endOfInput`.
  private static func isEndOfInput(_ reason: ConnectionCloseReason) -> Bool {
    if case .endOfInput = reason { return true }
    return false
  }
}
