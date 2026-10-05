import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// A button that opens a URL through the `openURL` action of the environment.
private struct OpenURLButton: View {
  /// The accessibility identifier of the button.
  static let identifier = "open-url-button"

  /// The URL to open.
  let url: URL

  @Environment(\.openURL) private var openURL

  var body: some View {
    Button("Open") { openURL(url) }
      .accessibilityIdentifier(Self.identifier)
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct SourcesViewHostedTests {
  /// The size of the host view.
  static let hostSize = CGSize(width: 600, height: 600)

  /// The longest time that a test waits for a view change, in seconds.
  static let waitSeconds: TimeInterval = 2

  /// The text of the cited message: two paragraphs.
  static let text = "First claim.\n\nSecond claim."

  /// The height of the tall spacer in the scroll test, in points.
  static let spacerHeight: CGFloat = 3_000

  /// The first source.
  static let alpha = CitationSource(
    id: "alpha", title: "Alpha Guide", url: URL(filePath: "/docs/alpha.html"), snippet: "About alpha.")

  /// The second source.
  static let beta = CitationSource(
    id: "beta", title: "Beta Notes", url: URL(filePath: "/docs/beta.html"), snippet: "")

  /// A payload with two sources. Each paragraph cites one source at its end.
  static let payload = CitationPayload(
    sources: [alpha, beta],
    markers: [
      CitationMarker(sourceID: "alpha", paragraphIndex: 0, offset: 12),
      CitationMarker(sourceID: "beta", paragraphIndex: 1, offset: 13),
    ])

  // MARK: - Helpers

  /// Makes a message with one text block of the text.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The message.
  static func message(id: String) -> Message {
    Message(id: id, blocks: [ContentBlock(text: text)])
  }

  /// Makes a response with the citations of the payload, and the footer of
  /// the payload below it, in one citation scope.
  ///
  /// - Parameters:
  ///   - message: The message of the response.
  ///   - streaming: The stream of the message, or `nil`.
  /// - Returns: The view.
  static func citedResponse(message: Message, streaming: StreamingMessage? = nil) -> some View {
    VStack {
      ResponseView(message: message, streaming: streaming, citations: payload)
      SourcesView(payload: payload)
    }
    .citationScope()
  }

  /// Tells whether a row shows the highlight.
  ///
  /// - Parameters:
  ///   - harness: The harness.
  ///   - index: The one-based number of the row.
  /// - Returns: `true` when the number of the row has the highlighted value.
  static func isHighlighted<Content: View>(_ harness: HostedViewHarness<Content>, index: Int) -> Bool {
    harness.element(identifier: SourcesView.numberIdentifier(index: index))?.value
      == SourcesView.highlightedValue
  }

  // MARK: - Footer

  @Test func aFooterWithTwoSourcesHasTwoRows() {
    let harness = HostedViewHarness(SourcesView(payload: Self.payload), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SourcesView.identifier) != nil)
    #expect(harness.element(identifier: SourcesView.rowIdentifier(index: 1)) != nil)
    #expect(harness.element(identifier: SourcesView.rowIdentifier(index: 2)) != nil)
    #expect(harness.element(identifier: SourcesView.rowIdentifier(index: 3)) == nil)
    #expect(harness.element(identifier: SourcesView.numberIdentifier(index: 2))?.label == "Source 2")
    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains("Alpha Guide"))
    #expect(labels.contains("Beta Notes"))
    #expect(labels.contains { $0.contains("About alpha.") })
  }

  @Test func aPressOnARowOpensItsSource() throws {
    let recorder = OpenedURLRecorder()
    let harness = HostedViewHarness(
      SourcesView(payload: Self.payload)
        .environment(\.openURL, OpenURLAction(handler: recorder.open)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: LinkView.cardIdentifier)

    #expect(recorder.urls == [Self.alpha.url])
  }

  @Test func aCollapsedFooterShowsNoRow() {
    let harness = HostedViewHarness(
      SourcesView(payload: Self.payload, isExpanded: false), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SourcesView.identifier) != nil)
    #expect(harness.element(identifier: SourcesView.rowIdentifier(index: 1)) == nil)
  }

  // MARK: - Pills

  @Test func eachCitedParagraphShowsItsPill() async {
    let harness = HostedViewHarness(
      Self.citedResponse(message: Self.message(id: "cited-pills")), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: InlineCitation.identifier(index: 2)) != nil
    }

