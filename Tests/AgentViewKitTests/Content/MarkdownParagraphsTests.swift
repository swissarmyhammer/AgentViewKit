import Testing

@testable import AgentViewKit

/// The paragraphs of a Markdown text, which the paragraph index of a
/// ``CitationMarker`` counts.
@Suite struct MarkdownParagraphsTests {
  /// The text of each paragraph of `markdown`.
  ///
  /// - Parameter markdown: The Markdown text.
  /// - Returns: The text of each paragraph, in text order.
  static func texts(of markdown: String) -> [String] {
    MarkdownParagraphs.paragraphs(in: markdown).map { String(markdown[$0.range]) }
  }

  @Test func aBlankLineEndsAParagraph() {
    #expect(Self.texts(of: "One.\n\nTwo.") == ["One.", "Two."])
  }

  @Test func aParagraphKeepsItsSingleLineBreaks() {
    #expect(Self.texts(of: "line one\nline two\n\ntail") == ["line one\nline two", "tail"])
  }

  @Test func aLineWithOnlySpacesIsBlank() {
    #expect(Self.texts(of: "one\n  \n\n\ntwo") == ["one", "two"])
  }

  @Test func blankLinesAtTheEndMakeNoParagraph() {
    #expect(Self.texts(of: "one\n\n\n") == ["one"])
  }

  @Test func anEmptyTextHasNoParagraph() {
    #expect(MarkdownParagraphs.paragraphs(in: "").isEmpty)
  }

  @Test func aFencedBlockWithBlankLinesIsOneParagraph() {
    let fence = "```swift\nlet a = 1\n\n\nlet b = 2\n```"

    #expect(Self.texts(of: "intro\n\n\(fence)\n\nafter") == ["intro", fence, "after"])
  }

  @Test func aFenceLineStartsAndEndsAParagraphWithNoBlankLine() {
    #expect(Self.texts(of: "intro\n```\ncode\n```\nafter") == ["intro", "```\ncode\n```", "after"])
  }

  @Test func onlyTheFencedParagraphIsAFence() {
    let paragraphs = MarkdownParagraphs.paragraphs(in: "intro\n\n```\ncode\n```")

    #expect(paragraphs.map(\.isFence) == [false, true])
  }

  @Test func aTildeFenceIsProseForTheParagraphIndex() {
    #expect(Self.texts(of: "intro\n~~~\ncode\n\nmore\n~~~") == ["intro\n~~~\ncode", "more\n~~~"])
  }

  @Test func anOpenFenceRunsToTheEndOfTheText() {
    #expect(Self.texts(of: "intro\n\n```\ncode\n\nmore") == ["intro", "```\ncode\n\nmore"])
  }

  @Test func carriageReturnLineBreaksSplitAsLineFeeds() {
    #expect(Self.texts(of: "One.\r\n\r\nTwo.\rStill two.") == ["One.", "Two.\rStill two."])
  }
}
