/// The explicit id of each inspection of a client model: the view part of
/// the scheme id of each of its rows (`inspection:<id>`), and, for a
/// transcript entry from the wire, the kind of its object id
/// (``InspectableClientModel/inspectorObjectID``).
///
/// An id never follows the locale or the name of a type.
enum ClientInspectionID {
  /// The id of the inspection of a tool call.
  static let toolCall = "tool-call"

  /// The id of the inspection of a terminal.
  static let terminal = "terminal"

  /// The id of the inspection of a user message.
  static let userMessage = "user-message"

  /// The id of the inspection of an agent message.
  static let agentMessage = "agent-message"

  /// The id of the inspection of a thought.
  static let thought = "thought"

  /// The id of the inspection of a message between two sessions.
  static let sessionMessage = "session-message"

  /// The id of the inspection of a plan.
  static let plan = "plan"

  /// The id of the inspection of a compaction.
  static let compaction = "compaction"

  /// The id of the inspection of an error.
  static let error = "error"

  /// The id of the inspection of an update that the client does not know.
  static let unknownUpdate = "unknown-update"

  /// The id of the inspection of a session.
  static let session = "session"

  /// The id of the inspection of a connection.
  static let connection = "connection"

  /// The id of the inspection of an MCP server.
  static let mcpServer = "mcp-server"
}
