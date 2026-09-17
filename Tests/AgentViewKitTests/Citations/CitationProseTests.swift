import Foundation
import SwiftUI
import Testing
import Textual

@testable import AgentViewKit

/// The pure parts of the inline citations: the placements of a payload, the
/// markers in a paragraph, and the parser that makes each marker a pill.
@MainActor struct CitationProseTests {
  /// A payload with two sources and four markers. One marker cites a source
  /// that is not in the list.
  static let payload = CitationPayload(
    sources: [
      CitationSource(id: "a", title: "Alpha", url: URL(filePath: "/alpha"), snippet: ""),
      CitationSource(id: "b", title: "Beta", url: URL(filePath: "/beta"), snippet: ""),
    ],
    markers: [
      CitationMarker(sourceID: "b", paragraphIndex: 1, offset: 4),
      CitationMarker(sourceID: "a", paragraphIndex: 0, offset: 3),
      CitationMarker(sourceID: "missing", paragraphIndex: 0, offset: 1),
      CitationMarker(sourceID: "a", paragraphIndex: 1, offset: 2),
    ])

  // MARK: - Payload

  @Test func thePlacementsAreGroupedByParagraphWithOneBasedNumbers() {
    let placements = Self.payload.placementsByParagraph()

    #expect(placements[0] == [CitationPlacement(offset: 3, number: 1)])
    #expect(
      placements[1] == [
        CitationPlacement(offset: 4, number: 2),
        CitationPlacement(offset: 2, number: 1),
      ])
    #expect(placements.count == 2)
  }

  @Test func aMarkerOfAnUnknownSourceHasNoPlacement() {
    let payload = CitationPayload(
      sources: [], markers: [CitationMarker(sourceID: "x", paragraphIndex: 0, offset: 0)])

    #expect(payload.placementsByParagraph().isEmpty)
  }

  @Test func theFirstCitationBlockGivesThePayload() throws {
    let other = ContentBlock(content: .structured(schemaName: "Other", payload: .null))
    let citation = ContentBlock(
      content: .structured(schemaName: CitationPayload.schemaName, payload: try Self.payload.jsonValue()))

    #expect(CitationPayload.first(in: [ContentBlock(text: "t"), other, citation]) == Self.payload)
    #expect(CitationPayload.first(in: [ContentBlock(text: "t"), other]) == nil)
    #expect(citation.isCitation)
    #expect(!other.isCitation)
  }

  @Test func aCitationBlockThatDoesNotDecodeGivesNoPayload() {
    let broken = ContentBlock(
      content: .structured(schemaName: CitationPayload.schemaName, payload: .string("no")))

    #expect(CitationPayload.first(in: [broken]) == nil)
    #expect(broken.isCitation)
  }

  // MARK: - Markers

  @Test func theMarkersGoInAtTheOffsetsAndKeepTheirOrderAtOneOffset() {
    let marked = CitationMarkers.marked(
      "Hello world",
      placements: [
        CitationPlacement(offset: 5, number: 2),
        CitationPlacement(offset: 11, number: 1),
        CitationPlacement(offset: 5, number: 1),
      ])

    #expect(
      marked.text
        == "Hello" + CitationMarkers.marker(number: 2) + CitationMarkers.marker(number: 1)
        + " world" + CitationMarkers.marker(number: 1))
    #expect(marked.numbers == [2, 1, 1])
  }

  @Test func anOffsetOutsideTheTextIsClamped() {
    let marked = CitationMarkers.marked(
      "Hi",
      placements: [
        CitationPlacement(offset: -3, number: 1),
        CitationPlacement(offset: 99, number: 2),
      ])

    #expect(marked.text == CitationMarkers.marker(number: 1) + "Hi" + CitationMarkers.marker(number: 2))
    #expect(marked.numbers == [1, 2])
  }

  @Test func aParagraphWithACodeFenceGetsNoMarker() {
    let text = "```swift\nlet x = 1\n```"
    let marked = CitationMarkers.marked(text, placements: [CitationPlacement(offset: 3, number: 1)])

    #expect(marked.text == text)
    #expect(marked.numbers.isEmpty)
  }

  @Test func thePartsSplitTheTextAtEachMarker() {
    let text = "a" + CitationMarkers.marker(number: 3) + "b" + CitationMarkers.marker(number: 12)

    #expect(
      CitationMarkers.parts(of: text) == [.text("a"), .marker(3), .text("b"), .marker(12)])
    #expect(CitationMarkers.parts(of: "plain") == [.text("plain")])
  }

  @Test func aStartWithNoValidMarkerStaysInTheText() {
    let broken = "a" + String(CitationMarkers.start) + "x"
    let text = broken + CitationMarkers.marker(number: 4) + "b"

    #expect(CitationMarkers.parts(of: text) == [.text(broken), .marker(4), .text("b")])
    #expect(CitationMarkers.parts(of: "") == [])
  }

  // MARK: - Parser

  @Test func theParserMakesEachMarkerAPillWithTheCitationLink() throws {
    let input = "Claim" + CitationMarkers.marker(number: 2) + " **bold**"
    let output = try CitationMarkdownParser(base: MathMarkdownParser()).attributedString(for: input)

    #expect(String(output.characters) == "Claim" + MathMarkdownParser.attachmentCharacter + " bold")
    let pills = output.runs.filter { $0.textual.attachment != nil }
    #expect(pills.count == 1)
    #expect(pills.first?.link == InlineCitation.url(index: 2))
    #expect(pills.first?.textual.attachment?.description == "[2]")
  }

  @Test func theParserDropsAMarkerInACodeBlock() throws {
    let input = "    code" + CitationMarkers.marker(number: 1)
    let output = try CitationMarkdownParser(base: MathMarkdownParser()).attributedString(for: input)

    #expect(!String(output.characters).contains(MathMarkdownParser.attachmentCharacter))
    #expect(!String(output.characters).contains(CitationMarkers.start))
  }

  @Test func theParserKeepsATextWithNoMarker() throws {
    let base = MathMarkdownParser()
    let parser = CitationMarkdownParser(base: base)

    #expect(try parser.attributedString(for: "Some *text*") == base.attributedString(for: "Some *text*"))
  }

  // MARK: - URL

  @Test func theCitationURLGivesItsIndexBack() throws {
    let url = try #require(InlineCitation.url(index: 7))

    #expect(InlineCitation.index(of: url) == 7)
    #expect(InlineCitation.index(of: try #require(URL(string: "https://example.com/7"))) == nil)
    #expect(InlineCitation.index(of: try #require(URL(string: "agentviewkit-citation:x"))) == nil)
  }

  @Test func theIdentifiersHaveTheirPrefixes() {
    #expect(InlineCitation.identifier(index: 2) == "inline-citation-2")
    #expect(SourcesView.rowIdentifier(index: 2) == "sources-row-2")
    #expect(SourcesView.numberIdentifier(index: 2) == "sources-number-2")
    #expect(SourcesView.identifier == "sources")
  }
}
