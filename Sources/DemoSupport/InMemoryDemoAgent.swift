import AgentViewKit
import Foundation
import FoundationModelsACP

/// The scripted ACP agent of the demo app.
///
/// When the demo app starts with ``launchArgument``, it runs the script of
/// this type in the app process, as ``InMemoryDemoACPAgent``, so the
/// end-to-end test of the demo app needs no agent binary. ``start(on:)`` runs
/// the same script as raw wire frames over an `InMemoryTransport`, for the
/// wire tests.
///
/// The agent answers:
///
/// - `initialize` with protocol version 2, the `session/delete` capability,
///   and one agent authentication method.
/// - `session/new` and `session/resume` with a mode option.
/// - `session/list` with one session.
/// - `session/prompt` with a new `messageId`. Before the result, it echoes
///   the prompt text in a `user_message_chunk` with the same `messageId`
///   (``ScriptedWireAgent``). After the result, it sends the `session/update`
///   notifications of one turn: a running state, the reply in two chunks, the
///   whole reply, a plan, the context usage, and an idle state.
public enum InMemoryDemoAgent {
  /// The launch argument that makes the demo app bind this agent.
  public static let launchArgument = "--in-memory-agent"

  /// The display name of the agent.
  public static let name = "In-Memory Agent"

  /// The id of the session that `session/new` gives.
  public static let sessionID = "demo-session"

  /// The title of the session that `session/list` gives.
  public static let sessionTitle = "Demo session"

  /// The working directory of the session that `session/list` gives.
  public static let sessionCwd = "/"

  /// The id of the authentication method that `initialize` gives.
  public static let authMethodID = "demo-sign-in"

  /// The id of the mode option that `session/new` gives.
  public static let modeOptionID = "mode"

  /// The start of the text of each reply.
  public static let replyPrefix = "You said: "

  /// The start of the id of each reply.
  static let replyIDPrefix = "demo-reply-"

  /// The id of the plan of each turn.
  static let planID = "demo-plan"

  /// The size of the context window that each turn reports.
  static let contextSize = 200_000

  /// The number of context tokens that each turn adds.
  static let tokensPerTurn = 1_200

  /// The number of text chunks of each reply.
  static let replyChunkCount = 2

  /// The text of the user message that a resume from the start replays.
  public static let historyPrompt = "Show the saved history"

  /// The id of the user message that a resume from the start replays.
  static let historyPromptID = "demo-history-prompt"

  /// The id of the agent message that a resume from the start replays.
  public static let historyReplyID = "demo-history-reply"

  /// The text of the agent message that a resume from the start replays.
  public static var historyReply: String {
    replyText(to: historyPrompt)
  }

  /// The id of the reply of a turn.
  ///
  /// - Parameter turn: The number of the turn, from 1.
  /// - Returns: `demo-reply-<turn>`.
  public static func replyID(turn: Int) -> String {
    replyIDPrefix + String(turn)
  }

  /// The text of the reply to a prompt.
  ///
  /// - Parameter prompt: The text of the prompt.
  /// - Returns: ``replyPrefix`` and the prompt.
  public static func replyText(to prompt: String) -> String {
    replyPrefix + prompt
  }

  /// Makes the agent on `transport` and starts it.
  ///
  /// - Parameter transport: The agent end of an `InMemoryTransport` pair.
  /// - Returns: The running agent. Call `stop()` to end it.
  public static func start(on transport: InMemoryTransport) -> ScriptedWireAgent {
    let agent = ScriptedWireAgent(transport: transport)
    agent.results = [
      "initialize": initializeResult.jsonString,
      "session/new": newSessionResult.jsonString,
      "session/resume": resumeSessionResult.jsonString,
      "session/list": listSessionsResult.jsonString,
    ]
    agent.followUps["session/prompt"] = { request, turn in
      turnFrames(for: request, turn: turn)
    }
    agent.start()
    return agent
  }

  // MARK: - Results

  /// The `initialize` result.
  static var initializeResult: JSONValue {
    .object([
      "info": .object(["name": .string(name), "version": .string("1.0.0")]),
      "protocolVersion": .number(Double(ProtocolVersion.v2.rawValue)),
      "capabilities": .object(["session": .object(["delete": .object([:])])]),
      "authMethods": .array([
        .object([
          "type": .string("agent"),
          "methodId": .string(authMethodID),
          "name": .string("Demo sign-in"),
          "description": .string("The in-memory agent accepts each sign-in."),
        ])
      ]),
    ])
  }

  /// The config options of each session: a mode option.
  static var configOptions: JSONValue {
    .array([
      .object([
        "configId": .string(modeOptionID),
        "name": .string("Mode"),
        "category": .string("mode"),
        "type": .string("select"),
        "currentValue": .string("ask"),
        "options": .array([
          .object(["value": .string("ask"), "name": .string("Ask")]),
          .object(["value": .string("code"), "name": .string("Code")]),
        ]),
      ])
    ])
  }

  /// The `session/new` result.
  static var newSessionResult: JSONValue {
    .object(["sessionId": .string(sessionID), "configOptions": configOptions])
  }

  /// The `session/resume` result.
  static var resumeSessionResult: JSONValue {
    .object(["configOptions": configOptions])
  }

