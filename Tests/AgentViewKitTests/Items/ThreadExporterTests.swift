import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests for the Markdown export of a transcript and of the content of a
/// message entry.
@MainActor struct ThreadExporterTests {
  // MARK: - Transcript of a session model

  /// The text of the user message of ``sendTurn(to:)``.
  static let question = "Read the README."

  /// The text of the agent message of ``sendTurn(to:)``, in two chunks.
  static let answerChunks = ["Run `swift ", "build`."]

  /// The text of a later agent message.
  static let laterAnswer = "Done."

  /// The number of entries of ``sendTurn(to:)``: a user message, a thought,
  /// a tool call and an agent message.
  static let turnEntryCount = 4

  /// The Markdown of the message entries of ``sendTurn(to:)``.
  static let turnMarkdown = "## User\n\n\(question)\n\n## Assistant\n\n\(answerChunks.joined())\n"

  /// The fields of the tool call of ``sendTurn(to:)``.
  static let toolCallFields = #""title": "Read README.md", "kind": "read", "status": "completed""#

  /// Sends a user message, a thought, a tool call and an agent message from
  /// the agent, and waits until the model holds the four entries. The agent
  /// message has two text chunks and a block that is only for the assistant.
  ///
  /// - Parameter session: The scripted session.
  /// - Throws: The error of the transport.
  static func sendTurn(to session: ScriptedSession) async throws {
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "export-u", block: WireBlockJSON.makeText(question)))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_thought_chunk", messageID: "export-t", block: WireBlockJSON.makeText("Think.")))
    try await session.sendUpdate(WireBlockJSON.makeToolCallUpdate(id: "export-c", fields: toolCallFields))
    let blocks = answerChunks.map(WireBlockJSON.makeText) + [AgentCommandsTests.assistantOnlyText]
    for block in blocks {
      try await session.sendUpdate(WireBlockJSON.makeChunk("agent_message_chunk", messageID: "export-m", block: block))
    }
    _ = await waitUntil { ThreadExporter.markdown(for: session.model.transcript) == turnMarkdown }
  }

  @Test func theExportOfATranscriptHasOnlyTheMessageEntriesInTranscriptOrder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    try await Self.sendTurn(to: session)

    #expect(session.model.transcript.count == Self.turnEntryCount)
    #expect(ThreadExporter.markdown(for: session.model.transcript) == Self.turnMarkdown)
  }

  @Test func aMessageEntryThatTheModelAddsIsInTheNextExport() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await Self.sendTurn(to: session)
    let expected = Self.turnMarkdown + "\n## Assistant\n\n\(Self.laterAnswer)\n"

    try await session.sendUpdate(
      WireBlockJSON.makeChunk(
        "agent_message_chunk", messageID: "export-later", block: WireBlockJSON.makeText(Self.laterAnswer)))
    _ = await waitUntil { ThreadExporter.markdown(for: session.model.transcript) == expected }

    #expect(ThreadExporter.markdown(for: session.model.transcript) == expected)
  }

  @Test func anEmptyTranscriptGivesAnEmptyDocument() {
    #expect(ThreadExporter.markdown(for: [TranscriptEntry]()).isEmpty)
  }

  // MARK: - Content of one entry

  /// Decodes ACP content blocks from JSON.
  ///
  /// - Parameter json: The JSON array of the blocks.
  /// - Returns: The blocks.
  /// - Throws: The decoding error.
  static func blocks(_ json: String) throws -> [FoundationModelsACP.ContentBlock] {
    try JSONDecoder().decode([FoundationModelsACP.ContentBlock].self, from: Data(json.utf8))
  }

  @Test func theContentMarkdownHasTheTextBlocksForTheUser() throws {
    let content = try Self.blocks(
      #"[{"type": "text", "text": "Shown."}, {"type": "image", "data": "", "mimeType": "image/png"}, "#
        + #"{"type": "text", "text": "Also."}]"#)

    #expect(ThreadExporter.markdown(for: content) == "Shown.\n\nAlso.")
  }

  @Test func contentWithNoTextForTheUserGivesAnEmptyDocument() throws {
    let content = try Self.blocks("[\(AgentCommandsTests.assistantOnlyText)]")

    #expect(ThreadExporter.markdown(for: content).isEmpty)
  }
}
