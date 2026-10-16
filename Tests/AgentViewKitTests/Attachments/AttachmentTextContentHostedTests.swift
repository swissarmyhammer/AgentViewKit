@testable import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing
import UniformTypeIdentifiers

@Suite(.serialized, .hostedSerially) @MainActor struct AttachmentTextContentHostedTests {
  @Test func aFencedBlockInAMarkdownAttachmentMountsACodeBlock() {
    let markdown = "Notes.\n\n```json\n{\"a\": 1}\n```"
    let harness = HostedViewHarness(
      AttachmentTextContent(text: markdown, type: AttachmentTextContent.markdown, filename: "notes.md"))
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "json code block")
  }
}
