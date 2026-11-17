import EditorStyle
import EditorSwiftUI
import EditorTestSupport
import EditorTheme
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The pure parts of the inline citations: the citation chips that a
/// payload gives the text of a response, and the metrics of a pill.
@MainActor struct CitationProseTests {
  /// The first source.
  static let alpha = CitationSource(id: "a", title: "Alpha", url: URL(filePath: "/alpha"), snippet: "")

  /// The second source.
  static let beta = CitationSource(id: "b", title: "Beta", url: URL(filePath: "/beta"), snippet: "")

  /// The chips of one marker in `markdown`.
  ///
  /// - Parameters:
  ///   - marker: The marker. It cites ``alpha`` or ``beta``.
  ///   - markdown: The text of the response.
  /// - Returns: The chips.
  static func chips(of marker: CitationMarker, in markdown: String) -> [EditorCitation] {
    CitationPayload(sources: [alpha, beta], markers: [marker]).editorCitations(in: markdown)
  }

  // MARK: - Chips

  @Test func aMarkerInTheFirstParagraphIsAtItsOffset() {
    let chips = Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 0, offset: 5), in: "Hello world")

    #expect(chips == [EditorCitation(offset: 5, number: 1, id: "a", title: "Alpha")])
  }

  @Test func aMarkerInALaterParagraphCountsFromTheStartOfItsParagraph() {
    let markdown = "One.\n\nTwo words."
    let chips = Self.chips(of: CitationMarker(sourceID: "b", paragraphIndex: 1, offset: 3), in: markdown)

    #expect(chips.map(\.offset) == ["One.\n\nTwo".utf8.count])
  }

  @Test func theOffsetOfAChipCountsTheUTF8BytesOfMultibyteText() {
    let markdown = "Café ü.\n\nÄ 日本 is here."
    let chips = Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 1, offset: 4), in: markdown)

    #expect(chips.map(\.offset) == ["Café ü.\n\nÄ 日本".utf8.count])
  }

  @Test func theNumberOfAChipIsThePositionOfItsSourcePlusOne() {
    let chips = Self.chips(of: CitationMarker(sourceID: "b", paragraphIndex: 0, offset: 0), in: "Text")

    #expect(chips.map(\.number) == [2])
    #expect(chips.map(\.title) == ["Beta"])
  }

  @Test func eachMarkerOfAPayloadMakesOneChipInMarkerOrder() {
    let payload = CitationPayload(
      sources: [Self.alpha, Self.beta],
      markers: [
        CitationMarker(sourceID: "b", paragraphIndex: 1, offset: 1),
        CitationMarker(sourceID: "a", paragraphIndex: 0, offset: 2),
      ])

    #expect(payload.editorCitations(in: "ab\n\ncd").map(\.id) == ["b", "a"])
  }

  @Test func aMarkerOfAnUnknownSourceMakesNoChip() {
    #expect(Self.chips(of: CitationMarker(sourceID: "x", paragraphIndex: 0, offset: 0), in: "Text").isEmpty)
  }

  @Test func aMarkerOfAParagraphPastTheEndMakesNoChip() {
    #expect(Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 2, offset: 0), in: "One.\n\nTwo.").isEmpty)
  }

  @Test func anOffsetPastTheEndOfItsParagraphIsTheEndOfTheParagraph() {
    let chips = Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 0, offset: 99), in: "One.\n\nTwo.")

    #expect(chips.map(\.offset) == ["One.".utf8.count])
  }

  @Test func anOffsetBelowZeroIsTheStartOfItsParagraph() {
    let chips = Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 1, offset: -3), in: "One.\n\nTwo.")

    #expect(chips.map(\.offset) == ["One.\n\n".utf8.count])
  }

  @Test func aMarkerInAFencedCodeBlockMakesNoChip() {
    let markdown = "Code:\n\n```swift\nlet x = 1\n```"

    #expect(Self.chips(of: CitationMarker(sourceID: "a", paragraphIndex: 1, offset: 3), in: markdown).isEmpty)
  }

  // MARK: - Metrics

  @Test func thePillTakesItsWidthFromTheDigitsOfTheUIFace() {
    let index = 1000
    let textFontSize: CGFloat = 13
    let padding = InlineCitationPadding(style: .default)
    let system = InlineCitationMetrics(index: index, textFontSize: textFontSize, face: .system, padding: padding)
    let family = InlineCitationMetrics(
      index: index, textFontSize: textFontSize, face: FontFace(family: UIFamilyTheme.family), padding: padding)

    #expect(family.size.width != system.size.width)
  }

  /// The metrics of a one-digit pill at the body size, with `style`.
  ///
  /// - Parameter style: The style that gives the padding of the pill.
  /// - Returns: The metrics.
  static func metrics(style: EditorStyle) -> InlineCitationMetrics {
    InlineCitationMetrics(index: 1, textFontSize: 13, face: .system, padding: InlineCitationPadding(style: style))
  }

  @Test func theHeightOfThePillFollowsTheChipPaddingRatioOfTheStyle() {
    var taller = EditorStyle.default
    taller.chip.paddingRatio *= 4

    #expect(Self.metrics(style: taller).size.height > Self.metrics(style: .default).size.height)
  }

  @Test func theWidthOfAPillWithManyDigitsFollowsTheSpacingOfTheStyle() {
    var wider = EditorStyle.default
    wider.spacing.xs *= 4
    let index = 1000
    let width = { (style: EditorStyle) in
      InlineCitationMetrics(index: index, textFontSize: 13, face: .system, padding: InlineCitationPadding(style: style))
        .size.width
    }

    #expect(width(wider) > width(.default))
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
