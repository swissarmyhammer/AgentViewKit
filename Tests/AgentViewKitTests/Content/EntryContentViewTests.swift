import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// The join of the adjacent text chunks of a transcript entry: a pure
/// function over the ACP blocks of the entry.
@MainActor struct EntryContentViewTests {
  /// The first text chunk of the tests.
  static let first = "One."

  /// The second text chunk of the tests.
  static let second = " Two."

  /// A resource link block that ends a run of text.
  static let link = FoundationModelsACP.ContentBlock.resourceLink(
    FoundationModelsACP.ResourceLink(name: "Guide", uri: "https://example.com/guide"))

  /// Annotations for the model only.
  static let assistantOnly = FoundationModelsACP.Annotations(audience: [.assistant])

  @Test func adjacentTextChunksWithTheSameAnnotationsJoinIntoOneBlock() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first)), .text(TextContent(text: Self.second)),
    ]

    #expect(EntryContentView.joiningAdjacentText(in: content) == [.text(TextContent(text: Self.first + Self.second))])
  }

  @Test func aBlockThatIsNotTextEndsARunOfText() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first)), Self.link, .text(TextContent(text: Self.second)),
    ]

    #expect(EntryContentView.joiningAdjacentText(in: content) == content)
  }

  @Test func textChunksWithOtherAnnotationsStaySeparate() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first)),
      .text(TextContent(text: Self.second, annotations: Self.assistantOnly)),
    ]

    #expect(EntryContentView.joiningAdjacentText(in: content) == content)
  }

  @Test func noBlocksGiveNoBlocks() {
    #expect(EntryContentView.joiningAdjacentText(in: []).isEmpty)
  }
}
