@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import PackageFileSupport
import Testing

/// Tests for the Markdown export of a thread and of a message.
@MainActor struct ThreadExporterTests {
  /// The golden Markdown file of ``fixtureThread()``.
  static let goldenPath = "Tests/AgentViewKitTests/Items/Fixtures/thread-export.md"

  /// A text block that is only for the model.
  static let hiddenBlock = ContentBlock(
    content: .text("Hidden."), annotations: Annotations(audience: [.assistant]))

  /// A structured block with one string property.
  static let chartBlock = ContentBlock(
    content: .structured(schemaName: chartSchema, payload: chartPayload))

  /// The schema name of the chart fixtures.
  static let chartSchema = "AgentViewKit.Chart"

  /// The payload of the chart fixtures.
  static let chartPayload = JSONValue.object(["title": .string("Sales")])

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
      .system(SystemPrompt(id: "system-1", text: "Answer in one line.")),
      .userMessage(ThreadFixtures.message(id: "user-1", text: "Read the README.")),
      .reasoning(
        Reasoning(
          id: "reasoning-1", segments: ["I must read the file first.\n\n", "Then I answer."])),
      .toolCall(ThreadFixtures.toolCall(id: "call-1", status: .completed)),
      .structured(
        StructuredRecord(id: "chart-1", schemaName: chartSchema, payload: chartPayload)),
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

  @Test func theMessageMarkdownHasTheTextAndTheStructuredBlocks() {
    let message = Message(
      id: "message", blocks: [ContentBlock(text: "Shown."), Self.hiddenBlock, Self.chartBlock])

    let expected = """
      Shown.

      ```json
      {
        "payload" : {
          "title" : "Sales"
        },
        "schemaName" : "AgentViewKit.Chart"
      }
      ```
      """
    #expect(ThreadExporter.markdown(for: message) == expected)
  }

  @Test func aMessageWithNoShownBlockHasNoSection() {
    let thread = AgentThread()
    let message = Message(id: "hidden", blocks: [Self.hiddenBlock])
    thread.apply(.insert(.userMessage(message), after: nil))

    #expect(ThreadExporter.markdown(for: thread).isEmpty)
  }

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
