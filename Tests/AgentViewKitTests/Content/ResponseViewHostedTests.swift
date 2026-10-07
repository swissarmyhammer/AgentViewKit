import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ResponseView`` and ``ParagraphView``.
@Suite(.serialized, .hostedSerially) @MainActor struct ResponseViewHostedTests {
  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 640)

  /// A text with four paragraphs.
  static let fourParagraphText = "One.\n\nTwo.\n\nThree.\n\nFour"

  /// The identifiers of the paragraph elements that `harness` shows.
  ///
  /// - Parameters:
  ///   - harness: The harness that hosts the view.
  ///   - limit: The largest paragraph index to look for, plus one.
  /// - Returns: The identifiers that the harness finds.
  static func paragraphIdentifiers(
    in harness: HostedViewHarness<some View>, limit: Int
  ) -> [String] {
    (0..<limit)
      .map(ResponseView.paragraphIdentifier(index:))
      .filter { harness.element(identifier: $0) != nil }
  }

  // MARK: - Elements

  @Test func aTextWithFourParagraphsMountsFourParagraphElements() {
    let harness = HostedViewHarness(
      ResponseView(id: "response-four", markdown: Self.fourParagraphText), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let paragraphs = Self.paragraphIdentifiers(in: harness, limit: 5)
    #expect(paragraphs == (0..<4).map(ResponseView.paragraphIdentifier(index:)))
  }

  @Test func aTextThatEndsWithABlankLineMountsOneParagraphElement() {
    let harness = HostedViewHarness(
      ResponseView(id: "response-blank-end", markdown: "One.\n\n"), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(Self.paragraphIdentifiers(in: harness, limit: 2) == [
      ResponseView.paragraphIdentifier(index: 0)
    ])
  }

  // MARK: - Code fences

  @Test func aFencedBlockMountsACodeBlock() {
    let harness = HostedViewHarness(
      ResponseView(id: "response-fence", markdown: "Some code:\n\n```swift\nlet x = 1\n```"),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "swift code block")
    #expect(Self.paragraphIdentifiers(in: harness, limit: 3).count == 2)
  }

  // MARK: - Paragraph view

  @Test func twoParagraphViewsWithTheSameParagraphAreEqual() {
    let paragraph = ParagraphSplitter.Paragraph(index: 0, text: "One.")
    let other = ParagraphSplitter.Paragraph(index: 0, text: "Two.")
    #expect(
      ParagraphView(messageID: "m", paragraph: paragraph)
        == ParagraphView(messageID: "m", paragraph: paragraph))
    #expect(
      ParagraphView(messageID: "m", paragraph: paragraph)
        != ParagraphView(messageID: "m", paragraph: other))
    #expect(
      ParagraphView(messageID: "m", paragraph: paragraph)
        != ParagraphView(messageID: "n", paragraph: paragraph))
  }

  @Test func twoParagraphViewsInDifferentReadingGroupsAreNotEqual() {
    let paragraph = ParagraphSplitter.Paragraph(index: 0, text: "One.")
    #expect(
      ParagraphView(messageID: "m", paragraph: paragraph, readingGroupID: "a")
        != ParagraphView(messageID: "m", paragraph: paragraph, readingGroupID: "b"))
  }
}
