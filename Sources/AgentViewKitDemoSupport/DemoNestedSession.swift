import FoundationModelsACP

/// A scripted session with child sessions, for the gallery and the UI tests.
///
/// The model is parent and child all the way down. The session has a root, a
/// child of the root with a grandchild, and a second child with a grandchild
/// that failed to restore. The chain of three sessions is only the size of the
/// fixture: each rule that the views show holds at each level.
///
/// The script follows the reference order of ACP v2 "Session Setup"
/// ("Ordering", the nested scenario of `acp-test-agent`):
///
/// 1. the history, which a resume from the start replays: the `agents` tool
///    calls with their links `_meta.sah.agentRun`, each announcement of a
///    child, and the messages of the children,
/// 2. a `subagent_update` for each child that the root lists, then the
///    current `state_update` of the root with the `background` list, then a
///    `session_info_update`,
/// 3. the response of `session/resume`,
/// 4. the current snapshot of each child, with its capabilities and its
///    title. The child that failed to restore has no state, and carries
///    `SAH.RestoreFailure`, as does its grandchild,
/// 5. the child that finishes: it reports idle in its snapshot, and then the
///    final `tool_call_update` of its `agents` call comes. The client removes
///    the child at that update, so it disappears from the tree,
/// 6. a permission request of the grandchild, which waits for the user. The
///    request marks the ancestors of the grandchild.
///
/// ``InMemoryDemoScript/nested`` serves the session. ``InMemoryDemoScript/nestedUnconfirmed``
/// serves the same script with no current snapshot, so each child stays
/// unconfirmed after the response. The session is fixture data, so the type is
/// not isolated to the main actor.
nonisolated public enum DemoNestedSession {
  /// The id of the root session.
  public static let rootId = "nested-demo"

  /// The id of the child of the root.
  public static let childId = rootId + "-reviewer"

  /// The id of the child of the child.
  public static let grandchildId = rootId + "-linter"

  /// The id of the child that failed to restore.
  public static let failedChildId = rootId + "-archivist"

  /// The id of the child of the child that failed to restore.
  public static let failedGrandchildId = rootId + "-indexer"

  /// The id of the child that finishes: after the response it reports idle,
  /// and the client removes it when its tool call ends.
  public static let finishedChildId = rootId + "-formatter"

  /// The id of the `agents` tool call of the root that started the child that
  /// finishes.
  public static let finishedChildToolCallId = rootId + "-format-agents"

  /// The title of the child.
  public static let childTitle = "Reviewer"

  /// The title of the grandchild.
  public static let grandchildTitle = "Linter"

  /// The title of the child that failed to restore.
  public static let failedChildTitle = "Archivist"

  /// The reason that the child failed to restore.
  public static let failedChildReason = "the session file is missing"

  /// The reason that the child of that child failed to restore.
  public static let ancestorReason = "an ancestor was not restored"

  /// The id of the `agents` tool call of the root that started the child.
  public static let childToolCallId = rootId + "-agents"

  /// The id of the `agents` tool call of the child that started the
  /// grandchild.
  public static let grandchildToolCallId = childId + "-agents"

  /// The id of the `agents` tool call of the root that started the child that
  /// failed to restore.
  public static let failedChildToolCallId = rootId + "-archive-agents"

  /// The id of the `agents` tool call of that child that started its child.
  public static let failedGrandchildToolCallId = failedChildId + "-agents"

  /// The session, with the current snapshots of its children.
  public static let session = makeSession(withSnapshots: true)

  /// The session with no current snapshot: after the response, each child
  /// stays unconfirmed, so its state is unknown.
  public static let unconfirmedSession = makeSession(withSnapshots: false)

  /// Makes the session.
  ///
  /// - Parameter withSnapshots: Whether the agent sends the current snapshot
  ///   of each child after the response.
  /// - Returns: The scripted session.
  private static func makeSession(withSnapshots: Bool) -> DemoGallerySession {
    let root = SessionId(rawValue: rootId)
    let history =
      DemoGallery.exchange(in: rootId, prompt: "Review the change.", reply: "I ask a reviewer to read it.")
      + [
        encoded(agentsCall(childToolCallId, child: childId)),
        encoded(agentsCall(failedChildToolCallId, child: failedChildId)),
        encoded(agentsCall(finishedChildToolCallId, child: finishedChildId)),
      ]
    let failedChildAnnouncement = announcement(
      failedChildId, title: failedChildTitle, state: .running(RunningStateUpdate()), call: failedChildToolCallId)
    let finishedChildAnnouncement = announcement(
      finishedChildId, title: "Formatter", state: .running(RunningStateUpdate()), call: finishedChildToolCallId)
    let childHistory: [DemoStreamUpdate] = [
      stream(rootId, announcement(childId, title: childTitle, state: .running(RunningStateUpdate()), call: childToolCallId)),
      stream(childId, agentMessage(childId + "-reply", "I ask a linter to check the style.")),
      stream(childId, agentsCall(grandchildToolCallId, child: grandchildId)),
      stream(
        childId,
        announcement(grandchildId, title: grandchildTitle, state: .running(RunningStateUpdate()), call: grandchildToolCallId)),
      stream(grandchildId, agentMessage(grandchildId + "-reply", "The style needs a change.")),
      stream(rootId, finishedChildAnnouncement),
      stream(rootId, failedChildAnnouncement),
      stream(failedChildId, agentsCall(failedGrandchildToolCallId, child: failedGrandchildId)),
      stream(
        failedChildId,
        announcement(
          failedGrandchildId, title: "Indexer", state: .running(RunningStateUpdate()), call: failedGrandchildToolCallId)),
    ]
    let beforeResponse: [DemoStreamUpdate] = [
      stream(rootId, announcement(childId, title: childTitle, state: .running(RunningStateUpdate()), call: childToolCallId)),
      stream(rootId, finishedChildAnnouncement),
      stream(rootId, failedChildAnnouncement),
      stream(
        rootId,
        .stateUpdate(
          .running(
            RunningStateUpdate(background: [
              .subagent(BackgroundSubagent(sessionId: SessionId(rawValue: childId))),
              .subagent(BackgroundSubagent(sessionId: SessionId(rawValue: finishedChildId))),
              .subagent(BackgroundSubagent(sessionId: SessionId(rawValue: failedChildId))),
            ])))),
      stream(rootId, .sessionInfoUpdate(SessionInfoUpdate(title: .value("Nested sessions")))),
    ]
    let snapshots: [DemoStreamUpdate] =
      withSnapshots
      ? [
        stream(
          rootId,
          announcement(
            childId, title: childTitle, state: .running(RunningStateUpdate()), call: childToolCallId,
            capabilities: SubagentSessionCapabilities(cancel: SessionCancelCapabilities()))),
        stream(
          childId,
          announcement(
            grandchildId, title: grandchildTitle, state: .requiresAction(RequiresActionStateUpdate()),
            call: grandchildToolCallId, capabilities: SubagentSessionCapabilities(cancel: SessionCancelCapabilities()))),
        stream(
          rootId,
          announcement(
            finishedChildId, title: "Formatter", state: .idle(IdleStateUpdate(stopReason: .endTurn)),
            call: finishedChildToolCallId, capabilities: SubagentSessionCapabilities(cancel: SessionCancelCapabilities()))),
        stream(
          rootId,
          announcement(failedChildId, title: failedChildTitle, state: nil, call: failedChildToolCallId, failure: failedChildReason)),
        stream(
          failedChildId,
          announcement(
            failedGrandchildId, title: "Indexer", state: nil, call: failedGrandchildToolCallId, failure: ancestorReason)),
        stream(rootId, finalCall(finishedChildToolCallId, child: finishedChildId)),
      ] : []
    _ = root
    return DemoGallerySession(
      id: rootId, title: "Nested sessions", history: history,
      requests: withSnapshots ? [.permission(grandchildPermission)] : [], childUpdates: childHistory,
      beforeResponse: beforeResponse, currentSnapshots: snapshots)
  }

  /// The permission request of the grandchild.
  static let grandchildPermission = #"""
    {"sessionId": "\#(grandchildId)", "title": "Edit Greeting.swift",
     "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"},
                 {"optionId": "no", "name": "Reject", "kind": "reject_once"}]}
    """#

  /// The update and the session of its stream.
  private static func stream(_ session: String, _ update: SessionUpdate) -> DemoStreamUpdate {
    DemoStreamUpdate(sessionId: session, update: encoded(update))
  }

  /// The JSON text of an update.
  private static func encoded(_ update: SessionUpdate) -> String {
    (try? JSONValue(encoding: update).jsonString) ?? "{}"
  }

  /// A whole agent message with one text block.
  private static func agentMessage(_ id: String, _ text: String) -> SessionUpdate {
    .agentMessage(
      AgentMessage(messageId: MessageId(rawValue: id), content: .value([.text(TextContent(text: text))])))
  }

  /// The `subagent_update` that announces a child, or gives its snapshot.
  ///
  /// - Parameters:
  ///   - child: The id of the child.
  ///   - title: The title of the child.
  ///   - state: The state of the child, or `nil` for a child with no known
  ///     state.
  ///   - call: The id of the tool call that started the child, for the link
  ///     `_meta.sah.agentRun`.
  ///   - capabilities: The capabilities of the child, or `nil`.
  ///   - failure: The reason that the restore failed, or `nil`.
  /// - Returns: The update.
  static func announcement(
    _ child: String, title: String, state: StateUpdate?, call: String,
    capabilities: SubagentSessionCapabilities? = nil, failure: String? = nil
  ) -> SessionUpdate {
    var meta = try? SAH.AgentRun(toolCallId: ToolCallId(rawValue: call)).inject(into: nil)
    if let failure {
      meta = try? SAH.RestoreFailure(reason: failure).inject(into: meta)
    }
    return .subagentUpdate(
      SubagentUpdate(
        sessionId: SessionId(rawValue: child), capabilities: capabilities.map { .value($0) } ?? .unchanged,
        state: state.map { .value($0) } ?? .unchanged, title: .value(title),
        meta: meta.map { .value($0) } ?? .unchanged))
  }

  /// The final `tool_call_update` of an `agents` call. It comes after the last
  /// update of the child, and the client removes the child at it.
  static func finalCall(_ id: String, child: String) -> SessionUpdate {
    agentsCall(id, child: child, status: .completed)
  }

  /// An `agents` tool call that links to its child session.
  ///
  /// - Parameters:
  ///   - id: The id of the tool call.
  ///   - child: The id of the child session.
  ///   - status: The status of the call.
  /// - Returns: The update.
  static func agentsCall(_ id: String, child: String, status: ToolCallStatus = .inProgress) -> SessionUpdate {
    .toolCallUpdate(
      ToolCallUpdate(
        toolCallId: ToolCallId(rawValue: id), name: .value("agents"), status: .value(status),
        title: .value("Run agent"),
        meta: (try? SAH.AgentRun(sessionId: SessionId(rawValue: child)).inject(into: nil)).map { .value($0) }
          ?? .unchanged))
  }
}
