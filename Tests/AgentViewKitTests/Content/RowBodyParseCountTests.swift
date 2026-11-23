#if DEBUG
  import AgentViewKitTestSupport
  import AppKit
  import Foundation
  import FoundationModelsACP
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The parses of the text of a row body (task ^0g7ftka, #scroll-perf).
  ///
  /// A row body parses its text one time for each change of the text, not one
  /// time for each evaluation of its body. Each test evaluates a body two
  /// times with an equal input, and reads the ``BodyEvaluationCounter``
  /// count of the parse. The views are in an `NSHostingView` with no window,
  /// so a test shows no window and takes no focus.
  @MainActor @Suite struct RowBodyParseCountTests {
    /// A text with prose, one Swift fence, and prose.
    static let fencedText = "Intro.\n\n```swift\nlet a = 1\n```\n\nEnd."

    /// A payload that cites one source in the second paragraph of
    /// ``citedText``.
    static let payload = CitationPayload(
      sources: [
        CitationSource(id: "s", title: "Source", url: URL(filePath: "/source"), snippet: "")
      ],
      markers: [CitationMarker(sourceID: "s", paragraphIndex: 1, offset: 3)])

    /// The text that ``payload`` cites.
    static let citedText = "One.\n\nTwo words."

    /// The text that a test adds to a text to change it.
    static let addedText = " More."

    /// Two streamed text chunks of one entry.
    static let chunks: [FoundationModelsACP.ContentBlock] = [
      .text(TextContent(text: "One.")), .text(TextContent(text: " Two.")),
    ]

    /// The width of the host of the tests.
    static let hostWidth: CGFloat = 400

    /// The message group that a test gives a response to make it evaluate
    /// its body again with the same text.
    static let otherGroup = "other-group"

    // MARK: - Hosts

    /// A response in a host with no window, laid out one time.
    ///
    /// - Parameters:
    ///   - id: The id of the response, unique to the test.
    ///   - markdown: The Markdown text.
    ///   - citations: The citations of the text, or `nil`.
    /// - Returns: The host.
    static func mountResponse(id: String, markdown: String, citations: CitationPayload? = nil)
      -> NSHostingView<AnyView>
    {
      resetCounts(of: id)
      let hosting = NSHostingView(
        rootView: response(id: id, markdown: markdown, citations: citations, group: nil))
      StyleViewHost.layOut(hosting)
      return hosting
    }

    /// A response at the width of the host.
    ///
    /// - Parameters:
    ///   - id: The id of the response.
    ///   - markdown: The Markdown text.
    ///   - citations: The citations of the text, or `nil`.
    ///   - group: The message group of the response, or `nil`.
    /// - Returns: The view.
    static func response(id: String, markdown: String, citations: CitationPayload?, group: String?)
      -> AnyView
    {
      AnyView(
        ResponseView(id: id, markdown: markdown, citations: citations)
          .environment(\.accessibilityMessageGroupID, group)
          .frame(width: hostWidth))
    }

    /// Gives the response in `hosting` a new message group and the same
    /// text, and lays it out again. The response then evaluates its body
    /// again.
    ///
    /// - Parameters:
    ///   - hosting: The host of ``mountResponse(id:markdown:citations:)``.
    ///   - id: The id of the response.
    ///   - markdown: The Markdown text, the same text as before.
    ///   - citations: The citations of the text, or `nil`.
    static func evaluateAgain(
      _ hosting: NSHostingView<AnyView>, id: String, markdown: String,
      citations: CitationPayload? = nil
    ) {
      hosting.rootView = response(
        id: id, markdown: markdown, citations: citations, group: otherGroup)
      StyleViewHost.layOut(hosting)
    }

    /// Gives the response in `hosting` a new text, and lays it out again.
    ///
    /// - Parameters:
    ///   - hosting: The host of ``mountResponse(id:markdown:citations:)``.
    ///   - id: The id of the response.
    ///   - markdown: The new Markdown text.
    ///   - citations: The citations of the text, or `nil`.
    static func change(
      _ hosting: NSHostingView<AnyView>, id: String, to markdown: String,
      citations: CitationPayload? = nil
    ) {
      hosting.rootView = response(id: id, markdown: markdown, citations: citations, group: nil)
      StyleViewHost.layOut(hosting)
    }

    /// The content of one entry in a host with no window, laid out one
    /// time.
    ///
    /// - Parameters:
    ///   - id: The id of the entry, unique to the test.
    ///   - content: The content blocks of the entry.
    /// - Returns: The host.
    static func mountEntry(id: String, content: [FoundationModelsACP.ContentBlock])
      -> NSHostingView<AnyView>
    {
      resetCounts(of: id)
      let hosting = NSHostingView(rootView: entry(id: id, content: content))
      StyleViewHost.layOut(hosting)
      return hosting
    }

    /// The content of one entry at the width of the host.
    ///
    /// - Parameters:
    ///   - id: The id of the entry.
    ///   - content: The content blocks of the entry.
    /// - Returns: The view.
    static func entry(id: String, content: [FoundationModelsACP.ContentBlock]) -> AnyView {
      AnyView(EntryContentView(content: content, id: id).frame(width: hostWidth))
    }

    /// Gives the entry in `hosting` new content, and lays it out again.
    ///
    /// - Parameters:
    ///   - hosting: The host of ``mountEntry(id:content:)``.
    ///   - id: The id of the entry.
    ///   - content: The content blocks of the entry.
    static func give(
      _ hosting: NSHostingView<AnyView>, id: String, content: [FoundationModelsACP.ContentBlock]
    ) {
      hosting.rootView = entry(id: id, content: content)
      StyleViewHost.layOut(hosting)
    }

    /// Sets each count of the views with `id` to zero.
    ///
    /// - Parameter id: The id of the view, unique to the test.
    static func resetCounts(of id: String) {
      for key in [
        ResponseView.counterKey(for: id), ResponseView.piecesCounterKey(for: id),
        ResponseView.chipsCounterKey(for: id), EntryContentView.counterKey(for: id),
        EntryContentView.joinCounterKey(for: id),
      ] {
        BodyEvaluationCounter.reset(key)
      }
    }

    // MARK: - The memo

    /// The counter key of the memo tests. No other test uses it.
    static let memoKey = "parse-count-memo-test"

    /// A production change that fails this test: the memo parses an input
    /// that is equal to its last input again.
    @Test func theMemoParsesAnEqualInputOneTime() {
      BodyEvaluationCounter.reset(Self.memoKey)
      let memo = ParseMemo<String, Int>()

      for _ in 0..<2 {
        _ = memo.value(for: "abc", counterKey: Self.memoKey) { $0.count }
      }

      #expect(BodyEvaluationCounter.count(Self.memoKey) == 1)
    }

    /// A production change that fails this test: the memo gives the output
    /// of its last input for a new input.
    @Test func theMemoGivesTheOutputOfANewInput() {
      let memo = ParseMemo<String, Int>()
      _ = memo.value(for: "abc", counterKey: Self.memoKey) { $0.count }

      #expect(memo.value(for: "abcd", counterKey: Self.memoKey) { $0.count } == 4)
    }

    /// The sum of the counts of the keys of `ids`.
    ///
    /// - Parameters:
    ///   - key: The counter key of an id.
    ///   - ids: The ids of the views.
    /// - Returns: The sum of the ``BodyEvaluationCounter`` counts.
    static func count(_ key: (String) -> String, of ids: [String]) -> Int {
      ids.map { BodyEvaluationCounter.count(key($0)) }.reduce(0, +)
    }

    // MARK: - Fence pieces

    /// A production change that fails this test: the response finds the
    /// fences of its text at each evaluation of its body.
    @Test func aResponseThatEvaluatesAgainWithTheSameTextFindsItsFencesOneTime() throws {
      let id = "parse-count-pieces-same"
      let hosting = Self.mountResponse(id: id, markdown: Self.fencedText)

      Self.evaluateAgain(hosting, id: id, markdown: Self.fencedText)

      try #require(BodyEvaluationCounter.count(ResponseView.counterKey(for: id)) >= 2)
      #expect(BodyEvaluationCounter.count(ResponseView.piecesCounterKey(for: id)) == 1)
    }

    /// A production change that fails this test: the response keeps the
    /// fences of its first text when its text changes.
    @Test func aResponseWithANewTextFindsItsFencesOneMoreTime() {
      let id = "parse-count-pieces-new"
      let hosting = Self.mountResponse(id: id, markdown: Self.fencedText)

      Self.change(hosting, id: id, to: Self.fencedText + Self.addedText)

      #expect(BodyEvaluationCounter.count(ResponseView.piecesCounterKey(for: id)) == 2)
    }

    // MARK: - Citation chips

    /// A production change that fails this test: the response makes the
    /// citation chips of its text at each evaluation of its body.
    @Test func aResponseThatEvaluatesAgainWithTheSameTextMakesItsChipsOneTime() throws {
      let id = "parse-count-chips-same"
      let hosting = Self.mountResponse(id: id, markdown: Self.citedText, citations: Self.payload)

      Self.evaluateAgain(hosting, id: id, markdown: Self.citedText, citations: Self.payload)

      try #require(BodyEvaluationCounter.count(ResponseView.counterKey(for: id)) >= 2)
      #expect(BodyEvaluationCounter.count(ResponseView.chipsCounterKey(for: id)) == 1)
    }

    /// A production change that fails this test: the response makes the
    /// chips of each prose segment of a text with a fence from the whole
    /// text again.
    @Test func aResponseWithAFenceMakesTheChipsOfItsTextOneTime() {
      let id = "parse-count-chips-fence"
      _ = Self.mountResponse(id: id, markdown: Self.fencedText, citations: Self.payload)

      #expect(BodyEvaluationCounter.count(ResponseView.chipsCounterKey(for: id)) == 1)
    }

    /// A production change that fails this test: the response keeps the
    /// chips of its first text when its text changes.
    @Test func aResponseWithANewTextMakesItsChipsOneMoreTime() {
      let id = "parse-count-chips-new"
      let hosting = Self.mountResponse(id: id, markdown: Self.citedText, citations: Self.payload)

      Self.change(hosting, id: id, to: Self.citedText + Self.addedText, citations: Self.payload)

      #expect(BodyEvaluationCounter.count(ResponseView.chipsCounterKey(for: id)) == 2)
    }

    // MARK: - Joined text chunks

    /// A production change that fails this test: the entry joins its text
    /// chunks at each evaluation of its body.
    ///
    /// SwiftUI does not evaluate the body of an entry again for equal
    /// content and an equal id. So the test gives the entry a new id and
    /// equal content. The id is not an input of the join.
    @Test func anEntryThatEvaluatesAgainWithEqualContentJoinsItsChunksOneTime() throws {
      let id = "parse-count-join-same"
      let otherID = id + "-other"
      Self.resetCounts(of: otherID)
      let hosting = Self.mountEntry(id: id, content: Self.chunks)

      Self.give(hosting, id: otherID, content: Self.chunks)

      try #require(Self.count(EntryContentView.counterKey(for:), of: [id, otherID]) >= 2)
      #expect(Self.count(EntryContentView.joinCounterKey(for:), of: [id, otherID]) == 1)
    }

    /// A production change that fails this test: the entry keeps the joined
    /// text of its first content when a new chunk comes.
    @Test func anEntryWithANewChunkJoinsItsChunksOneMoreTime() {
      let id = "parse-count-join-new"
      let hosting = Self.mountEntry(id: id, content: Self.chunks)

      Self.give(hosting, id: id, content: Self.chunks + [.text(TextContent(text: Self.addedText))])

      #expect(BodyEvaluationCounter.count(EntryContentView.joinCounterKey(for: id)) == 2)
    }
  }
#endif
