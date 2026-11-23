#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The EditorKit models of the rows of a thread when the rows scroll away
  /// and come back (task ^3qvtsgh).
  ///
  /// A row far from the rows in view drops its editor (``LiveRowRange``).
  /// ``ConversationView`` keeps the models of its rows in one thread-level
  /// ``CodeBlockModelCache``, so a row that comes back gets its old models
  /// and does not make new ones.
  ///
  /// The tests count the models that ``RenderedMarkdownView/makeModel(_:)``
  /// and ``CodeBlockView/makeModel(_:)`` make, with the
  /// ``BodyEvaluationCounter`` key of each text. Each answer has texts of
  /// its own, so the counts of other tests do not change the counts here.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadModelCacheHostedTests {
    /// The number of answers in the transcript. It is larger than the rows
    /// in view and the live rows on both sides of them.
    static let answerCount = 300

    /// The size of the window of the harness.
    static let size = CGSize(width: 600, height: 800)

    /// The text of the answer at `index`: a prose segment and a fenced code
    /// block, each with a text that no other test uses.
    ///
    /// - Parameter index: The index of the answer.
    /// - Returns: The Markdown text.
    static func answer(_ index: Int) -> String {
      "Model cache answer \(index).\n\n```swift\nlet modelCacheValue\(index) = \(index)\n```\n"
    }

    /// The texts of a transcript of ``answerCount`` answers.
    static let answers = (0..<answerCount).map { answer($0) }

    /// The ``BodyEvaluationCounter`` key of each model of `markdown`: one key
    /// for each prose segment and one key for each code segment.
    ///
    /// - Parameter markdown: The Markdown text of an answer.
    /// - Returns: The keys of the models of the answer.
    static func modelKeys(of markdown: String) -> [String] {
      MarkdownCodeFences.pieces(in: markdown).map { piece in
        switch piece.segment {
        case .prose(let text): RenderedMarkdownView.modelCounterKey(for: text)
        case .code(let code, _, _): CodeBlockView.modelCounterKey(for: code)
        }
      }
    }

    /// The keys of the models of each answer of the transcript.
    static let keys = answers.flatMap { modelKeys(of: $0) }

    /// Sets the count of each key of the transcript to zero.
    static func resetCounts() {
      for key in keys {
        BodyEvaluationCounter.reset(key)
      }
    }

    /// The keys of the transcript that have one count or more.
    static var countedKeys: [String] {
      keys.filter { BodyEvaluationCounter.count($0) > 0 }
    }

    /// Scrolls the conversation to the row with `key`
    /// (``ConversationViewHostedTests/jump(to:anchors:harness:)``), and
    /// renders the update that the scroll queued: the new live rows.
    ///
    /// - Parameters:
    ///   - key: The row key of the entry to scroll to.
    ///   - anchors: The manager of the conversation.
    ///   - harness: The harness that shows the conversation.
    static func scroll<Content: View>(
      to key: String, anchors: ScrollAnchorManager, harness: HostedViewHarness<Content>
    ) async {
      ConversationViewHostedTests.jump(to: key, anchors: anchors, harness: harness)
      await harness.renderAfter { anchors.visibleIDs.contains(key) }
    }

    /// A production change that fails this test: a row keeps its models in
    /// the state of its views, so a row that scrolls away and comes back
    /// makes new models.
    @Test func aScrollDownAndBackUpMakesNoNewModelForTheRowsAlreadySeen() async throws {
      Self.resetCounts()
      defer { Self.resetCounts() }
      let session = SessionModel.preview(transcript: Self.answers.map { .agent($0) })
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(
        ConversationView(session: session, anchors: anchors), size: Self.size)
      defer { harness.close() }
      let firstKey = try #require(session.transcript.first?.rowKey)
      let lastKey = try #require(session.transcript.last?.rowKey)
      await Self.scroll(to: firstKey, anchors: anchors, harness: harness)
      let seen = Self.countedKeys
      try #require(!seen.isEmpty)
      await Self.scroll(to: lastKey, anchors: anchors, harness: harness)
      Self.resetCounts()

      await Self.scroll(to: firstKey, anchors: anchors, harness: harness)

      let made = seen.map { BodyEvaluationCounter.count($0) }.reduce(0, +)
      #expect(made == 0, "\(made) new models for \(seen.count) models already seen")
    }

    /// A production change that fails this test: ``ConversationView`` gives
    /// its rows its own cache also when the host gives a cache, so the host
    /// cannot keep or evict the models of the rows.
    @Test func aCacheOfTheHostGetsTheModelsOfTheRows() {
      let cache = CodeBlockModelCache()
      let text = Self.answer(0)
      let session = SessionModel.preview(transcript: [.agent(text)])

      let harness = HostedViewHarness(
        ConversationView(session: session).environment(\.codeBlockModelCache, cache),
        size: Self.size)
      defer { harness.close() }

      #expect(cache.count == Self.modelKeys(of: text).count)
    }
  }
#endif
