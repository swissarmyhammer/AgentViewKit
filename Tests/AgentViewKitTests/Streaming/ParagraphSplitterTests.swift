import AgentViewKit
import Testing

@Suite struct ParagraphSplitterTests {
  @Test func threeSettledParagraphsAndAnOpenFourth() {
    let split = ParagraphSplitter.split("one\n\ntwo\n\nthree\n\nfou")

    #expect(split.settled.map(\.text) == ["one", "two", "three"])
    #expect(split.tail == "fou")
  }

  @Test func settledParagraphsGetTheirIndex() {
    let split = ParagraphSplitter.split("one\n\ntwo\n\nthree")

    #expect(split.settled.map(\.id.index) == [0, 1])
  }

  @Test func aParagraphKeepsItsSingleLineBreaks() {
    let split = ParagraphSplitter.split("line one\nline two\n\ntail")

    #expect(split.settled.map(\.text) == ["line one\nline two"])
    #expect(split.tail == "tail")
  }

  @Test func aSingleTrailingLineBreakKeepsTheParagraphOpen() {
    let split = ParagraphSplitter.split("one\n")

    #expect(split.settled.isEmpty)
    #expect(split.tail == "one\n")
  }

  @Test func aTrailingBlankLineSettlesTheLastParagraph() {
    let split = ParagraphSplitter.split("one\n\n")

    #expect(split.settled.map(\.text) == ["one"])
    #expect(split.tail == "")
  }

  @Test func manyBlankLinesMakeOneSeparator() {
    let split = ParagraphSplitter.split("one\n\n\n  \n\ntwo")

    #expect(split.settled.map(\.text) == ["one"])
    #expect(split.tail == "two")
  }

  @Test func anEmptyMessageHasNoParagraphs() {
    let split = ParagraphSplitter.split("")

    #expect(split.settled.isEmpty)
    #expect(split.tail == "")
  }

  @Test func aFencedBlockWithBlankLinesStaysOneParagraph() {
    let fence = "```swift\nlet a = 1\n\n\nlet b = 2\n```"

    let split = ParagraphSplitter.split("intro\n\n\(fence)\n\nafter")

    #expect(split.settled.map(\.text) == ["intro", fence])
    #expect(split.tail == "after")
  }

  @Test func anOpenFenceWithBlankLinesIsTheTail() {
    let split = ParagraphSplitter.split("intro\n\n```swift\nlet a = 1\n\nlet b")

    #expect(split.settled.map(\.text) == ["intro"])
    #expect(split.tail == "```swift\nlet a = 1\n\nlet b")
  }

  @Test func aFenceStartsAndEndsAParagraphWithNoBlankLine() {
    let split = ParagraphSplitter.split("intro\n```\ncode\n```\nafter")

    #expect(split.settled.map(\.text) == ["intro", "```\ncode\n```"])
    #expect(split.tail == "after")
  }

  @Test func aShorterBacktickRunDoesNotCloseAFence() {
    let split = ParagraphSplitter.split("````\n```\n\ncode\n````\n\nafter")

    #expect(split.settled.map(\.text) == ["````\n```\n\ncode\n````"])
    #expect(split.tail == "after")
  }

  @Test func settledIdsAreStableWhenTheTailGrows() {
    let before = ParagraphSplitter.split("one\n\ntwo\n\nthr")
    let after = ParagraphSplitter.split("one\n\ntwo\n\nthree and more")
    let later = ParagraphSplitter.split("one\n\ntwo\n\nthree and more\n\nfour")

    #expect(before.settled.map(\.id) == after.settled.map(\.id))
    #expect(Array(later.settled.prefix(2)).map(\.id) == before.settled.map(\.id))
    #expect(later.settled.map(\.text) == ["one", "two", "three and more"])
  }

  @Test func theIdChangesWhenTheTextChanges() {
    let first = ParagraphSplitter.split("one\n\ntail")
    let second = ParagraphSplitter.split("uno\n\ntail")

    #expect(first.settled[0].id != second.settled[0].id)
    #expect(first.settled[0].id.index == second.settled[0].id.index)
  }

  @Test func theTextHashIsTheSameForEachRun() {
    // FNV-1a of "one" is a fixed value. Swift's Hasher has a random seed for
    // each process, so the splitter must not use it.
    let split = ParagraphSplitter.split("one\n\ntail")

    #expect(split.settled[0].id.textHash == 0x1A08_AA19_21CA_5CAF)
  }

  @Test func crlfInputSplitsAsLineFeedInput() {
    let split = ParagraphSplitter.split("one\r\ntwo\r\n\r\nthree\r\n\r\nfou")
    let lineFeed = ParagraphSplitter.split("one\ntwo\n\nthree\n\nfou")

    #expect(split.settled.map(\.text) == ["one\ntwo", "three"])
    #expect(split.tail == "fou")
    #expect(split.settled.map(\.id) == lineFeed.settled.map(\.id))
  }

  @Test func crlfInsideAFenceKeepsTheFenceWhole() {
    let split = ParagraphSplitter.split("```\r\na\r\n\r\nb\r\n```\r\n\r\nx")

    #expect(split.settled.map(\.text) == ["```\na\n\nb\n```"])
    #expect(split.tail == "x")
  }

  // MARK: - Complete text

  @Test func paragraphsSettlesTheTailAsTheLastParagraph() {
    let paragraphs = ParagraphSplitter.paragraphs("one\n\ntwo\n")

    #expect(paragraphs.map(\.text) == ["one", "two"])
    #expect(paragraphs.map(\.id.index) == [0, 1])
  }

  @Test func paragraphsDropsATailWithOnlyLineBreaks() {
    #expect(ParagraphSplitter.paragraphs("one\n\n").map(\.text) == ["one"])
    #expect(ParagraphSplitter.paragraphs("").isEmpty)
  }

  @Test func paragraphsSettlesAnOpenFence() {
    #expect(ParagraphSplitter.paragraphs("```swift\nlet x").map(\.text) == ["```swift\nlet x"])
  }
}
