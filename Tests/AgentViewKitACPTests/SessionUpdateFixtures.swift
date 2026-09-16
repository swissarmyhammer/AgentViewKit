import AgentViewKitACP
import Foundation
import FoundationModelsACP

/// JSON fixtures of ACP v2 `session/update` values, and the decoder of the
/// ACP wire package.
enum SessionUpdateFixtures {
  /// One fixture for each case of `SessionUpdate`, keyed by its
  /// `sessionUpdate` tag. The key `unknown` holds a tag that the wire package
  /// does not know.
  static let byTag: [String: String] = [
    "user_message_chunk": userMessageChunk,
    "user_message": userMessage,
    "agent_message_chunk": agentMessageChunk,
    "agent_message": agentMessage,
    "agent_thought_chunk": agentThoughtChunk,
    "agent_thought": agentThought,
    "state_update": stateIdle,
    "tool_call_content_chunk": toolCallDiffChunk,
    "tool_call_update": toolCallUpdate,
    "terminal_update": terminalUpdate,
    "terminal_output_chunk": terminalOutputChunk,
    "plan_update": planUpdate,
    "available_commands_update": availableCommands,
    "config_option_update": flatConfigOptions,
    "session_info_update": sessionInfo,
    "usage_update": usage,
    "unknown": unknownUpdate,
  ]

  static let userMessageChunk = """
    {"sessionUpdate": "user_message_chunk", "messageId": "u1",
     "content": {"type": "text", "text": "Fix the bug."}, "_meta": {"source": "replay"}}
    """

  static let userMessage = """
    {"sessionUpdate": "user_message", "messageId": "u1",
     "content": [{"type": "text", "text": "Fix it."}], "_meta": {"edited": true}}
    """

  static let agentMessageChunk = """
    {"sessionUpdate": "agent_message_chunk", "messageId": "m1",
     "content": {"type": "text", "text": "Hello"}}
    """

  static let agentMessage = """
    {"sessionUpdate": "agent_message", "messageId": "m1",
     "content": [{"type": "text", "text": "Done."}], "_meta": {"model": "a"}}
    """

  static let agentThoughtChunk = """
    {"sessionUpdate": "agent_thought_chunk", "messageId": "t1",
     "content": {"type": "text", "text": "Think"}}
    """

  static let agentThought = """
    {"sessionUpdate": "agent_thought", "messageId": "t1",
     "content": [{"type": "text", "text": "Plan"}, {"type": "text", "text": "Act"}]}
    """

  static let stateIdle = """
    {"sessionUpdate": "state_update", "state": "idle", "stopReason": "max_tokens"}
    """

  static let toolCallDiffChunk = """
    {"sessionUpdate": "tool_call_content_chunk", "toolCallId": "c1",
     "content": {"type": "diff", "changes": [],
                 "patch": {"format": "git_patch", "text": "--- a\\n+++ b\\n"}},
     "_meta": {"chunk": 1}}
    """

  static let toolCallUpdate = """
    {"sessionUpdate": "tool_call_update", "toolCallId": "c1", "title": "Read file",
     "kind": "read", "status": "_lost",
     "content": [{"type": "content", "content": {"type": "text", "text": "body"}},
                 {"type": "terminal", "terminalId": "term1"}],
     "locations": [{"path": "/tmp/a.swift", "line": 3}],
     "rawInput": {"path": "/tmp/a.swift"}, "rawOutput": null, "_meta": {"x": 1}}
    """

  static let terminalUpdate = """
    {"sessionUpdate": "terminal_update", "terminalId": "term1", "command": "ls",
     "cwd": "/tmp", "exitStatus": {"exitCode": 0, "signal": null},
     "output": {"data": "aGk="}, "_meta": {"tty": true}}
    """

  static let terminalOutputChunk = """
    {"sessionUpdate": "terminal_output_chunk", "terminalId": "term1", "data": "IQ=="}
    """

  static let planUpdate = """
    {"sessionUpdate": "plan_update",
     "plan": {"type": "items", "planId": "p1",
              "entries": [{"content": "Read", "priority": "high", "status": "in_progress"},
                          {"content": "Ship", "priority": "urgent", "status": "pending"}]}}
    """

