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

  /// The third text chunk of the tests.
  static let third = " Three."

  /// The metadata of the first chunk of a run.
  static let firstMeta = JSONValue.string("first")

  /// A production change that fails this test: the one-pass join drops a
  /// chunk after the second chunk of a run.
  @Test func threeAdjacentTextChunksJoinIntoOneBlockInOrder() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first)), .text(TextContent(text: Self.second)),
      .text(TextContent(text: Self.third)),
    ]

    #expect(
      EntryContentView.joiningAdjacentText(in: content) == [
        .text(TextContent(text: Self.first + Self.second + Self.third))
      ])
  }

  /// A production change that fails this test: the joined block takes the
  /// metadata of a later chunk of its run.
  @Test func theJoinedBlockKeepsTheMetadataOfTheFirstChunk() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first, meta: Self.firstMeta)),
      .text(TextContent(text: Self.second, meta: .string("second"))),
    ]

    #expect(
      EntryContentView.joiningAdjacentText(in: content) == [
        .text(TextContent(text: Self.first + Self.second, meta: Self.firstMeta))
      ])
  }

  /// A production change that fails this test: the join puts the text of
  /// the run after a block that is not text into the run before it.
  @Test func eachRunOfTextOnEachSideOfABlockThatIsNotTextJoins() {
    let content: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: Self.first)), .text(TextContent(text: Self.second)), Self.link,
      .text(TextContent(text: Self.second)), .text(TextContent(text: Self.third)),
    ]

    #expect(
      EntryContentView.joiningAdjacentText(in: content) == [
        .text(TextContent(text: Self.first + Self.second)), Self.link,
        .text(TextContent(text: Self.second + Self.third)),
      ])
  }

  @Test func noBlocksGiveNoBlocks() {
    #expect(EntryContentView.joiningAdjacentText(in: []).isEmpty)
  }
}
