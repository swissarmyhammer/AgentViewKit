import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient

/// Helpers for a scripted session that has child sessions.
///
/// The model is parent and child all the way down: a child is announced in
/// the stream of its parent, and each child can announce its own children in
/// its own stream. These helpers take the id of the stream that carries the
/// update, so the same helper works at each level. A test chain of three
/// sessions is only a test size.
///
/// The link between an `agents` tool call and its child session is
/// `_meta.sah.agentRun` (``SAH/AgentRun``). The helpers write it on both
/// messages. A helper can leave it out, as an agent does for a child that a
/// host started.
extension ScriptedSession {
  /// Sends one typed update in the stream of a session.
  ///
  /// - Parameters:
  ///   - update: The update.
  ///   - sessionId: The session whose stream carries the update.
  /// - Throws: The error of the encoder or of the transport.
  public func send(update: SessionUpdate, in sessionId: SessionId) async throws {
    try await agent.send(
      Self.sessionUpdateFrame(sessionId: .string(sessionId.rawValue), update: JSONValue(encoding: update)))
  }

  /// Finds a session of the tree under the scripted session.
  ///
  /// - Parameter sessionId: The id of the session.
  /// - Returns: The session model: the scripted session, or a descendant of
  ///   it. `nil` when the tree has no such session.
  public func session(_ sessionId: SessionId) -> SessionModel? {
    Self.find(sessionId, under: model)
  }

  /// Finds a session in the tree under a session, depth first.
  private static func find(_ sessionId: SessionId, under session: SessionModel) -> SessionModel? {
    if session.sessionId == sessionId { return session }
    return session.children.lazy.compactMap { find(sessionId, under: $0) }.first
  }

  /// Announces a child session in the stream of its parent, and waits until
  /// the model made the child.
  ///
  /// - Parameters:
  ///   - child: The id of the child.
  ///   - title: The title of the child, or `nil` for none.
  ///   - parent: The parent. The default is the scripted session.
  ///   - toolCallId: The id of the `agents` tool call that started the child.
  ///     The helper writes the link `_meta.sah.agentRun` with it. `nil` sends
  ///     no link.
  ///   - state: The state of the first snapshot, or `nil` for none.
  /// - Returns: The model of the child.
  /// - Throws: The error of the encoder or of the transport, or
  ///   ``ScriptedChildError/notAnnounced`` when the model did not make the
  ///   child.
  @discardableResult
  public func announceChild(
    _ child: SessionId, title: String? = nil, in parent: SessionId? = nil,
    startedBy toolCallId: ToolCallId? = nil, state: StateUpdate? = .running(RunningStateUpdate())
  ) async throws -> SessionModel {
    let parent = parent ?? model.sessionId
    let link = try toolCallId.map { try SAH.AgentRun(toolCallId: $0).inject(into: nil) }
    let update = SubagentUpdate(
      sessionId: child, state: state.map { .value($0) } ?? .unchanged,
      title: title.map { .value($0) } ?? .unchanged, meta: link.map { .value($0) } ?? .unchanged)
    try await send(update: .subagentUpdate(update), in: parent)
    await ObservationWait.until { self.session(child) != nil || self.model.isClosed }
    guard let made = session(child) else { throw ScriptedChildError.notAnnounced(child) }
    return made
  }

  /// Sends a state snapshot of a child in the stream of its parent.
  ///
  /// - Parameters:
  ///   - state: The state.
  ///   - child: The id of the child.
  ///   - parent: The parent. The default is the scripted session.
  /// - Throws: The error of the encoder or of the transport.
  public func sendChildSnapshot(_ state: StateUpdate, child: SessionId, in parent: SessionId? = nil) async throws {
    let update = SubagentUpdate(sessionId: child, state: .value(state))
    try await send(update: .subagentUpdate(update), in: parent ?? model.sessionId)
  }

  /// Sends a `state_update` in the stream of a child.
  ///
  /// - Parameters:
  ///   - state: The state.
  ///   - child: The id of the child.
  /// - Throws: The error of the encoder or of the transport.
  public func sendChildState(_ state: StateUpdate, child: SessionId) async throws {
    try await send(update: .stateUpdate(state), in: child)
  }

  /// Sends an agent message chunk in the stream of a child.
  ///
  /// - Parameters:
  ///   - text: The text of the chunk.
  ///   - messageID: The `messageId` of the message.
  ///   - child: The id of the child.
  /// - Throws: The error of the encoder or of the transport.
  public func sendChildMessage(_ text: String, messageID: String, child: SessionId) async throws {
    try await send(update: BackgroundRunScript.makeChunkUpdate(messageID: messageID, text: text), in: child)
  }

  /// Sends a permission request of a child.
  ///
  /// - Parameters:
  ///   - child: The id of the child.
  ///   - id: The JSON-RPC id of the request.
  /// - Throws: The error of the transport.
  public func sendChildPermissionRequest(child: SessionId, id: Int) async throws {
    try await sendRequest(
      Self.permissionMethod, id: id, params: Self.makePermissionParams(sessionId: child.rawValue))
  }

  /// Sends a form elicitation of a child.
  ///
  /// - Parameters:
  ///   - child: The id of the child.
  ///   - id: The JSON-RPC id of the request.
  /// - Throws: The error of the transport.
  public func sendChildElicitation(child: SessionId, id: Int) async throws {
    try await sendRequest(
      Self.elicitationMethod, id: id, params: Self.makeFormElicitationParams(sessionId: child.rawValue))
  }

  /// Sends the `agents` tool call that starts a child, in the stream of the
  /// parent.
  ///
  /// - Parameters:
  ///   - toolCallId: The id of the tool call.
  ///   - child: The id of the child session. The helper writes the link
  ///     `_meta.sah.agentRun` with it. `nil` sends no link.
  ///   - parent: The parent. The default is the scripted session.
  /// - Throws: The error of the encoder or of the transport.
  public func sendAgentToolCall(_ toolCallId: ToolCallId, child: SessionId?, in parent: SessionId? = nil) async throws {
    try await send(
      update: .toolCallUpdate(
        ToolCallUpdate(
          toolCallId: toolCallId, name: .value("agents"), status: .value(.inProgress), title: .value("Run agent"),
          meta: try Self.linkMeta(child: child))),
      in: parent ?? model.sessionId)
  }

  /// Sends the final update of an `agents` tool call. The agent sends it
  /// after the last update of the child, so the client removes the child
  /// when it sees it.
  ///
  /// - Parameters:
  ///   - toolCallId: The id of the tool call.
  ///   - status: The final status. The default is completed.
  ///   - child: The id of the child session, for the link, or `nil` for no
  ///     link.
  ///   - parent: The parent. The default is the scripted session.
  /// - Throws: The error of the encoder or of the transport.
  public func sendAgentToolCallResult(
    _ toolCallId: ToolCallId, status: ToolCallStatus = .completed, child: SessionId?, in parent: SessionId? = nil
  ) async throws {
    try await send(
      update: .toolCallUpdate(
        ToolCallUpdate(
          toolCallId: toolCallId, status: .value(status), meta: try Self.linkMeta(child: child))),
      in: parent ?? model.sessionId)
  }

  /// The `_meta` patch of an `agents` tool call with the link to its child.
  private static func linkMeta(child: SessionId?) throws -> PatchField<JSONValue> {
    guard let child else { return .unchanged }
    return .value(try SAH.AgentRun(sessionId: child).inject(into: nil))
  }
}

/// The error of a helper of a scripted session with children.
public enum ScriptedChildError: Error, Equatable {
  /// The model did not make the announced child.
  case notAnnounced(SessionId)
}