  static let availableCommands = """
    {"sessionUpdate": "available_commands_update",
     "availableCommands": [{"name": "review", "description": "Review the code",
                            "input": {"type": "text", "hint": "path"}},
                           {"name": "clear", "description": "Clear the thread"}]}
    """

  static let flatConfigOptions = """
    {"sessionUpdate": "config_option_update",
     "configOptions": [{"configId": "mode", "name": "Mode", "category": "mode",
                        "type": "select", "currentValue": "ask",
                        "options": [{"value": "ask", "name": "Ask"},
                                    {"value": "code", "name": "Code"}]},
                       {"configId": "web", "name": "Web", "type": "boolean",
                        "currentValue": true}]}
    """

  static let groupedConfigOptions = """
    {"sessionUpdate": "config_option_update",
     "configOptions": [{"configId": "model", "name": "Model", "category": "model",
                        "type": "select", "currentValue": "fast",
                        "options": [{"groupId": "local", "name": "Local",
                                     "options": [{"value": "fast", "name": "Fast"}]},
                                    {"groupId": "cloud", "name": "Cloud",
                                     "options": [{"value": "big", "name": "Big"}]}]}]}
    """

  static let unknownConfigOption = """
    {"sessionUpdate": "config_option_update",
     "configOptions": [{"configId": "level", "name": "Level", "type": "slider",
                        "min": 0}]}
    """

  static let sessionInfo = """
    {"sessionUpdate": "session_info_update", "title": "Bug hunt",
     "updatedAt": "2026-09-16T10:00:00Z"}
    """

  static let usage = """
    {"sessionUpdate": "usage_update", "used": 1200, "size": 200000,
     "cost": {"amount": 0.25, "currency": "USD"}}
    """

  static let unknownUpdate = """
    {"sessionUpdate": "mood_update", "mood": "happy"}
    """

  /// Decodes a session update with the ACP wire decoder.
  ///
  /// - Parameter json: The JSON text of the update.
  /// - Returns: The decoded update.
  static func decode(_ json: String) throws -> SessionUpdate {
    try JSONDecoder().decode(SessionUpdate.self, from: Data(json.utf8))
  }

  /// Decodes a value of an ACP wire type.
  ///
  /// - Parameters:
  ///   - type: The type to decode.
  ///   - json: The JSON text of the value.
  /// - Returns: The decoded value.
  static func decode<Value: Decodable>(_ type: Value.Type, _ json: String) throws -> Value {
    try JSONDecoder().decode(type, from: Data(json.utf8))
  }

  /// The `sessionUpdate` tag of an update.
  ///
  /// The switch has no default case, so a new case of `SessionUpdate` stops
  /// the build until it has a tag and a fixture.
  static func tag(of update: SessionUpdate) -> String {
    switch update {
    case .userMessageChunk: "user_message_chunk"
    case .userMessage: "user_message"
    case .agentMessageChunk: "agent_message_chunk"
    case .agentMessage: "agent_message"
    case .agentThoughtChunk: "agent_thought_chunk"
    case .agentThought: "agent_thought"
    case .stateUpdate: "state_update"
    case .toolCallContentChunk: "tool_call_content_chunk"
    case .toolCallUpdate: "tool_call_update"
    case .terminalUpdate: "terminal_update"
    case .terminalOutputChunk: "terminal_output_chunk"
    case .planUpdate: "plan_update"
    case .availableCommandsUpdate: "available_commands_update"
    case .configOptionUpdate: "config_option_update"
    case .sessionInfoUpdate: "session_info_update"
    case .usageUpdate: "usage_update"
    case .unknown: "unknown"
    }
  }
}

/// A pending permission request that a test makes.
struct TestPermission: PendingPermissionRequestValue {
  /// The local id of the request.
  var id: UUID

  /// The request as the agent sent it.
  var request: RequestPermissionRequest
}

/// A pending elicitation that a test makes.
struct TestElicitation: PendingElicitationValue {
  /// The local id of the elicitation.
  var id: UUID

  /// The request as the agent sent it.
  var request: CreateElicitationRequest
}
