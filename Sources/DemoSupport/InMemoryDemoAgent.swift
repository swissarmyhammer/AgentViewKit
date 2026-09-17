import AgentViewKit
import Foundation
import FoundationModelsACP

/// The scripted ACP agent of the demo app.
///
/// The demo app binds this agent when it starts with ``launchArgument``. The
/// agent runs in the app process over an `InMemoryTransport`, so the
/// end-to-end test of the demo app needs no agent binary.
///
/// The agent answers:
///
/// - `initialize` with protocol version 2, the `session/delete` capability,
///   and one agent authentication method.
/// - `session/new` and `session/resume` with a mode option.
/// - `session/list` with one session.
/// - `session/prompt` with `{}`. Then it sends the `session/update`
///   notifications of one turn: the user message, a running state, the reply
///   in two chunks, the whole reply, a plan, the context usage, and an idle
///   state.
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

  /// The start of the id of each echoed user message.
  static let userMessageIDPrefix = "demo-user-"

  /// The id of the plan of each turn.
  static let planID = "demo-plan"

  /// The size of the context window that each turn reports.
  static let contextSize = 200_000

  /// The number of context tokens that each turn adds.
  static let tokensPerTurn = 1_200

  /// The number of text chunks of each reply.
  static let replyChunkCount = 2

  /// The id of the reply of a turn.
  ///
  /// - Parameter turn: The number of the turn, from 1.
  /// - Returns: `demo-reply-<turn>`.
  public static func replyID(turn: Int) -> String {
    replyIDPrefix + String(turn)
  }

  /// The id of the echoed user message of a turn.
  ///
  /// - Parameter turn: The number of the turn, from 1.
  /// - Returns: `demo-user-<turn>`.
  public static func userMessageID(turn: Int) -> String {
    userMessageIDPrefix + String(turn)
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
  static var initializeResult: AgentViewKit.JSONValue {
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
  static var configOptions: AgentViewKit.JSONValue {
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
  static var newSessionResult: AgentViewKit.JSONValue {
    .object(["sessionId": .string(sessionID), "configOptions": configOptions])
  }

  /// The `session/resume` result.
  static var resumeSessionResult: AgentViewKit.JSONValue {
    .object(["configOptions": configOptions])
  }

  /// The `session/list` result.
  static var listSessionsResult: AgentViewKit.JSONValue {
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

  /// The text of a `session/prompt` request: the text of each `text` block.
  ///
  /// - Parameter request: The request frame.
  /// - Returns: The joined text.
  static func promptText(of request: AgentViewKit.JSONValue) -> String {
    guard case .array(let blocks)? = request["params"]?["prompt"] else { return "" }
    return blocks.compactMap { block in
      block["type"]?.stringValue == "text" ? block["text"]?.stringValue : nil
    }.joined()
  }

  /// The notification frames of one turn.
  ///
  /// - Parameters:
  ///   - request: The `session/prompt` request frame.
  ///   - turn: The number of the turn, from 1.
  /// - Returns: The frames, in send order.
  static func turnFrames(for request: AgentViewKit.JSONValue, turn: Int) -> [String] {
    let sessionId = request["params"]?["sessionId"] ?? .string(sessionID)
    let prompt = promptText(of: request)
    let reply = replyText(to: prompt)
    let replyID = AgentViewKit.JSONValue.string(replyID(turn: turn))
    let updates: [AgentViewKit.JSONValue] =
      [
        .object([
          "sessionUpdate": .string("user_message"),
          "messageId": .string(userMessageID(turn: turn)),
          "content": .array([textBlock(prompt)]),
        ]),
        .object(["sessionUpdate": .string("state_update"), "state": .string("running")]),
      ]
      + chunks(of: reply).map { chunk in
        .object([
          "sessionUpdate": .string("agent_message_chunk"),
          "messageId": replyID,
          "content": textBlock(chunk),
        ])
      }
      + [
        .object([
          "sessionUpdate": .string("agent_message"),
          "messageId": replyID,
          "content": .array([textBlock(reply)]),
        ]),
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
    return updates.map { update in
      AgentViewKit.JSONValue.object([
        "jsonrpc": .string("2.0"),
        "method": .string("session/update"),
        "params": .object(["sessionId": sessionId, "update": update]),
      ]).jsonString
    }
  }

  /// A `text` content block.
  private static func textBlock(_ text: String) -> AgentViewKit.JSONValue {
    .object(["type": .string("text"), "text": .string(text)])
  }

  /// A plan entry with the `medium` priority.
  private static func planEntry(_ content: String, status: String) -> AgentViewKit.JSONValue {
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
