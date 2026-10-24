/// The scripted sessions of the Gallery tab of the demo app.
///
/// The recorded sessions of FoundationModelsACPAgent do not have each entry
/// kind and each state that the kit views show, and the agent cannot make
/// some of them. ``InMemoryDemoACPAgent`` serves these sessions with the
/// ``InMemoryDemoScript/gallery`` script, so that the Gallery shows the
/// views of those kinds next to the recorded sessions:
///
/// - a permission request, a form elicitation and a URL elicitation, which
///   the agent sends after each resume and which wait for the user. These
///   sessions end in `requires_action`, as other agents send it,
/// - a permission request that waits while the session is idle, as
///   FoundationModelsACPAgent reports it (it never sends `requires_action`),
/// - a plan, compactions of each status, notices of each severity, an error,
///   and the attachments of a user message,
/// - one session for each stop reason that no recorded session has.
///
/// Each session is fixture data. Only the tests of the waiting sessions read
/// the content: the last state and the requests. The values are
/// constant data, so the type is not isolated to the main actor, and
/// ``InMemoryDemoACPAgent`` reads them from its own actor.
nonisolated public enum DemoGallery {
  /// The start of the id of each scripted session.
  static let idPrefix = "gallery-"

  /// The stop reasons that get a session of their own: the ACP stop reasons
  /// other than `end_turn`, `cancelled` and `error`, and the extension stop
  /// reasons of FoundationModelsACPAgent. A recorded session has `cancelled`,
  /// and ``error`` has `error`.
  static let stopReasons = [
    "max_tokens", "max_turn_requests", "refusal", "_truncated", "_ended_in_reasoning", "_repeated",
    "_reasoning_limit", "_error", "_no_output", "_stalled",
  ]

  /// The path of the source file that the permission session edits.
  static let greetingPath = "/project/Greeting.swift"

  /// The scripted sessions, in list order.
  public static let sessions: [DemoGallerySession] =
    [permission, idlePermission, formElicitation, urlElicitation, plan, compaction, notices, error, attachments]
    + stopReasons.map(makeStopReasonSession)

  // MARK: - Sessions

  /// A pending edit, and a permission request for it with each option kind.
  ///
  /// The edit names its file as a location, so the expanded call shows a
  /// location chip that selects the file in the inspector.
  static let permission: DemoGallerySession = {
    let id = idPrefix + "permission"
    let toolCallID = id + "-edit"
    let pendingEdit = #"""
      {"sessionUpdate": "tool_call_update", "toolCallId": "\#(toolCallID)", "title": "Edit Greeting.swift",
       "kind": "edit", "status": "pending", "locations": [{"path": "\#(greetingPath)", "line": 2}]}
      """#
    return waitingSession(
      id: id, title: "Permission request", prompt: "Change the greeting in Greeting.swift.",
      reply: "I will edit Greeting.swift. The edit needs your permission.", pending: [pendingEdit],
      requests: [
        .permission(
          #"""
          {"sessionId": "\#(id)", "title": "Edit Greeting.swift",
           "description": "The agent changes the text of the greeting.",
           "subject": {"type": "tool_call", "toolCall": {"toolCallId": "\#(toolCallID)"}},
           "options": [{"optionId": "allow-once", "name": "Allow", "kind": "allow_once"},
                       {"optionId": "allow-always", "name": "Always Allow", "kind": "allow_always"},
                       {"optionId": "reject-once", "name": "Reject", "kind": "reject_once"},
                       {"optionId": "reject-always", "name": "Always Reject", "kind": "reject_always"}]}
          """#)
      ])
  }()

  /// A permission request that waits while the agent reports idle.
  ///
  /// FoundationModelsACPAgent never sends `requires_action`: its prompt ends
  /// with `idle` and the `end_turn` stop reason, and a question that comes
  /// after it waits with no prompt open. The other waiting sessions end in
  /// `requires_action`, as other agents send it.
  static let idlePermission: DemoGallerySession = {
    let id = idPrefix + "idle-permission"
    let toolCallID = id + "-run"
    let pendingRun = #"""
      {"sessionUpdate": "tool_call_update", "toolCallId": "\#(toolCallID)", "title": "Run the test suite",
       "kind": "execute", "status": "pending"}
      """#
    return turnSession(
      id: id, title: "Permission request while idle", prompt: "Run the tests after the build.",
      reply: "The build is complete. The test run needs your permission.",
      then: [pendingRun, idleState(stopReason: "end_turn")],
      requests: [
        .permission(
          #"""
          {"sessionId": "\#(id)", "title": "Run the test suite",
           "subject": {"type": "tool_call", "toolCall": {"toolCallId": "\#(toolCallID)"}},
           "options": [{"optionId": "allow-once", "name": "Allow", "kind": "allow_once"},
                       {"optionId": "reject-once", "name": "Reject", "kind": "reject_once"}]}
          """#)
      ])
  }()

  /// A form elicitation with a field of each kind.
  static let formElicitation: DemoGallerySession = {
    let id = idPrefix + "form-elicitation"
    return waitingSession(
      id: id, title: "Form elicitation", prompt: "Deploy the new release.",
      reply: "I need some details before the deployment.",
      requests: [
        .elicitation(
          #"""
          {"sessionId": "\#(id)", "mode": "form", "message": "Give the details of the deployment.",
           "requestedSchema": {"type": "object",
             "properties": {
               "name": {"type": "string", "title": "Release name",
                        "description": "The name that the release notes show.", "minLength": 1},
               "environment": {"type": "string", "title": "Environment",
                               "oneOf": [{"const": "staging", "title": "Staging"},
                                         {"const": "production", "title": "Production"}]},
               "replicas": {"type": "integer", "title": "Replicas", "minimum": 1, "maximum": 10, "default": 2},
               "notify": {"type": "boolean", "title": "Tell the team", "default": true},
               "contact": {"type": "string", "title": "Contact email", "format": "email"}},
             "required": ["name", "environment"]}}
          """#)
      ])
  }()

  /// A URL elicitation that asks for a sign-in in the browser.
  static let urlElicitation: DemoGallerySession = {
    let id = idPrefix + "url-elicitation"
    return waitingSession(
      id: id, title: "URL elicitation", prompt: "Open the issues of this week.",
      reply: "The issue tracker needs a sign-in first.",
      requests: [
        .elicitation(
          #"""
          {"sessionId": "\#(id)", "mode": "url", "message": "Sign in to the issue tracker to continue.",
           "url": "https://example.com/authorize", "elicitationId": "\#(id)"}
          """#)
      ])
  }()

  /// A plan with an entry of each status and each priority.
  static let plan: DemoGallerySession = {
    let id = idPrefix + "plan"
    let planUpdate = #"""
      {"sessionUpdate": "plan_update", "plan": {"type": "items", "planId": "\#(id)",
       "entries": [{"content": "Read the failing test", "priority": "high", "status": "completed"},
                   {"content": "Find the cause of the failure", "priority": "high", "status": "in_progress"},
                   {"content": "Change the parser", "priority": "medium", "status": "pending"},
                   {"content": "Run the full test suite", "priority": "low", "status": "pending"}]}}
      """#
    return turnSession(
      id: id, title: "Plan", prompt: "Fix the failing parser test.", reply: "I made a plan. I am at the second step.",
      then: [planUpdate, runningState])
  }()

  /// A compaction of each status, and the context usage after them.
  static let compaction: DemoGallerySession = {
    let id = idPrefix + "compaction"
    let compactions = [
      #"""
      {"sessionUpdate": "compaction_update", "compactionId": "\#(id)-completed", "status": "completed",
       "summary": [{"type": "text", "text": "The user wants a faster build. The cache is on. The next step is the test run."}]}
      """#,
      #"""
      {"sessionUpdate": "compaction_update", "compactionId": "\#(id)-failed", "status": "failed",
       "error": "The model context is too small for a summary."}
      """#,
      #"{"sessionUpdate": "compaction_update", "compactionId": "\#(id)-cancelled", "status": "cancelled"}"#,
      #"{"sessionUpdate": "compaction_update", "compactionId": "\#(id)-running", "status": "in_progress"}"#,
    ]
    return turnSession(
      id: id, title: "Compaction", prompt: "Make the build faster.", reply: "I turned on the build cache.",
      then: compactions + [#"{"sessionUpdate": "usage_update", "used": 168000, "size": 200000}"#, runningState])
  }()

  /// A notice of each severity.
  static let notices: DemoGallerySession = {
    let id = idPrefix + "notices"
    let notices = [
      notice(
        severity: "info", title: "A new model version is available",
        description: "The agent uses the new version in the next session."),
      notice(
        severity: "warning", title: "The quota is almost used",
        description: "You used 90 percent of the monthly quota."),
      notice(
        severity: "error", title: "The search index is not available",
        description: "The agent cannot search the project until the index is built again."),
    ]
    return turnSession(
      id: id, title: "Notices", prompt: "Search the project for the parser.", reply: "I read the parser files.",
      then: notices + [idleState(stopReason: "end_turn")])
  }()

  /// A failed tool call, and a response that stopped with an error.
  static let error: DemoGallerySession = {
    let id = idPrefix + "error"
    let failedToolCall = #"""
      {"sessionUpdate": "tool_call_update", "toolCallId": "\#(id)-migrate", "title": "Run the migration",
       "kind": "execute", "status": "failed"}
      """#
    let erroredState = #"""
      {"sessionUpdate": "state_update", "state": "idle", "stopReason": "error",
       "error": {"code": -32603, "message": "The model stopped with an internal error."}}
      """#
    return turnSession(
      id: id, title: "Error", prompt: "Run the database migration.", reply: "I run the migration now.",
      then: [failedToolCall, erroredState])
  }()

  /// A user message with an image, a resource link, and an embedded
  /// resource.
  static let attachments: DemoGallerySession = {
    let id = idPrefix + "attachments"
    let prompt = #"""
      {"sessionUpdate": "user_message", "messageId": "\#(id)-prompt",
       "content": [{"type": "text", "text": "Compare the screenshot with the notes and the code."},
                   {"type": "image", "mimeType": "image/png", "data": "\#(screenshotPNG)"},
                   {"type": "resource_link", "uri": "file:///project/notes.md", "name": "notes.md",
                    "mimeType": "text/markdown", "size": 48},
                   {"type": "resource", "resource": {"uri": "file://\#(greetingPath)", "mimeType": "text/x-swift",
                    "text": "struct Greeting {\n  let text = \"Hello\"\n}\n"}}]}
      """#
    let reply = message("agent_message", id: id + "-reply", text: "The screenshot, the notes and the code agree.")
    return DemoGallerySession(
      id: id, title: "Attachments", history: [prompt, reply, idleState(stopReason: "end_turn")], requests: [])
  }()

  /// Makes the session of one stop reason: one prompt whose work ends with
  /// an idle state with that stop reason.
  ///
  /// - Parameter stopReason: The wire value of the stop reason.
  /// - Returns: The session.
  static func makeStopReasonSession(_ stopReason: String) -> DemoGallerySession {
    turnSession(
      id: idPrefix + "stop-" + stopReason, title: "Stop reason \(stopReason)", prompt: "Write the release notes.",
      reply: "The release notes start with", then: [idleState(stopReason: stopReason)])
  }

  // MARK: - Session shapes

  /// Makes a session of one prompt: a prompt of the user, the reply of the
  /// agent, and the updates after the reply.
  ///
  /// - Parameters:
  ///   - id: The id of the session. The message ids start with it.
  ///   - title: The title that `session/list` gives.
  ///   - prompt: The text of the user message.
  ///   - reply: The text of the agent message.
  ///   - updates: The JSON text of the updates after the reply.
  ///   - requests: The requests that the agent sends after each resume.
  /// - Returns: The session.
  static func turnSession(
    id: String, title: String, prompt: String, reply: String, then updates: [String],
    requests: [DemoAgentRequest] = []
  ) -> DemoGallerySession {
    DemoGallerySession(
      id: id, title: title, history: exchange(in: id, prompt: prompt, reply: reply) + updates, requests: requests)
  }

  /// Makes a session of one prompt that waits for the user: a prompt of the
  /// user, the reply of the agent, the pending updates, and the
  /// ``requiresActionState``. The agent sends the requests after each
  /// resume.
  ///
  /// - Parameters:
  ///   - id: The id of the session. The message ids start with it.
  ///   - title: The title that `session/list` gives.
  ///   - prompt: The text of the user message.
  ///   - reply: The text of the agent message.
  ///   - pending: The JSON text of the updates between the reply and the
  ///     state, for example a pending tool call.
  ///   - requests: The requests that wait for the user.
  /// - Returns: The session.
  static func waitingSession(
    id: String, title: String, prompt: String, reply: String, pending: [String] = [],
    requests: [DemoAgentRequest]
  ) -> DemoGallerySession {
    turnSession(
      id: id, title: title, prompt: prompt, reply: reply, then: pending + [requiresActionState], requests: requests)
  }

  // MARK: - Updates

  /// The bytes of a small PNG image, in Base64: a square of 16 by 16 pixels
  /// with a color gradient.
  static let screenshotPNG =
    "iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAIAAACQkWg2AAABlklEQVR42g3LQQEAIQgAQSMQwQhEIIIRjEAEIhjBCETguU8jGMEId/Of1hrS6A1tWGM0ZsMb0ViN3chGNU7jNl6jNUGELqhgwhCm4EIIS9hCCiUc4QpP/tCRTu9oxzqjMzveic7q7E52qnM6t/P6HxRRuqKKKUOZiiuhLGUrqZRylKs8/YMhRjfUMGMY03AjjGVsI40yjnGNZ38YyKAPdGCDMZgDH8RgDfYgBzU4gzt44w8TmfSJTmwyJnPik5isyZ7kpCZncidv/sERpzvqmDOc6bgTznK2k045x7nO8z8EEvRAAwtGMAMPIljBDjKo4AQ3ePGHhSz6Qhe2GIu58EUs1mIvclGLs7iLt/6wkU3f6MY2YzM3vonN2uxNbmpzNnfz9h8SSXqiiSUjmYknkaxkJ5lUcpKbvPxDIUUvtLBiFLPwIopV7CKLKk5xi1d/OMihH/Rgh3GYBz/EYR32IQ91OId7eOcPF7n0i17sMi7z4pe4rMu+5KUu53Iv7/7hIY/+0Ic9xmM+/BGP9diPfNTjPO7jPT6GdLgQ8hjYogAAAABJRU5ErkJggg=="

  /// The `state_update` of an agent that waits for the user, as other
  /// agents send it.
  static let requiresActionState = #"{"sessionUpdate": "state_update", "state": "requires_action"}"#

  /// The `state_update` of an agent that runs.
  static let runningState = #"{"sessionUpdate": "state_update", "state": "running"}"#

  /// The `state_update` of an agent that stopped its work.
  ///
  /// - Parameter stopReason: The wire value of the stop reason.
  /// - Returns: The JSON text of the update.
  static func idleState(stopReason: String) -> String {
    #"{"sessionUpdate": "state_update", "state": "idle", "stopReason": "\#(stopReason)"}"#
  }

  /// A whole message with one text block.
  ///
  /// - Parameters:
  ///   - kind: The `sessionUpdate` kind, `user_message` or `agent_message`.
  ///   - id: The `messageId` of the message.
  ///   - text: The text of the message. It holds no character that JSON
  ///     escapes.
  /// - Returns: The JSON text of the update.
  static func message(_ kind: String, id: String, text: String) -> String {
    #"{"sessionUpdate": "\#(kind)", "messageId": "\#(id)", "content": [{"type": "text", "text": "\#(text)"}]}"#
  }

  /// A prompt of the user and the reply of the agent.
  ///
  /// - Parameters:
  ///   - sessionID: The id of the session. The message ids start with it.
  ///   - prompt: The text of the user message.
  ///   - reply: The text of the agent message.
  /// - Returns: The JSON text of the two updates.
  static func exchange(in sessionID: String, prompt: String, reply: String) -> [String] {
    [
      message("user_message", id: sessionID + "-prompt", text: prompt),
      message("agent_message", id: sessionID + "-reply", text: reply),
    ]
  }

  /// A `notice` update.
  ///
  /// - Parameters:
  ///   - severity: The wire value of the severity.
  ///   - title: The title of the notice.
  ///   - description: The description of the notice.
  /// - Returns: The JSON text of the update.
  static func notice(severity: String, title: String, description: String) -> String {
    #"""
    {"sessionUpdate": "notice", "severity": "\#(severity)", "title": "\#(title)", "description": "\#(description)"}
    """#
  }
}
