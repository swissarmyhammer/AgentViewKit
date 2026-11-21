import AgentViewKitTestSupport
import EditorTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

@testable import AgentViewKit

@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentTextContentHostedTests {
  /// The Markdown text of the attachment tests: a paragraph and a fenced
  /// JSON block.
  static let markdown = "Notes.\n\n```json\n{\"a\": 1}\n```"

  /// A Markdown attachment shows in the rendered form of EditorKit (D185),
  /// with its fenced block in the same text view.
  @Test func aMarkdownAttachmentShowsTheRenderedForm() {
    let harness = HostedViewHarness(
      AttachmentTextContent(
        text: Self.markdown, type: AttachmentTextContent.markdown, filename: "notes.md"))
    defer { harness.close() }
    harness.render()

    let text = harness.element(identifier: RenderedMarkdownView.identifier)
    #expect(text?.value?.contains("Notes.") == true)
    #expect(text?.value?.contains("{\"a\": 1}") == true)
    #expect(harness.element(identifier: CodeBlockView.identifier) == nil)
  }

  /// The header of a fence in the rendered Markdown text is one static text
  /// with the language of the block (AVK-9.2).
  ///
  /// EditorKit makes the header from the syntax tree, and the parse runs off
  /// the main actor. Thus the test gives the view a model that it keeps, and
  /// waits for the end of the parse before it reads the header.
  @Test func theFenceOfRenderedMarkdownShowsItsLanguageInItsHeader() async {
    let model = RenderedMarkdownView.makeModel(Self.markdown)
    let harness = HostedViewHarness(RenderedMarkdownView(Self.markdown, model: model))
    defer { harness.close() }
    harness.render()

    await ResponseTextChecks.renderParsed(model, in: harness)

    #expect(harness.accessibilityElements().contains { $0.value == "json" })
  }
}
