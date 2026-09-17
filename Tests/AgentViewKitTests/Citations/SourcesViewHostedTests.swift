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

  /// The schema name of a payload that has the citation shape but no
  /// registration.
  static let otherSchemaName = "Demo.Citation"

  /// The accessibility identifier of a host view.
  static let hostViewIdentifier = "host-sources"

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

  /// Makes a message with the text and a structured block of the payload.
  ///
  /// - Parameters:
  ///   - id: The identifier of the message.
  ///   - schemaName: The schema name of the structured block.
  ///   - citationFirst: Whether the structured block comes before the text.
  /// - Returns: The message.
  /// - Throws: The error of the payload encode.
  static func citedMessage(
    id: String,
    schemaName: String = CitationPayload.schemaName,
    citationFirst: Bool = false
  ) throws -> Message {
    let citation = ContentBlock(
      content: .structured(schemaName: schemaName, payload: try payload.jsonValue()))
    let text = ContentBlock(text: text)
    return Message(id: id, blocks: citationFirst ? [citation, text] : [text, citation])
  }

  /// Makes a thread with one assistant message.
  ///
  /// - Parameter message: The message.
  /// - Returns: The thread.
  static func thread(with message: Message) -> AgentThread {
    let thread = AgentThread()
    thread.apply(.insert(.assistantMessage(message), after: nil))
    return thread
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

  @Test func aMessageWithTwoSourcesRendersAFooterWithTwoRows() async throws {
    let message = try Self.citedMessage(id: "cited-rows")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message)), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: SourcesView.rowIdentifier(index: 2)) != nil
    }

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

  @Test func theFooterIsBelowTheTextWhenTheBlockComesFirst() async throws {
    let message = try Self.citedMessage(id: "cited-order", citationFirst: true)
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message)), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: SourcesView.identifier) != nil
    }

    let identifiers = harness.accessibilityElements().compactMap(\.identifier)
    let paragraph = try #require(identifiers.firstIndex(of: ResponseView.paragraphIdentifier(index: 1)))
    let sources = try #require(identifiers.firstIndex(of: SourcesView.identifier))
    #expect(paragraph < sources)
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

  @Test func eachCitedParagraphShowsItsPill() async throws {
    let message = try Self.citedMessage(id: "cited-pills")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message)), size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: InlineCitation.identifier(index: 2)) != nil
    }

    #expect(harness.element(identifier: InlineCitation.identifier(index: 1))?.label == "Source 1")
    #expect(harness.element(identifier: InlineCitation.identifier(index: 2))?.label == "Source 2")
  }

  @Test func aTapOnPillTwoHighlightsRowTwo() async throws {
    let message = try Self.citedMessage(id: "cited-tap")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message)), size: Self.hostSize)
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
    let message = try Self.citedMessage(id: "cited-stream")
    let thread = Self.thread(with: message)
    thread.apply(.appendStreaming(id: message.id, text: Self.text + "\n\nMore"))
    let harness = HostedViewHarness(AgentThreadView(thread: thread), size: Self.hostSize)
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

  // MARK: - Registry

  @Test func theStandardRegistryHasOnlyTheCitationName() {
    let registry = StructuredItemRegistry.standard

    #expect(registry.resolve(schemaName: CitationPayload.schemaName) != nil)
    #expect(registry.resolve(schemaName: Self.otherSchemaName) == nil)
    #expect(Array(registry.keys) == [CitationPayload.schemaName])
  }

  @Test func anUnregisteredCitationLikePayloadFallsBackToStructuredItemView() async throws {
    let message = try Self.citedMessage(id: "cited-other", schemaName: Self.otherSchemaName)
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message)), size: Self.hostSize)
    defer { harness.close() }
    let identifier = StructuredItemView.identifier(for: Self.otherSchemaName)
    await harness.pump(until: Self.waitSeconds) { harness.element(identifier: identifier) != nil }

    #expect(harness.element(identifier: identifier) != nil)
    #expect(harness.element(identifier: SourcesView.identifier) == nil)
    #expect(harness.element(identifier: InlineCitation.identifier(index: 1)) == nil)
  }

  @Test func aCitationPayloadThatDoesNotDecodeFallsBackToStructuredItemView() {
    let block = ContentBlock(
      content: .structured(schemaName: CitationPayload.schemaName, payload: .string("broken")))
    let harness = HostedViewHarness(
      ContentBlockView(block: block, id: "broken-0"), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: StructuredItemView.identifier(for: CitationPayload.schemaName)) != nil)
    #expect(harness.element(identifier: SourcesView.identifier) == nil)
  }

  @Test func aHostRegistrationReplacesTheSourcesView() async throws {
    let message = try Self.citedMessage(id: "cited-host")
    let harness = HostedViewHarness(
      AgentThreadView(thread: Self.thread(with: message))
        .structuredItem(CitationPayload.schemaName) { _ in
          Text("Host sources").accessibilityIdentifier(Self.hostViewIdentifier)
        },
      size: Self.hostSize)
    defer { harness.close() }
    await harness.pump(until: Self.waitSeconds) {
      harness.element(identifier: Self.hostViewIdentifier) != nil
    }

    #expect(harness.element(identifier: Self.hostViewIdentifier) != nil)
    #expect(harness.element(identifier: SourcesView.identifier) == nil)
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