  /// The `session/list` result.
  static var listSessionsResult: JSONValue {
    .object([
      "sessions": .array([
        .object([
          "sessionId": .string(sessionID),
          "cwd": .string(sessionCwd),
          "title": .string(sessionTitle),
        ])
      ])
    ])
  }

  // MARK: - Turn

  /// The notification frames of one turn, after the prompt result.
  ///
  /// - Parameters:
  ///   - request: The `session/prompt` request frame.
  ///   - turn: The number of the turn, from 1.
  /// - Returns: The frames, in send order.
  static func turnFrames(for request: JSONValue, turn: Int) -> [String] {
    turnNotifications(for: request, turn: turn).map(ScriptedWireAgent.makeSessionUpdateFrame(params:))
  }

  /// The params of the `session/update` notifications of one turn, after the
  /// prompt result.
  ///
  /// ``turnFrames(for:turn:)`` sends them as raw frames, and
  /// ``InMemoryDemoACPAgent`` sends them through an `AgentSideConnection`.
  ///
  /// - Parameters:
  ///   - request: The `session/prompt` request frame. Only its `params`
  ///     member is read.
  ///   - turn: The number of the turn, from 1.
  /// - Returns: The params, in send order.
  static func turnNotifications(for request: JSONValue, turn: Int) -> [JSONValue] {
    let sessionId = request["params"]?["sessionId"] ?? .string(sessionID)
    let reply = replyText(to: ScriptedWireAgent.promptText(of: request))
    let replyID = JSONValue.string(replyID(turn: turn))
    let updates: [JSONValue] =
      [
        .object(["sessionUpdate": .string("state_update"), "state": .string("running")])
      ]
      + chunks(of: reply).map { chunk in
        .object([
          "sessionUpdate": .string("agent_message_chunk"),
          "messageId": replyID,
          "content": ScriptedWireAgent.textBlock(text: chunk),
        ])
      }
      + [
        messageUpdate(kind: "agent_message", id: replyID, text: reply),
        .object([
          "sessionUpdate": .string("plan_update"),
          "plan": .object([
            "type": .string("items"),
            "planId": .string(planID),
            "entries": .array([
              planEntry("Read the prompt", status: "completed"),
              planEntry("Write the reply", status: "completed"),
            ]),
          ]),
        ]),
        .object([
          "sessionUpdate": .string("usage_update"),
          "used": .number(Double(tokensPerTurn * turn)),
          "size": .number(Double(contextSize)),
        ]),
        .object([
          "sessionUpdate": .string("state_update"),
          "state": .string("idle"),
          "stopReason": .string("end_turn"),
        ]),
      ]
    return notificationParams(of: updates, sessionId: sessionId)
  }

  /// The params of the `session/update` notifications that a resume from the
  /// start replays: the saved user message and the saved reply of the agent.
  ///
  /// ``InMemoryDemoACPAgent`` sends them before the result of
  /// `session/resume`, so the client puts them in the transcript of the
  /// resumed session.
  ///
  /// - Parameter sessionId: The id of the resumed session.
  /// - Returns: The params, in send order.
  static func historyNotifications(sessionId: JSONValue) -> [JSONValue] {
    let updates = [
      messageUpdate(kind: "user_message", id: .string(historyPromptID), text: historyPrompt),
      messageUpdate(kind: "agent_message", id: .string(historyReplyID), text: historyReply),
    ]
    return notificationParams(of: updates, sessionId: sessionId)
  }

  /// The params of one `session/update` notification for each update.
  ///
  /// - Parameters:
  ///   - updates: The `update` members, in send order.
  ///   - sessionId: The id of the session of the updates.
  /// - Returns: The params, in send order.
  private static func notificationParams(
    of updates: [JSONValue], sessionId: JSONValue
  ) -> [JSONValue] {
    updates.map { update in
      JSONValue.object(["sessionId": sessionId, "update": update])
    }
  }

  /// The `update` member of a whole message: one text block.
  ///
  /// - Parameters:
  ///   - kind: The `sessionUpdate` kind, `user_message` or `agent_message`.
  ///   - id: The `messageId` of the message.
  ///   - text: The text of the message.
  /// - Returns: The update.
  private static func messageUpdate(
    kind: String, id: JSONValue, text: String
  ) -> JSONValue {
    .object([
      "sessionUpdate": .string(kind),
      "messageId": id,
      "content": .array([ScriptedWireAgent.textBlock(text: text)]),
    ])
  }

  /// A plan entry with the `medium` priority.
  private static func planEntry(_ content: String, status: String) -> JSONValue {
    .object(["content": .string(content), "priority": .string("medium"), "status": .string(status)])
  }

  /// The text chunks of a reply: ``replyChunkCount`` parts of about the same
  /// length, or the whole text when it is too short.
  ///
  /// - Parameter text: The reply.
  /// - Returns: The chunks. Joined, they are `text`.
  static func chunks(of text: String) -> [String] {
    guard text.count >= replyChunkCount else { return [text] }
    let middle = text.index(text.startIndex, offsetBy: text.count / replyChunkCount)
    return [String(text[..<middle]), String(text[middle...])]
  }
}
