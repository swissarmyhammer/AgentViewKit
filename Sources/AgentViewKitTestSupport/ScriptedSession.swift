import AgentViewKit
// The benchmark target of `Benchmarks/` compiles this file,
// `BackgroundRunScript.swift` and `ScriptedWireAgent.swift` through links, in
// one module with no `DemoSupport` module (`Benchmarks/README.md`, "The
// boundary").
#if canImport(DemoSupport)
  import DemoSupport
#endif
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// A `SessionModel` over a ``DemoSupport/ScriptedWireAgent``, for the view
/// tests (plan.md §3.2).
///
/// ``open(bufferLimits:additionalDirectories:terminalAuthRunner:coalescingCadence:configure:)``
/// connects a `ConnectionModel` to the agent over an `InMemoryTransport`
/// pair, sends `initialize`, and opens one new session.
/// By default the connection model has a coalescing cadence of zero, so each
/// chunk changes its entry at once. A test sends `session/update` frames with
/// ``sendUpdate(_:)`` and reads the transcript of ``model``.
///
/// The class states `@MainActor`, because the benchmark target of
/// `Benchmarks/` compiles this file through a link with no default
/// isolation.
@MainActor
public final class ScriptedSession {
  /// The id of the session that the agent opens.
  public static let sessionID = "scripted-session"

  /// The working directory of the new session request.
  public static let workingDirectory = "/tmp/scripted-session"

  /// The `initialize` result of the agent: protocol version 2 with the
  /// session capabilities and no prompt capability.
  static let initializeResult = makeInitializeResult(sessionCapabilities: "{}")

