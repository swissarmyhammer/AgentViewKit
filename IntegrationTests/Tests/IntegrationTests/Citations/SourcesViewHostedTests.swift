import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
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

  /// Makes a response of ``text`` with the citations of the payload, and the
  /// footer of the payload below it, in one citation scope.
  ///
  /// - Parameter id: The id of the response view.
  /// - Returns: The view.
  static func citedResponse(id: String) -> some View {
    VStack {
      ResponseView(id: id, markdown: text, citations: payload)
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
    harness.render()

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
    harness.render()

    try harness.press(identifier: LinkView.cardIdentifier)

    #expect(recorder.urls == [Self.alpha.url])
  }

  @Test func aCollapsedFooterShowsNoRow() {
    let harness = HostedViewHarness(
      SourcesView(payload: Self.payload, isExpanded: false), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: SourcesView.identifier) != nil)
    #expect(harness.element(identifier: SourcesView.rowIdentifier(index: 1)) == nil)
  }

  // MARK: - Pills

  @Test func eachCitedParagraphShowsItsPill() {
    let harness = HostedViewHarness(
      Self.citedResponse(id: "cited-pills"), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: InlineCitation.identifier(index: 1))?.label == "Source 1")
    #expect(harness.element(identifier: InlineCitation.identifier(index: 2))?.label == "Source 2")
  }

  @Test func aResponseWithNoCitationsShowsNoPill() {
    let harness = HostedViewHarness(
      ResponseView(id: "uncited", markdown: Self.text), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ResponseView.paragraphIdentifier(index: 1)) != nil)
    #expect(harness.element(identifier: InlineCitation.identifier(index: 1)) == nil)
  }

  @Test func aTapOnPillTwoHighlightsRowTwo() throws {
    let harness = HostedViewHarness(
      Self.citedResponse(id: "cited-tap"), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    #expect(!Self.isHighlighted(harness, index: 2))

    try harness.press(identifier: InlineCitation.identifier(index: 2))

    #expect(Self.isHighlighted(harness, index: 2))
    #expect(!Self.isHighlighted(harness, index: 1))
  }

  @Test func aStandaloneInlineCitationHighlightsItsRow() throws {
    let harness = HostedViewHarness(
      VStack {
        InlineCitation(index: 1)
        SourcesView(payload: Self.payload)
      }
      .citationScope(),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: InlineCitation.identifier(index: 1))

    #expect(Self.isHighlighted(harness, index: 1))
    #expect(!Self.isHighlighted(harness, index: 2))
  }

  /// A pill opens a collapsed footer and highlights the row of its source.
  ///
  /// The footer opens in the `onChange` action of the render pass of the
  /// press. That action changes the state of the footer, so one more render
  /// pass shows the row.
  @Test func aPillOpensACollapsedFooter() throws {
    let harness = HostedViewHarness(
      VStack {
        InlineCitation(index: 2)
        SourcesView(payload: Self.payload, isExpanded: false)
      }
      .citationScope(),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: InlineCitation.identifier(index: 2))
    harness.render()

    #expect(Self.isHighlighted(harness, index: 2))
  }

  /// A pill scrolls the row of its source into view.
  ///
  /// The row scrolls in a main-actor task after the render pass of the press,
  /// and reports the scroll through
  /// ``SwiftUI/EnvironmentValues/citationScrollReport`` in the same step. The
  /// test waits for that report, so it reads the scroll position after the
  /// scroll, with no clock.
  @Test func aPillScrollsItsRowIntoView() async throws {
    let scrolls = ReportRecorder<Int>()
    let harness = HostedViewHarness(
      ScrollView {
        VStack {
          InlineCitation(index: 2)
          Color.clear.frame(height: Self.spacerHeight)
          SourcesView(payload: Self.payload)
        }
      }
      .citationScope()
      .environment(\.citationScrollReport, scrolls.report))
    defer { harness.close() }
    harness.render()
    let scrollView = try #require(views(ofType: NSScrollView.self, in: harness.hostingView).first)
    #expect(scrollView.contentView.bounds.minY == 0)

    try harness.press(identifier: InlineCitation.identifier(index: 2))
    // The pill selects its row in the same step, and the row then starts the
    // scroll task. A press that selected nothing stops the test here.
    try #require(Self.isHighlighted(harness, index: 2))
    await ObservationWait.until { !scrolls.values.isEmpty }

    #expect(scrolls.values.count == 1)
    #expect(scrollView.contentView.bounds.minY > 0)
  }

  // MARK: - Accent

  /// A link of the sources list shows the link mark in place of an accent
  /// text color: the accent is only for the selection and the focus (card
  /// ^y2mrfxt).
  @Test func aLinkInTheSourcesListShowsTheLinkMark() {
    let harness = HostedViewHarness(SourcesView(payload: Self.payload), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: SourcesView.linkMarkIdentifier(index: 1))?.label == "Link")
    #expect(harness.element(identifier: SourcesView.linkMarkIdentifier(index: 2))?.label == "Link")
  }

  // MARK: - Links

  @Test func aCitationLinkInTheScopeHighlightsItsRow() throws {
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
    harness.render()

    try harness.press(identifier: OpenURLButton.identifier)

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
    harness.render()

    try harness.press(identifier: OpenURLButton.identifier)

    #expect(recorder.urls == [url])
  }
}
