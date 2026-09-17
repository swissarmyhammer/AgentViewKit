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

  // MARK: - Resumed split

  /// A message with prose, a list, fences with blank lines, CRLF line
  /// breaks, and a fence that starts with no blank line before it.
  static let resumedSample = [
    "# Title\n\nSome **bold** text\nand a second line.\n\n",
    "- one\n- two\n\n```swift\nlet a = 1\n\n\nlet b = 2\n```\nafter the fence\n\n",
    "Windows\r\nline breaks\r\n\r\nand a lone\rbreak.\n\n   \n",
    "text before a fence\n~~~\nbody\n~~~\n\nlast paragraph",
  ].joined()

  /// The chunk lengths, in characters, of the resumed splits.
  nonisolated static let resumedChunkLengths = [1, 3, 7, 16]

  /// Splits `text` in chunks with a resumption, and checks each split
  /// against a full split of the same text.
  ///
  /// - Parameters:
  ///   - text: The message.
  ///   - chunkLength: The number of characters in each chunk.
  static func expectResumedSplitsMatchFullSplits(of text: String, chunkLength: Int) {
    let characters = Array(text)
    let ends = Array(stride(from: chunkLength, to: characters.count, by: chunkLength)) + [characters.count]
    var resumption = ParagraphSplitter.Resumption.start
    var settled: [ParagraphSplitter.Paragraph] = []
    for end in ends {
      let prefix = String(characters[..<end])
      let resumed = ParagraphSplitter.split(prefix, resumingAt: resumption)
      let full = ParagraphSplitter.split(prefix)
      settled += resumed.settled
      resumption = resumed.resumption
      #expect(settled == full.settled, "The settled paragraphs differ at \(end) of \(chunkLength).")
      #expect(resumed.tail == full.tail, "The tail differs at \(end) of \(chunkLength).")
      #expect(resumption.settledCount == settled.count)
    }
  }

  @Test(arguments: resumedChunkLengths)
  func aResumedSplitGivesTheParagraphsOfAFullSplit(chunkLength: Int) {
    Self.expectResumedSplitsMatchFullSplits(of: Self.resumedSample, chunkLength: chunkLength)
  }

  @Test func aSplitFromTheStartIsAFullSplit() {
    let resumed = ParagraphSplitter.split(Self.resumedSample, resumingAt: .start)
    let full = ParagraphSplitter.split(Self.resumedSample)

    #expect(resumed.settled == full.settled)
    #expect(resumed.tail == full.tail)
  }

  @Test func theResumptionStartsAtTheOpenParagraph() {
    let split = ParagraphSplitter.split("one\n\ntwo", resumingAt: .start)

    #expect(split.resumption == ParagraphSplitter.Resumption(utf8Offset: "one\n\n".utf8.count, settledCount: 1))
  }

  @Test func theResumptionStartsAtTheLastLineWhenNoParagraphIsOpen() {
    let split = ParagraphSplitter.split("one\n\n", resumingAt: .start)

    #expect(split.resumption == ParagraphSplitter.Resumption(utf8Offset: "one\n\n".utf8.count, settledCount: 1))
    #expect(split.tail == "")
  }

  @Test func aResumedSplitDoesNotReadTheSettledText() {
    let resumption = ParagraphSplitter.Resumption(utf8Offset: "ignored\n\n".utf8.count, settledCount: 1)

    let split = ParagraphSplitter.split("IGNORED\n\nnext\n\nopen", resumingAt: resumption)

    #expect(split.settled == [ParagraphSplitter.Paragraph(index: 1, text: "next")])
    #expect(split.tail == "open")
  }

  @Test func aCarriageReturnAtTheEndOfAChunkJoinsTheNextLineFeed() {
    let first = ParagraphSplitter.split("one\r", resumingAt: .start)
    let second = ParagraphSplitter.split("one\r\ntwo\r\n\r\nthree", resumingAt: first.resumption)

    #expect((first.settled + second.settled).map(\.text) == ["one\ntwo"])
    #expect(second.tail == "three")
  }
}