  /// The `initialize` result of an agent that accepts the
  /// `additionalDirectories` of `session/new` and `session/resume`: protocol
  /// version 2 with the session capability `additionalDirectories` and no
  /// prompt capability.
  public static let additionalDirectoriesInitializeResult = makeInitializeResult(
    sessionCapabilities: #"{"additionalDirectories": {}}"#)

  /// Makes the `initialize` result of an agent with prompt capabilities.
  ///
  /// Give the result to the agent in the `configure` closure of
  /// ``open(bufferLimits:additionalDirectories:terminalAuthRunner:coalescingCadence:configure:)``:
  ///
  /// ```swift
  /// let session = try await ScriptedSession.open {
  ///   $0.results["initialize"] = ScriptedSession.makeInitializeResult(promptCapabilities: #"{"image": {}}"#)
  /// }
  /// ```
  ///
  /// - Parameter promptCapabilities: The JSON text of the `prompt` member of
  ///   the session capabilities, such as `{"embeddedContext": {}}`.
  /// - Returns: The JSON text of the result: protocol version 2 with the
  ///   session capabilities and the prompt capabilities.
  public static func makeInitializeResult(promptCapabilities: String) -> String {
    makeInitializeResult(sessionCapabilities: #"{"prompt": \#(promptCapabilities)}"#)
  }

  /// The `info` member of the `initialize` result of the agent: the name
  /// `scripted-agent` and the version `1.0.0`, with no title.
  public static let agentInfo = #"{"name": "scripted-agent", "version": "1.0.0"}"#

  /// Makes the `initialize` result of an agent with auth methods.
  ///
  /// Give the result to the agent in the `configure` closure of
  /// ``open(bufferLimits:additionalDirectories:terminalAuthRunner:coalescingCadence:configure:)``:
  ///
  /// ```swift
  /// let session = try await ScriptedSession.open {
  ///   $0.results["initialize"] = ScriptedSession.makeInitializeResult(
  ///     info: ScriptedSession.agentInfo,
  ///     authMethods: #"[{"type": "agent", "methodId": "login", "name": "Sign in"}]"#)
  /// }
  /// ```
  ///
  /// - Parameters:
  ///   - info: The JSON text of the `info` member, such as ``agentInfo``.
  ///   - authMethods: The JSON text of the `authMethods` array.
  /// - Returns: The JSON text of the result: protocol version 2 with the
  ///   session capabilities, the agent info and the auth methods.
  public static func makeInitializeResult(info: String, authMethods: String) -> String {
    makeInitializeResult(sessionCapabilities: "{}", info: info, authMethods: authMethods)
  }

  /// Makes the `initialize` result of the agent.
  ///
  /// - Parameters:
  ///   - sessionCapabilities: The JSON text of the `session` member of the
  ///     agent capabilities.
  ///   - info: The JSON text of the `info` member.
  ///   - authMethods: The JSON text of the `authMethods` array.
  /// - Returns: The JSON text of the result with protocol version 2.
  private static func makeInitializeResult(
    sessionCapabilities: String, info: String = agentInfo, authMethods: String = "[]"
  ) -> String {
    #"""
    {"info": \#(info), "protocolVersion": 2, "authMethods": \#(authMethods),
     "capabilities": {"session": \#(sessionCapabilities)}}
    """#
  }

  /// The `info` that the client sends in its `initialize` request.
  public static let clientInfo = Implementation(name: "AgentViewKitTestSupport", version: "1.0.0")

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
  /// - Parameters:
  ///   - bufferLimits: The limits of the update buffer of the connection. A
  ///     test gives small limits to make the buffer overflow, so that the
  ///     session model gets `hasMissedUpdates`.
  ///   - additionalDirectories: The additional workspace roots of the
  ///     `session/new` request. When the list is not empty, the `initialize`
  ///     result of the agent advertises `session.additionalDirectories`, so
  ///     that the connection model sends the list. A `configure` closure
  ///     that replaces the `initialize` result must also advertise it.
  ///   - terminalAuthRunner: The runner of the host, or `nil`. With a
  ///     runner, the `initialize` request advertises `auth.terminal`, so
  ///     that the model can run a `terminal` method of the agent.
  ///   - coalescingCadence: The cadence between the coalesced flushes of the
  ///     chunks of the session model. The default is zero, so each chunk
  ///     changes its entry at once. A test or a benchmark of the coalescing
  ///     gives `SessionModel.defaultCoalescingCadence`.
  ///   - configure: Changes the agent before it starts, for example its
  ///     results or its prompt echo order.
  /// - Returns: The helper with the open session.
  /// - Throws: The error of `initialize` or of `session/new`.
  public static func open(
    bufferLimits: SessionUpdateBufferLimits = .default,
    additionalDirectories: [AbsolutePath] = [],
    terminalAuthRunner: (any TerminalAuthRunner)? = nil,
    coalescingCadence: Duration = .zero,
    configure: (ScriptedWireAgent) -> Void = { _ in }
  ) async throws -> ScriptedSession {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let agent = ScriptedWireAgent(transport: agentEnd)
    agent.results["initialize"] =
      additionalDirectories.isEmpty ? initializeResult : additionalDirectoriesInitializeResult
    agent.results["session/new"] = newSessionResult
    configure(agent)
    agent.start()
    let connection = ConnectionModel(coalescingCadence: coalescingCadence)
    _ = await connection.connect(over: clientEnd, bufferLimits: bufferLimits)
    _ = try await connection.initialize(
      InitializeRequest.makeAgentViewKitRequest(info: clientInfo, terminalAuthRunner: terminalAuthRunner))
    let model = try await connection.newSession(
      NewSessionRequest(
        cwd: AbsolutePath(rawValue: workingDirectory),
        additionalDirectories: additionalDirectories.isEmpty ? nil : additionalDirectories))
    return ScriptedSession(agent: agent, connection: connection, model: model)
  }

  /// Sends one `session/update` frame of the session from the agent.
  ///
  /// - Parameter update: The JSON text of the update, such as
  ///   `{"sessionUpdate": "agent_message_chunk", ...}`.
  /// - Throws: The error of the JSON parser or of the transport.
  public func sendUpdate(_ update: String) async throws {
    try await send(updateValue: JSONValue(json: update))
  }

  /// Sends one typed `session/update` value of the session from the agent.
  ///
  /// - Parameter update: The update, such as a step of
  ///   ``BackgroundRunScript``.
  /// - Throws: The error of the encoder or of the transport.
  public func send(update: SessionUpdate) async throws {
    try await send(updateValue: JSONValue(encoding: update))
  }

  /// Sends one `session/update` frame of the session from the agent.
  ///
  /// - Parameter updateValue: The `update` member of the params.
  /// - Throws: The error of the transport.
  private func send(updateValue: JSONValue) async throws {
    try await agent.send(Self.sessionUpdateFrame(sessionId: .string(model.sessionId.rawValue), update: updateValue))
  }

  /// The params of a permission request of the session, with the
  /// `allow_once` option `yes` and the `reject_once` option `no`.
  public static let permissionParams = #"""
    {"sessionId": "\#(sessionID)", "title": "Edit a.swift",
     "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"},
                 {"optionId": "no", "name": "Reject", "kind": "reject_once"}]}
    """#

  /// The params of a form elicitation of the session. The one field `name`
  /// has the default `Ada`, so the form can submit at once.
  public static let formElicitationParams = #"""
    {"sessionId": "\#(sessionID)", "message": "Your name?", "mode": "form",
     "requestedSchema": {"type": "object",
                         "properties": {"name": {"type": "string", "default": "Ada"}}}}
    """#

  /// A JSON-RPC request frame from the agent to the client.
  ///
  /// - Parameters:
  ///   - method: The method of the request.
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params.
  /// - Returns: The JSON text of the frame.
  public static func requestFrame(_ method: String, id: Int, params: String) -> String {
    #"{"jsonrpc":"2.0","id":\#(id),"method":"\#(method)","params":\#(params)}"#
  }

  /// A `session/update` notification frame from the agent to the client.
  /// The frame comes from
  /// ``DemoSupport/ScriptedWireAgent/makeSessionUpdateFrame(params:)``.
  ///
  /// - Parameters:
  ///   - sessionId: The `sessionId` member of the params. The default is
  ///     ``sessionID``. A follow-up of the agent can give the `sessionId`
  ///     of its request.
  ///   - update: The `update` member of the params.
  /// - Returns: The JSON text of the frame.
  public static func sessionUpdateFrame(sessionId: JSONValue = .string(sessionID), update: JSONValue) -> String {
    ScriptedWireAgent.makeSessionUpdateFrame(params: .object(["sessionId": sessionId, "update": update]))
  }

  /// An `agent_message_chunk` update with one text block, as a JSON value.
  /// The update comes from
  /// ``BackgroundRunScript/makeChunkUpdate(messageID:text:)``.
  ///
  /// - Parameters:
  ///   - messageID: The `messageId` of the agent message.
  ///   - text: The text of the chunk.
  /// - Returns: The update.
  /// - Throws: The error of the encoder.
  public static func agentMessageChunkUpdate(messageID: String, text: String) throws -> JSONValue {
    try JSONValue(encoding: BackgroundRunScript.makeChunkUpdate(messageID: messageID, text: text))
  }

  /// Sends one JSON-RPC request from the agent to the client.
  ///
  /// - Parameters:
  ///   - method: The method of the request, such as
  ///     `session/request_permission`.
  ///   - id: The JSON-RPC id of the request.
  ///   - params: The JSON text of the params.
  /// - Throws: The error of the transport.
  public func sendRequest(_ method: String, id: Int, params: String) async throws {
    try await agent.send(Self.requestFrame(method, id: id, params: params))
  }

  /// Stops the agent and closes the transport.
  public func close() {
    agent.stop()
  }
}
