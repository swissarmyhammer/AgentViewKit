import DemoSupport
import FoundationModelsACP
import FoundationModelsACPClient

/// A `SessionModel` over a ``DemoSupport/ScriptedWireAgent``, for the view
/// tests (update.md §4.2).
///
/// ``open(configure:)`` connects a `ConnectionModel` to the agent over an
/// `InMemoryTransport` pair, sends `initialize`, and opens one new session.
/// The connection model has a coalescing cadence of zero, so each chunk
/// changes its entry at once. A test sends `session/update` frames with
/// ``sendUpdate(_:)`` and reads the transcript of ``model``.
public final class ScriptedSession {
  /// The id of the session that the agent opens.
  public static let sessionID = "scripted-session"

  /// The working directory of the new session request.
  public static let workingDirectory = "/tmp/scripted-session"

  /// The `initialize` result of the agent: protocol version 2 with the
  /// session capabilities.
  static let initializeResult = #"""
    {"info": {"name": "scripted-agent", "version": "1.0.0"}, "protocolVersion": 2,
     "capabilities": {"session": {}}}
    """#

  /// The `session/new` result of the agent.
  static let newSessionResult = #"{"sessionId": "\#(sessionID)"}"#

  /// The scripted agent at the other end of the transport.
  public let agent: ScriptedWireAgent

  /// The connection model of the client.
  public let connection: ConnectionModel

  /// The model of the session that the agent opened.
  public let model: SessionModel

  /// Makes the helper from its connected parts.
  ///
  /// - Parameters:
  ///   - agent: The scripted agent.
  ///   - connection: The connection model of the client.
  ///   - model: The model of the open session.
  private init(agent: ScriptedWireAgent, connection: ConnectionModel, model: SessionModel) {
    self.agent = agent
    self.connection = connection
    self.model = model
  }

  /// Connects a connection model to a new scripted agent, and opens one
  /// session.
  ///
  /// - Parameter configure: Changes the agent before it starts, for example
  ///   its results or its prompt echo order.
  /// - Returns: The helper with the open session.
  /// - Throws: The error of `initialize` or of `session/new`.
  public static func open(
    configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agent = ScriptedWireAgent(transport: agentEnd)
    agent.results["initialize"] = initializeResult
    agent.results["session/new"] = newSessionResult
    configure(agent)
    agent.start()
    let connection = ConnectionModel(coalescingCadence: .zero)
    _ = await connection.connect(over: clientEnd)
    _ = try await connection.initialize(
      InitializeRequest(
        info: Implementation(name: "AgentViewKitTestSupport", version: "1.0.0"), protocolVersion: .v2))
    let model = try await connection.newSession(
      NewSessionRequest(cwd: AbsolutePath(rawValue: workingDirectory)))
    return ScriptedSession(agent: agent, connection: connection, model: model)
  }

  /// Sends one `session/update` frame of the session from the agent.
  ///
  /// - Parameter update: The JSON text of the update, such as
  ///   `{"sessionUpdate": "agent_message_chunk", ...}`.
  /// - Throws: The error of the transport.
  public func sendUpdate(_ update: String) async throws {
    let sessionID = model.sessionId.rawValue
    try await agent.send(
      #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"\#(sessionID)","update":\#(update)}}"#)
  }

  /// Stops the agent and closes the transport.
  public func close() {
    agent.stop()
  }
}
