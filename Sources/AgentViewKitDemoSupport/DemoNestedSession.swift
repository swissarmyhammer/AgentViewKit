/// A scripted session with child sessions, for the gallery and the UI tests.
///
/// The model is parent and child all the way down. The session here has a
/// root, a child of the root, and a child of that child. The chain of three
/// sessions is only the size of the fixture: each rule that the views show
/// holds at each level.
///
/// - The root has an `agents` tool call that links to the child with
///   `_meta.sah.agentRun`, and the child has an `agents` tool call that links
///   to the grandchild.
/// - A resume from the start replays the three streams. After its result, the
///   agent sends the current snapshot of each child, so the children are
///   confirmed. Then it sends a permission request of the grandchild, which
///   waits for the user. The request marks the ancestors of the grandchild.
///
/// ``InMemoryDemoScript/nested`` serves the session. The session is fixture
/// data, so the type is not isolated to the main actor.
nonisolated public enum DemoNestedSession {
  /// The id of the root session.
  public static let rootId = "nested-demo"

  /// The id of the child of the root.
  public static let childId = rootId + "-reviewer"

  /// The id of the child of the child.
  public static let grandchildId = rootId + "-linter"

  /// The title of the child.
  public static let childTitle = "Reviewer"

  /// The title of the grandchild.
  public static let grandchildTitle = "Linter"

  /// The id of the `agents` tool call of the root that started the child.
  public static let childToolCallId = rootId + "-agents"

  /// The id of the `agents` tool call of the child that started the
  /// grandchild.
  public static let grandchildToolCallId = childId + "-agents"

  /// The session.
  public static let session: DemoGallerySession = {
    let history =
      DemoGallery.exchange(in: rootId, prompt: "Review the change.", reply: "I ask a reviewer to read it.")
      + [agentsToolCall(id: childToolCallId, child: childId), DemoGallery.runningState]
    let childUpdates = [
      DemoStreamUpdate(sessionId: rootId, update: announcement(childId, title: childTitle, state: "running", toolCall: childToolCallId)),
      DemoStreamUpdate(
        sessionId: childId,
        update: DemoGallery.message("agent_message", id: childId + "-reply", text: "I ask a linter to check the style.")),
      DemoStreamUpdate(sessionId: childId, update: agentsToolCall(id: grandchildToolCallId, child: grandchildId)),
      DemoStreamUpdate(
        sessionId: childId,
        update: announcement(grandchildId, title: grandchildTitle, state: "running", toolCall: grandchildToolCallId)),
      DemoStreamUpdate(
        sessionId: grandchildId,
        update: DemoGallery.message("agent_message", id: grandchildId + "-reply", text: "The style needs a change.")),
    ]
    let currentSnapshots = [
      DemoStreamUpdate(sessionId: rootId, update: announcement(childId, state: "running", toolCall: childToolCallId)),
      DemoStreamUpdate(
        sessionId: childId, update: announcement(grandchildId, state: "requires_action", toolCall: grandchildToolCallId)),
    ]
    return DemoGallerySession(
      id: rootId, title: "Nested sessions", history: history,
      requests: [.permission(grandchildPermission)], childUpdates: childUpdates, currentSnapshots: currentSnapshots)
  }()

  /// The permission request of the grandchild.
  static let grandchildPermission = #"""
    {"sessionId": "\#(grandchildId)", "title": "Edit Greeting.swift",
     "options": [{"optionId": "yes", "name": "Allow", "kind": "allow_once"},
                 {"optionId": "no", "name": "Reject", "kind": "reject_once"}]}
    """#

  /// The `subagent_update` that announces a child, or gives its snapshot.
  ///
  /// - Parameters:
  ///   - child: The id of the child.
  ///   - title: The title of the child, or `nil` for none.
  ///   - state: The wire value of the state of the child.
  ///   - toolCall: The id of the tool call that started the child. It is the
  ///     link `_meta.sah.agentRun`.
  /// - Returns: The JSON text of the update.
  static func announcement(_ child: String, title: String? = nil, state: String, toolCall: String) -> String {
    let titleMember = title.map { #""title": "\#($0)", "# } ?? ""
    return #"""
      {"sessionUpdate": "subagent_update", "sessionId": "\#(child)", \#(titleMember)"state": {"state": "\#(state)"},
       "_meta": {"sah": {"agentRun": {"toolCallId": "\#(toolCall)"}}}}
      """#
  }

  /// An `agents` tool call that links to its child session.
  ///
  /// - Parameters:
  ///   - id: The id of the tool call.
  ///   - child: The id of the child session.
  /// - Returns: The JSON text of the update.
  static func agentsToolCall(id: String, child: String) -> String {
    #"""
      {"sessionUpdate": "tool_call_update", "toolCallId": "\#(id)", "name": "agents", "title": "Run agent",
       "status": "in_progress", "_meta": {"sah": {"agentRun": {"sessionId": "\#(child)"}}}}
      """#
  }
}
