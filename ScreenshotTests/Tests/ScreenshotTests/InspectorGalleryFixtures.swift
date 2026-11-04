@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorInspector
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The models of the inspector images: two of each client model, with
/// different values, from a scripted session whose agent sends one update of
/// each kind of entry twice.
@MainActor
struct InspectorGalleryFixtures {
  /// The scripted session whose transcript holds the entries.
  let session: ScriptedSession

  /// The updates that the agent sends: two of each kind of entry, each pair
  /// with different values.
  private static let updates: [String] = [
    WireBlockJSON.makeChunk("user_message_chunk", messageID: "user-1", block: WireBlockJSON.makeText("Fix the parser.")),
    WireBlockJSON.makeChunk("user_message_chunk", messageID: "user-2", block: WireBlockJSON.makeText("Then run the tests.")),
    WireBlockJSON.makeChunk(
      "agent_message_chunk", messageID: "agent-1", block: WireBlockJSON.makeText("The parser reads one token too far.")),
    WireBlockJSON.makeChunk("agent_message_chunk", messageID: "agent-2", block: WireBlockJSON.makeText("Each test passes.")),
    WireBlockJSON.makeChunk(
      "agent_thought_chunk", messageID: "thought-1", block: WireBlockJSON.makeText("The loop ends one step late.")),
    WireBlockJSON.makeChunk("agent_thought_chunk", messageID: "thought-2", block: WireBlockJSON.makeText("Run the suite.")),
    WireBlockJSON.makeToolCallUpdate(
      id: "call-1", fields: #""title": "Read Sources/Parser/Lexer.swift", "kind": "read", "status": "completed""#),
    WireBlockJSON.makeToolCallUpdate(
      id: "call-2", fields: #""title": "Edit Sources/Parser/Lexer.swift", "kind": "edit", "status": "in_progress""#),
    #"{"sessionUpdate": "terminal_update", "terminalId": "terminal-1", "command": "swift build", "exitStatus": {"exitCode": 0}}"#,
    #"{"sessionUpdate": "terminal_update", "terminalId": "terminal-2", "command": "swift test"}"#,
    planUpdate(id: "plan-1", firstStatus: "completed"),
    planUpdate(id: "plan-2", firstStatus: "in_progress"),
    #"{"sessionUpdate": "compaction_update", "compactionId": "compaction-1", "status": "completed"}"#,
    #"{"sessionUpdate": "compaction_update", "compactionId": "compaction-2", "status": "in_progress"}"#,
    sessionMessage(id: "mail-1", from: "child-1", text: "The lexer change is ready."),
    sessionMessage(id: "mail-2", from: "child-2", text: "The tests pass."),
    #"{"sessionUpdate": "x_board_update", "note": "first"}"#,
    #"{"sessionUpdate": "x_index_update", "note": "second"}"#,
  ]

  /// The number of entries of one kind that a subject shows: one, and a
  /// second beside it for the Mixed image.
  private static let pairCount = 2

  /// A `plan_update` of two steps.
  ///
  /// - Parameters:
  ///   - id: The id of the plan.
  ///   - firstStatus: The wire status of the first step.
  /// - Returns: The JSON text of the update.
  private static func planUpdate(id: String, firstStatus: String) -> String {
    #"""
    {"sessionUpdate": "plan_update", "plan": {"type": "items", "planId": "\#(id)",
     "entries": [{"content": "Read the failing test", "priority": "high", "status": "\#(firstStatus)"},
                 {"content": "Change the parser", "priority": "medium", "status": "pending"}]}}
    """#
  }

  /// A `session_message` from another session.
  ///
  /// - Parameters:
  ///   - id: The id of the message.
  ///   - from: The id of the session that sent it.
  ///   - text: The text of the message.
  /// - Returns: The JSON text of the update.
  private static func sessionMessage(id: String, from: String, text: String) -> String {
    #"{"sessionUpdate": "session_message", "messageId": "\#(id)", "senderSessionId": "\#(from)", "content": [\#(WireBlockJSON.makeText(text))]}"#
  }

  /// Opens the scripted session and sends ``updates``.
  ///
  /// The connection model reads a `FixedClock` from
  /// `TimedSessionClock.start` that moves `TimedSessionClock.stepSeconds`
  /// after the model takes each update, so the Time group of each entry shows a known start
  /// and end, and the duration row of each entry that ended.
  ///
  /// - Returns: The fixtures, once each entry is in the transcript.
  /// - Throws: The error of the session or of the transport.
  static func open() async throws -> InspectorGalleryFixtures {
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    let model = session.model
    for (index, update) in updates.enumerated() {
      try await session.sendUpdate(update)
      await ObservationWait.until(within: TimingGalleryFixtures.settleLimit) { model.transcript.count > index }
      clock.advance(by: TimedSessionClock.stepSeconds)
    }
    return InspectorGalleryFixtures(session: session)
  }

  /// Closes the scripted session.
  func close() {
    session.close()
  }

  /// The subjects of the client models, the config options and the tool
  /// toggles.
  var subjects: [InspectorGallery.Subject] {
    get throws {
      let tools = [
        ToolToggle(id: ToolToggleID("web-search"), name: "Web search", isEnabled: true),
        ToolToggle(id: ToolToggleID("terminal"), name: "Terminal", isEnabled: false),
      ]
      let servers = PreviewFixtures.mcpSession.mcpServers
      return [
        InspectorGallery.Subject(
          "config-options", view: ConfigOptionsView(session: PreviewFixtures.configuredSession, style: .form)),
        InspectorGallery.Subject("tool-toggles", view: ToolToggles(tools: tools, style: .list) { _, _ in }),
        InspectorGallery.Subject("session", PreviewFixtures.usageSession, PreviewFixtures.configuredSession),
        InspectorGallery.Subject("connection", ConnectionModel.preview(), ConnectionModel.preview(state: .connecting)),
        InspectorGallery.Subject("mcp-server", try #require(servers.first), try #require(servers.last)),
        try pair("user-message", UserMessageEntry.self),
        try pair("agent-message", AgentMessageEntry.self),
        try pair("thought", ThoughtEntry.self),
        try pair("tool-call", ToolCallEntry.self),
        try pair("terminal", TerminalEntry.self),
        try pair("plan", PlanTranscriptEntry.self),
        try pair("compaction", CompactionEntry.self),
        try pair("session-message", SessionMessageEntry.self),
        try pair("unknown", UnknownEntry.self),
        InspectorGallery.Subject(
          "error",
          try #require(PreviewFixtures.entry(.error(code: .internalError, message: "The agent stopped."), as: ErrorEntry.self)),
          try #require(PreviewFixtures.entry(.error(code: .invalidParams, message: "The path is not absolute."), as: ErrorEntry.self))),
      ]
    }
  }

  /// The subject of the first two entries of `type` in the transcript.
  ///
  /// - Parameters:
  ///   - name: The name of the subject.
  ///   - type: The class of the entries.
  /// - Returns: The subject.
  /// - Throws: When the transcript has fewer than two entries of the type.
  private func pair<Entry: Inspectable>(_ name: String, _ type: Entry.Type) throws -> InspectorGallery.Subject {
    let entries = session.model.transcript.compactMap { $0.object as? Entry }
    try #require(entries.count >= Self.pairCount, "The transcript has \(entries.count) entries of \(type).")
    let pair = entries.prefix(Self.pairCount)
    return InspectorGallery.Subject(name, try #require(pair.first), try #require(pair.last))
  }
}
