import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Synchronization
import Testing

/// Keeps the agent side of the connection that the factory of
/// ``InProcessAgent`` got, so that a test can close it.
///
/// The factory runs outside the main actor, so the box is not isolated. A
/// `Mutex` holds the connection.
nonisolated private final class AgentConnectionBox: Sendable {
  /// The agent side of the connection, or `nil` before the factory ran.
  private let connection = Mutex<AgentSideConnection?>(nil)

  /// Keeps the agent side of the connection.
  ///
  /// - Parameter agentConnection: The connection that the factory got.
  func keep(_ agentConnection: AgentSideConnection) {
    connection.withLock { $0 = agentConnection }
  }

  /// Closes the agent side of the connection, as an agent process that
  /// stops. Before the factory ran, the call does nothing.
  func close() async {
    await connection.withLock { $0 }?.close()
  }
}

/// Tests of ``InProcessAgent``: the helper connects a `ConnectionModel` to an
/// ACP agent that runs in the process of the host (update.md §8 item 4).
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

  /// The text of the agent message of the first turn in the transcript of a
  /// session.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The joined text blocks of the message, or `nil` when the
  ///   transcript has no agent message with the reply id of the first turn.
  private static func firstReplyText(in session: SessionModel) -> String? {
    let replyID = MessageId(rawValue: InMemoryDemoAgent.replyID(turn: firstTurn))
    for case .agentMessage(let message) in session.transcript where message.messageId == replyID {
      return message.content.compactMap { block in
        if case .text(let text) = block { text.text } else { nil }
      }.joined()
    }
    return nil
  }

  @Test func theReturnedModelIsConnected() async {
    let (model, agent) = await Self.makeDemoConnection()

    #expect(model.state == .connected)
    await agent.close()
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
    #expect(await waitUntil { Self.firstReplyText(in: session) == expected })
    await agent.close()
  }

  @Test func theStateOfTheModelBecomesDisconnectedAfterTheAgentCloses() async {
    let (model, agent) = await Self.makeDemoConnection()

    await agent.close()

    #expect(await waitUntil { model.state == .disconnected })
  }
}
