import AgentViewKit
import Foundation
import Testing

@Suite struct ContentBlockTests {
  /// A text block with the given audience and priority.
  private static func text(
    _ text: String,
    audience: [Audience]? = nil,
    priority: Double? = nil
  ) -> ContentBlock {
    ContentBlock(
      content: .text(text),
      annotations: Annotations(audience: audience, priority: priority)
    )
  }

  // MARK: - Audience

  @Test func aBlockWithNoAnnotationsIsVisibleToEachAudience() {
    let block = ContentBlock.text("Hello")

    #expect(block.annotations == nil)
    #expect(block.isVisible(to: .user))
    #expect(block.isVisible(to: .assistant))
  }

  @Test func aBlockWithNoAudienceIsVisibleToEachAudience() {
    let block = Self.text("Hello", priority: 0.5)

    #expect(block.isVisible(to: .user))
    #expect(block.isVisible(to: .assistant))
  }

  @Test func aBlockForTheAssistantOnlyIsNotVisibleToTheUser() {
    let block = Self.text("Hidden", audience: [.assistant])

    #expect(!block.isVisible(to: .user))
    #expect(block.isVisible(to: .assistant))
  }

  @Test func aBlockForTheUserIsVisibleToTheUser() {
    let block = Self.text("Shown", audience: [.user, .assistant])

    #expect(block.isVisible(to: .user))
  }

  @Test func aBlockWithAnEmptyAudienceIsVisibleToNoAudience() {
    let block = Self.text("Nobody", audience: [])

    #expect(!block.isVisible(to: .user))
    #expect(!block.isVisible(to: .assistant))
  }

  @Test func aBlockForAnUnknownAudienceIsNotVisibleToTheUser() {
    let block = Self.text("Other", audience: [.unknown("tool")])

    #expect(!block.isVisible(to: .user))
    #expect(block.isVisible(to: .unknown("tool")))
  }

  @Test func theVisibleFilterKeepsTheOrderOfTheVisibleBlocks() {
    let blocks = [
      Self.text("a"),
      Self.text("b", audience: [.assistant]),
      Self.text("c", audience: [.user]),
    ]

    #expect(blocks.visible(to: .user).map(\.content) == [.text("a"), .text("c")])
  }

  @Test(arguments: [("user", Audience.user), ("assistant", Audience.assistant)])
  func aKnownAudienceGivesItsCase(wireValue: String, audience: Audience) {
    #expect(Audience(wireValue: wireValue) == audience)
    #expect(audience.wireValue == wireValue)
  }

  @Test func anUnknownAudienceGivesUnknown() {
    #expect(Audience(wireValue: "tool") == .unknown("tool"))
  }

  // MARK: - Priority

  @Test func thePrioritySortPutsTheHighestPriorityFirst() {
    let blocks = [
      Self.text("low", priority: 0.1),
      Self.text("high", priority: 0.9),
      Self.text("middle", priority: 0.5),
    ]

    #expect(
      blocks.sortedByPriority().map(\.content) == [.text("high"), .text("middle"), .text("low")]
    )
  }

  @Test func thePrioritySortPutsBlocksWithNoPriorityLast() {
    let blocks = [
      ContentBlock.text("none"),
      Self.text("zero", priority: 0),
      Self.text("unset", audience: [.user]),
    ]

    #expect(
      blocks.sortedByPriority().map(\.content) == [.text("zero"), .text("none"), .text("unset")]
    )
  }

  @Test func thePrioritySortKeepsTheOrderOfEqualPriorities() {
    let blocks = [
      Self.text("first", priority: 0.5),
      Self.text("second", priority: 0.5),
      Self.text("third", priority: 0.5),
    ]

    #expect(
      blocks.sortedByPriority().map(\.content) == [.text("first"), .text("second"), .text("third")]
    )
  }

  // MARK: - Kind

  @Test func eachContentCaseGivesItsKind() {
    let cases: [(ContentBlock.Content, ContentBlock.Kind)] = [
      (.text("a"), .text),
      (.image(ImageContent(data: Data([1]), mimeType: "image/png")), .image),
      (.audio(AudioContent(data: Data([2]), mimeType: "audio/wav")), .audio),
      (
        .resourceLink(
          ResourceLink(
            name: "a.swift",
            uri: "file:///a.swift",
            icons: [ResourceIcon(src: "https://example.com/a.png")],
            mimeType: "text/x-swift"
          )
        ),
        .resourceLink
      ),
      (.resource(EmbeddedResource(uri: "file:///a.txt", contents: .text("a"))), .resource),
      (.resource(EmbeddedResource(uri: "file:///a.bin", contents: .blob(Data([3])))), .resource),
      (.attachment(URL(filePath: "/tmp/a.pdf")), .attachment),
      (.structured(schemaName: "Chart", payload: .null), .structured),
      (.unknown(kind: "video", raw: .null), .unknown),
    ]

    for (content, kind) in cases {
      #expect(ContentBlock(content: content).kind == kind)
    }
  }

  @Test func aResourceLinkKeepsItsFields() {
    let link = ResourceLink(
      name: "a.swift",
      uri: "file:///a.swift",
      icons: [ResourceIcon(src: "https://example.com/a.png", mimeType: "image/png", sizes: ["16x16"])],
      mimeType: "text/x-swift"
    )

    #expect(link.name == "a.swift")
    #expect(link.uri == "file:///a.swift")
    #expect(link.icons.first?.sizes == ["16x16"])
    #expect(link.mimeType == "text/x-swift")
  }
}