    #expect(harness.element(identifier: InlineCitation.identifier(index: 1))?.label == "Source 1")
    #expect(harness.element(identifier: InlineCitation.identifier(index: 2))?.label == "Source 2")
  }

  @Test func aResponseWithNoCitationsShowsNoPill() async {
    let harness = HostedViewHarness(
      ResponseView(message: Self.message(id: "uncited"), streaming: nil), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: ResponseView.paragraphIdentifier(index: 1)) != nil
    }

    #expect(harness.element(identifier: ResponseView.paragraphIdentifier(index: 1)) != nil)
    #expect(harness.element(identifier: InlineCitation.identifier(index: 1)) == nil)
  }

  @Test func aTapOnPillTwoHighlightsRowTwo() async throws {
    let harness = HostedViewHarness(
      Self.citedResponse(message: Self.message(id: "cited-tap")), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: InlineCitation.identifier(index: 2)) != nil
    }
    #expect(!Self.isHighlighted(harness, index: 2))

    try harness.press(identifier: InlineCitation.identifier(index: 2))
    await harness.pump(until: Self.waitSeconds) { Self.isHighlighted(harness, index: 2) }

    #expect(Self.isHighlighted(harness, index: 2))
    #expect(!Self.isHighlighted(harness, index: 1))
  }

  @Test func aStreamingMessageShowsThePillsOfItsSettledParagraphs() async throws {
    let message = Self.message(id: "cited-stream")
    let thread = AgentThread()
    thread.apply(.insert(.assistantMessage(message), after: nil))
    thread.apply(.appendStreaming(id: message.id, text: Self.text + "\n\nMore"))
    let streaming = try #require(thread.streaming[message.id])
    let harness = HostedViewHarness(
      Self.citedResponse(message: message, streaming: streaming), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: InlineCitation.identifier(index: 2)) != nil
    }

    #expect(harness.element(identifier: InlineCitation.identifier(index: 1)) != nil)
    #expect(harness.element(identifier: InlineCitation.identifier(index: 2)) != nil)
  }

  @Test func aStandaloneInlineCitationHighlightsItsRow() async throws {
    let harness = HostedViewHarness(
      VStack {
        InlineCitation(index: 1)
        SourcesView(payload: Self.payload)
      }
      .citationScope(),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: InlineCitation.identifier(index: 1))
    await harness.pump(until: Self.waitSeconds) { Self.isHighlighted(harness, index: 1) }

    #expect(Self.isHighlighted(harness, index: 1))
    #expect(!Self.isHighlighted(harness, index: 2))
  }

  @Test func aPillOpensACollapsedFooter() async throws {
    let harness = HostedViewHarness(
      VStack {
        InlineCitation(index: 2)
        SourcesView(payload: Self.payload, isExpanded: false)
      }
      .citationScope(),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: InlineCitation.identifier(index: 2))
    await harness.pump(until: Self.waitSeconds) { Self.isHighlighted(harness, index: 2) }

    #expect(Self.isHighlighted(harness, index: 2))
  }

  @Test func aPillScrollsItsRowIntoView() async throws {
    let harness = HostedViewHarness(
      ScrollView {
        VStack {
          InlineCitation(index: 2)
          Color.clear.frame(height: Self.spacerHeight)
          SourcesView(payload: Self.payload)
        }
      }
      .citationScope())
    defer { harness.close() }
    harness.pump()
    let scrollView = try #require(Self.firstScrollView(in: harness.hostingView))
    #expect(scrollView.contentView.bounds.minY == 0)

    try harness.press(identifier: InlineCitation.identifier(index: 2))
    await harness.pump(until: Self.waitSeconds) { scrollView.contentView.bounds.minY > 0 }

    #expect(scrollView.contentView.bounds.minY > 0)
  }

  // MARK: - Links

  @Test func aCitationLinkInTheScopeHighlightsItsRow() async throws {
    let recorder = OpenedURLRecorder()
    let url = try #require(InlineCitation.url(index: 2))
    let harness = HostedViewHarness(
      VStack {
        OpenURLButton(url: url)
        SourcesView(payload: Self.payload)
      }
      .citationScope()
      .environment(\.openURL, OpenURLAction(handler: recorder.open)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: OpenURLButton.identifier)
    await harness.pump(until: Self.waitSeconds) { Self.isHighlighted(harness, index: 2) }

    #expect(Self.isHighlighted(harness, index: 2))
    #expect(recorder.urls.isEmpty)
  }

  @Test func anOtherLinkInTheScopeGoesToTheOuterAction() throws {
    let recorder = OpenedURLRecorder()
    let url = try #require(URL(string: "https://example.com/page"))
    let harness = HostedViewHarness(
      OpenURLButton(url: url)
        .citationScope()
        .environment(\.openURL, OpenURLAction(handler: recorder.open)),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: OpenURLButton.identifier)

    #expect(recorder.urls == [url])
  }

  // MARK: - Scroll

  /// Finds the first scroll view under a view, depth first.
  ///
  /// - Parameter view: The view to search.
  /// - Returns: The scroll view, or `nil`.
  static func firstScrollView(in view: NSView) -> NSScrollView? {
    if let scrollView = view as? NSScrollView { return scrollView }
    for subview in view.subviews {
      if let scrollView = firstScrollView(in: subview) { return scrollView }
    }
    return nil
  }
}
