import EditorSwiftUI
import Foundation
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

  @Test func theResponseShowsItsTextInTheRenderedMarkdownView() {
    let body = ResponseView(id: "response", markdown: "Some **text**.").body

    #expect(String(describing: type(of: body)).contains("RenderedMarkdownView"))
  }

  // MARK: - Citations

  @Test func aResponseWithNoPayloadShowsNoChip() {
    #expect(ResponseView(id: "response", markdown: Self.citedText).chips.isEmpty)
  }

  @Test func theChipsOfAResponseAreTheChipsOfItsPayload() {
    let view = ResponseView(id: "response", markdown: Self.citedText, citations: Self.payload)

    #expect(view.chips == Self.payload.editorCitations(in: Self.citedText))
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
