import AgentViewKit
import Foundation
import FoundationModelsACP
import Testing

/// Tests for the Markdown of the content of a message entry.
@MainActor struct ThreadExporterTests {
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
