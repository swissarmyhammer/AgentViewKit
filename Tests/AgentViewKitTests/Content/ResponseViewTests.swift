import AppKit
import EditorSwiftUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The text of an agent answer in the rendered form of EditorKit (AVK-9.7,
/// D185).
@MainActor @Suite struct ResponseViewTests {
  /// A payload that cites one source in the second paragraph of
  /// ``citedText``.
  static let payload = CitationPayload(
    sources: [CitationSource(id: "s", title: "Source", url: URL(filePath: "/source"), snippet: "")],
    markers: [CitationMarker(sourceID: "s", paragraphIndex: 1, offset: 3)])

  /// The text that ``payload`` cites.
  static let citedText = "One.\n\nTwo words."

  /// A text with prose, one Swift fence, and prose.
  static let fencedText = "Intro.\n\n```swift\nlet a = 1\n```\n\nEnd."

  /// The width of the host of the tests that lay out a response.
  static let hostWidth: CGFloat = 400

  /// Lays out a response with `markdown` in a host with no window, so the
  /// test shows no window and takes no focus.
  ///
  /// - Parameter markdown: The Markdown text of the response.
  /// - Returns: The host.
  static func mount(_ markdown: String) -> NSHostingView<some View> {
    let hosting = NSHostingView(
      rootView: ResponseView(id: "response", markdown: markdown).frame(width: hostWidth))
    hosting.frame = NSRect(origin: .zero, size: hosting.fittingSize)
    hosting.layoutSubtreeIfNeeded()
    return hosting
  }

  /// The text of each text view under `view`, in tree order.
  ///
  /// - Parameter view: The root view.
  /// - Returns: The texts.
  static func texts(under view: NSView) -> [String] {
    if let text = view as? NSTextView { return [text.string] }
    return view.subviews.flatMap(texts(under:))
  }

  /// The accessibility labels of the code block views under `view`.
  ///
  /// - Parameter view: The root view.
  /// - Returns: The label of each element with the identifier
  ///   ``CodeBlockView/identifier``.
  static func codeBlockLabels(under view: NSView) async -> [String] {
    await withAccessibilityTree {
      accessibilityElements(identifiedAs: CodeBlockView.identifier, under: view)
        .compactMap(accessibilityLabel(of:))
    }
  }

  @Test func theResponseShowsItsTextInTheRenderedMarkdownView() {
    let body = ResponseView(id: "response", markdown: "Some **text**.").body

    #expect(String(describing: type(of: body)).contains("RenderedMarkdownView"))
  }

  // MARK: - Fenced code blocks

  /// A production change that fails this test: the response shows the
  /// fence in its Markdown editor, so one text view holds the whole text.
  @Test func aResponseWithOneFenceShowsProseCodeAndProse() {
    let hosting = Self.mount(Self.fencedText)

    #expect(Self.texts(under: hosting) == ["Intro.", "let a = 1", "End."])
  }

  /// A production change that fails this test: the code of a fence shows
  /// in an editor that is not a ``CodeBlockView``.
  @Test func theFenceOfAResponseShowsInACodeBlockViewWithItsLanguage() async {
    let hosting = Self.mount(Self.fencedText)

    #expect(await Self.codeBlockLabels(under: hosting) == ["swift code block"])
  }

  /// A production change that fails this test: a response with no fence
  /// splits its text, or shows a code block view.
  @Test func aResponseWithNoFenceShowsOneMarkdownViewAndNoCodeBlockView() async {
    let text = "One.\n\nTwo."
    let hosting = Self.mount(text)

    #expect(Self.texts(under: hosting) == [text])
    #expect(await Self.codeBlockLabels(under: hosting).isEmpty)
  }

  /// A production change that fails this test: each segment of a response
  /// shares one model, so a segment shows the text of another.
  @Test func eachSegmentOfAResponseHasAModelIDOfItsOwn() {
    let ids = [
      ResponseView.segmentModelID(for: "response", index: 0, isCode: false),
      ResponseView.segmentModelID(for: "response", index: 1, isCode: true),
      ResponseView.segmentModelID(for: "response", index: 1, isCode: false),
      ResponseView.modelID(for: "response"),
    ]

    #expect(Set(ids).count == ids.count)
  }

  /// A production change that fails this test: the models of the segments
  /// of a response stay in the cache after the eviction of its message.
  @Test func theEvictionOfAMessageRemovesTheModelsOfItsSegments() {
    let cache = CodeBlockModelCache()
    _ = cache.model(
      for: ResponseView.segmentModelID(for: "response", index: 1, isCode: true), code: "x")

    cache.evict(messageID: "response")

    #expect(cache.count == 0)
  }

  // MARK: - Citations

  @Test func aResponseWithNoPayloadShowsNoChip() {
    #expect(ResponseView(id: "response", markdown: Self.citedText).chips.isEmpty)
  }

  @Test func theChipsOfAResponseAreTheChipsOfItsPayload() {
    let view = ResponseView(id: "response", markdown: Self.citedText, citations: Self.payload)

    #expect(view.chips == Self.payload.editorCitations(in: Self.citedText))
  }

  /// A text that cites a source in the prose after a fence.
  static let fencedCitedText = "One.\n\n```\nx\n```\n\nTwo words."

  /// A payload that cites one source in the third paragraph of
  /// ``fencedCitedText``.
  static let fencedPayload = CitationPayload(
    sources: payload.sources, markers: [CitationMarker(sourceID: "s", paragraphIndex: 2, offset: 3)]
  )

  /// A production change that fails this test: a chip keeps its offset in
  /// the whole text, so it shows at a wrong place of its prose segment.
  @Test func aChipMovesToTheStartOfItsProseSegment() throws {
    let pieces = MarkdownCodeFences.pieces(in: Self.fencedCitedText)
    let last = try #require(pieces.last)
    let chips = Self.fencedPayload.editorCitations(in: Self.fencedCitedText)

    let moved = ResponseView.chips(chips, in: last.range, of: Self.fencedCitedText)

    #expect(moved.map(\.offset) == [3])
  }

  /// A production change that fails this test: a chip shows in each prose
  /// segment, and not only in the segment that holds its offset.
  @Test func aChipDoesNotShowInAnotherProseSegment() throws {
    let pieces = MarkdownCodeFences.pieces(in: Self.fencedCitedText)
    let first = try #require(pieces.first)
    let chips = Self.fencedPayload.editorCitations(in: Self.fencedCitedText)

    #expect(ResponseView.chips(chips, in: first.range, of: Self.fencedCitedText).isEmpty)
  }

  // MARK: - Models

  @Test func theModelOfAResponseIsReadOnlyAndRendered() {
    let model = ResponseView.model(in: CodeBlockModelCache(), id: "response", markdown: "Text.")

    #expect(model.isReadOnly)
    #expect(model.presentation == .rendered)
    #expect(model.text == "Text.")
  }

  @Test func theCacheKeepsTheModelOfAResponseByItsID() {
    let cache = CodeBlockModelCache()
    let model = ResponseView.model(in: cache, id: "response", markdown: "Text.")

    #expect(ResponseView.model(in: cache, id: "response", markdown: "Text. More.") === model)
  }

  @Test func eachResponseHasAModelOfItsOwn() {
    let cache = CodeBlockModelCache()

    #expect(
      ResponseView.model(in: cache, id: "first", markdown: "One.")
        !== ResponseView.model(in: cache, id: "second", markdown: "One."))
  }

  @Test func aStreamedChunkChangesOnlyTheModelOfItsResponse() {
    let cache = CodeBlockModelCache()
    let streamed = ResponseView.model(in: cache, id: "streamed", markdown: "One.")
    let settled = ResponseView.model(in: cache, id: "settled", markdown: "Two.")
    let settledVersion = settled.state.version

    RenderedMarkdownView.sync(streamed, to: "One. More.")

    #expect(streamed.text == "One. More.")
    #expect(settled.text == "Two.")
    #expect(settled.state.version == settledVersion)
  }

  @Test func theEvictionOfAMessageRemovesTheModelOfItsResponse() {
    let cache = CodeBlockModelCache()
    _ = ResponseView.model(in: cache, id: "response", markdown: "Text.")

    cache.evict(messageID: "response")

    #expect(cache.count == 0)
  }

  // MARK: - Rows far from view (task ^t9416x5)

  /// The height of a laid-out text in the tests of the placeholder.
  static let laidOutHeight: CGFloat = 40

  /// A production change that fails this test: a live row drops its editor.
  @Test func aLiveResponseShowsItsEditor() {
    #expect(
      ResponseView.placeholderHeight(
        isLive: true, laidOutHeight: Self.laidOutHeight, holdsSelection: false) == nil)
  }

  /// A production change that fails this test: a response far from view
  /// keeps its editor and its model.
  @Test func aResponseFarFromViewShowsAPlaceholderOfItsHeight() {
    #expect(
      ResponseView.placeholderHeight(
        isLive: false, laidOutHeight: Self.laidOutHeight, holdsSelection: false)
        == Self.laidOutHeight)
  }

  /// A production change that fails this test: a response that was never
  /// laid out shows an empty placeholder, so the row has no height.
  @Test func aResponseThatWasNeverLaidOutShowsItsEditor() {
    #expect(
      ResponseView.placeholderHeight(isLive: false, laidOutHeight: nil, holdsSelection: false)
        == nil)
  }

  /// A production change that fails this test: a response far from view
  /// drops the editor that holds the selection of the thread, so a copy
  /// copies nothing.
  @Test func aResponseThatHoldsTheSelectionShowsItsEditor() {
    #expect(
      ResponseView.placeholderHeight(
        isLive: false, laidOutHeight: Self.laidOutHeight, holdsSelection: true) == nil)
  }
}
