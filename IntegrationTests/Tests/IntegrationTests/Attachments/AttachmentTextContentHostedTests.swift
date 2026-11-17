@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentTextContentHostedTests {
  /// A Markdown attachment shows in the rendered form of EditorKit (D185),
  /// with its fenced block in the same text view. The header of the fence
  /// is one static text with the language of the block (AVK-9.2).
  @Test func aMarkdownAttachmentShowsTheRenderedForm() {
    let markdown = "Notes.\n\n```json\n{\"a\": 1}\n```"
    let harness = HostedViewHarness(
      AttachmentTextContent(text: markdown, type: AttachmentTextContent.markdown, filename: "notes.md"))
    defer { harness.close() }
    harness.render()

    let text = harness.element(identifier: RenderedMarkdownView.identifier)
    #expect(text?.value?.contains("Notes.") == true)
    #expect(text?.value?.contains("{\"a\": 1}") == true)
    #expect(harness.element(identifier: CodeBlockView.identifier) == nil)
    #expect(harness.accessibilityElements().contains { $0.value == "json" })
  }
}
