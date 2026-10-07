@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import PackageFileSupport
import Testing

/// Tests for the Markdown export of a thread and of a message.
@MainActor struct ThreadExporterTests {
  /// The golden Markdown file of ``fixtureThread()``.
  static let goldenPath = "Tests/AgentViewKitTests/Items/Fixtures/thread-export.md"

  /// A text block that is only for the model.
  static let hiddenBlock = ContentBlock(
    content: .text("Hidden."), annotations: Annotations(audience: [.assistant]))

  /// Makes a thread with one item of each kind that the export shows, and
  /// items that the export omits.
  ///
  /// - Returns: The thread.
  static func fixtureThread() -> AgentThread {
    let thread = AgentThread()
    let assistant = Message(
      id: "assistant-1",
      blocks: [
        ContentBlock(text: "The README tells how to build."),
        hiddenBlock,
        ContentBlock(content: .image(ImageContent(data: Data(), mimeType: "image/png"))),
        ContentBlock(text: "Run `swift build`."),
      ])
    let items: [ThreadItem] = [
      .userMessage(ThreadFixtures.message(id: "user-1", text: "Read the README.")),
      .reasoning(
        Reasoning(
          id: "reasoning-1", segments: ["I must read the file first.\n\n", "Then I answer."])),
      .toolCall(ThreadFixtures.toolCall(id: "call-1", status: .completed)),
      .unknown(UnknownRecord(id: "unknown-1", kind: "future_item", raw: .object([:]))),
      .assistantMessage(assistant),
    ]
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }

  @Test func theExportOfTheFixtureThreadEqualsTheGoldenFile() throws {
    let golden = try PackageFiles.text(of: Self.goldenPath)

    #expect(ThreadExporter.markdown(for: Self.fixtureThread()) == golden)
  }

  @Test func anEmptyThreadGivesAnEmptyDocument() {
    #expect(ThreadExporter.markdown(for: AgentThread()).isEmpty)
  }

  @Test func theMessageMarkdownHasTheTextBlocksForTheUser() {
    let message = Message(
      id: "message", blocks: [ContentBlock(text: "Shown."), Self.hiddenBlock, ContentBlock(text: "Also.")])

    #expect(ThreadExporter.markdown(for: message) == "Shown.\n\nAlso.")
  }

  @Test func aMessageWithNoShownBlockHasNoSection() {
    let thread = AgentThread()
    let message = Message(id: "hidden", blocks: [Self.hiddenBlock])
    thread.apply(.insert(.userMessage(message), after: nil))

    #expect(ThreadExporter.markdown(for: thread).isEmpty)
  }

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

  // MARK: - Parts

  @Test func theFenceIsLongerThanEachBacktickRunInTheText() {
    #expect(ThreadExporter.fenced("\"a\"") == "```json\n\"a\"\n```")
    #expect(ThreadExporter.fenced("\"````\"") == "`````json\n\"````\"\n`````")
  }

  @Test func theQuoteMarksEachLine() {
    #expect(ThreadExporter.quoted("One\n\nTwo") == "> One\n>\n> Two")
    #expect(ThreadExporter.quoted("") == nil)
  }

  @Test func aLocationWithALineHasTheLineInTheSummary() {
    let call = ToolCallRecord(
      id: "call", title: "Edit", kind: .edit, status: .failed,
      locations: [ToolCallLocation(path: "/a.swift", line: 7)], rawOutput: .string("No file."))

    #expect(
      ThreadExporter.toolCallSummary(call)
        == .object([
          "title": .string("Edit"), "kind": .string("edit"), "status": .string("failed"),
          "locations": .array([.string("/a.swift:7")]), "output": .string("No file."),
        ]))
  }
}
