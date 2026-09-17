import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``ResponseView`` and ``ParagraphView``.
@Suite(.serialized, .hostedSerially) @MainActor struct ResponseViewHostedTests {
  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 640)

  /// The longest time that a test waits for the view to change, in seconds.
  static let changeWaitSeconds: TimeInterval = 2

  /// A text with three settled paragraphs and a tail.
  static let fourParagraphText = "One.\n\nTwo.\n\nThree.\n\nFour"

  /// Makes an assistant message with no content, for a streaming response.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The message.
  static func emptyMessage(_ id: String) -> Message {
    Message(id: id, blocks: [])
  }

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

  @Test func threeSettledParagraphsAndATailMountFourParagraphElements() {
    let id = "response-four"
    let streaming = StreamingMessage(id: id, text: Self.fourParagraphText)
    let harness = HostedViewHarness(
      ResponseView(message: Self.emptyMessage(id), streaming: streaming), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(streaming.settledParagraphs.count == 3)
    let paragraphs = Self.paragraphIdentifiers(in: harness, limit: 4)
    #expect(paragraphs == (0..<3).map(ResponseView.paragraphIdentifier(index:)))
    #expect(harness.element(identifier: ResponseView.tailIdentifier) != nil)
  }

  @Test func aMessageWithNoStreamShowsEachParagraphAsSettled() {
    let message = Message(
      id: "response-settled",
      blocks: [ContentBlock(text: "One.\n\nTwo."), ContentBlock(text: "Three.")])
    let harness = HostedViewHarness(
      ResponseView(message: message, streaming: nil), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let paragraphs = Self.paragraphIdentifiers(in: harness, limit: 4)
    #expect(paragraphs == (0..<3).map(ResponseView.paragraphIdentifier(index:)))
    #expect(harness.element(identifier: ResponseView.tailIdentifier) == nil)
  }

  @Test func aBlockThatIsNotForTheUserIsNotShown() {
    let hidden = ContentBlock(
      content: .text("Hidden."), annotations: Annotations(audience: [.assistant]))
    let message = Message(
      id: "response-audience", blocks: [ContentBlock(text: "Shown."), hidden])
    #expect(ResponseView.markdown(of: message) == "Shown.")
  }

  @Test func anEmptyTailMountsNoTailElement() {
    let id = "response-empty-tail"
    let streaming = StreamingMessage(id: id, text: "One.\n\n")
    let harness = HostedViewHarness(
      ResponseView(message: Self.emptyMessage(id), streaming: streaming), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(Self.paragraphIdentifiers(in: harness, limit: 2) == [
      ResponseView.paragraphIdentifier(index: 0)
    ])
    #expect(harness.element(identifier: ResponseView.tailIdentifier) == nil)
  }

  // MARK: - Evaluations

  @Test func aChunkInTheTailEvaluatesOnlyTheTail() async {
    let id = "response-evaluations"
    let streaming = StreamingMessage(id: id, text: Self.fourParagraphText)
    let harness = HostedViewHarness(
      ResponseView(message: Self.emptyMessage(id), streaming: streaming), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let tailKey = ResponseView.tailCounterKey(messageID: id)
    let paragraphKeys = streaming.settledParagraphs.map {
      ParagraphView.counterKey(messageID: id, paragraphID: $0.id)
    }
    #expect(paragraphKeys.count == 3)
    for key in paragraphKeys {
      #expect(BodyEvaluationCounter.count(key) >= 1)
    }
    #expect(BodyEvaluationCounter.count(tailKey) >= 1)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
    BodyEvaluationCounter.reset(tailKey)

    streaming.append(" and more")
    streaming.flush()
    await harness.pump(until: Self.changeWaitSeconds) {
      BodyEvaluationCounter.count(tailKey) >= 1
    }
    harness.pump()

    #expect(streaming.tail == .markdown("Four and more"))
    #expect(BodyEvaluationCounter.count(tailKey) == 1)
    for key in paragraphKeys {
      #expect(BodyEvaluationCounter.count(key) == 0, "The paragraph \(key) evaluated again.")
    }
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
    BodyEvaluationCounter.reset(tailKey)
  }

  // MARK: - Code fences

  @Test func aSettledFencedBlockMountsACodeBlock() {
    let message = Message(
      id: "response-settled-fence",
      blocks: [ContentBlock(text: "Some code:\n\n```swift\nlet x = 1\n```")])
    let harness = HostedViewHarness(
      ResponseView(message: message, streaming: nil), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "swift code block")
    #expect(Self.paragraphIdentifiers(in: harness, limit: 3).count == 2)
  }

  @Test func anOpenFenceInTheTailMountsACodeBlockAndAppendsToItsModel() async {
    let id = "response-open-fence"
    let cache = CodeBlockModelCache()
    let streaming = StreamingMessage(id: id, text: "Some code:\n\n```swift\nlet x")
    let harness = HostedViewHarness(
      ResponseView(message: Self.emptyMessage(id), streaming: streaming)
        .environment(\.codeBlockModelCache, cache),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(streaming.tail == .openFence(language: "swift", body: "let x"))
    #expect(harness.element(identifier: CodeBlockView.identifier)?.label == "swift code block")
    let blockID = ResponseView.tailBlockID(messageID: id)
    #expect(cache.contains(blockID))
    let model = cache.model(for: blockID, code: "")
    #expect(model.text == "let x")

    streaming.append(" = 1\nprint(x)")
    streaming.flush()
    await harness.pump(until: Self.changeWaitSeconds) {
      model.text == "let x = 1\nprint(x)"
    }

    #expect(model.text == "let x = 1\nprint(x)")
    #expect(cache.model(for: blockID, code: "") === model)
    #expect(model.isReadOnly)
  }

  @Test func theOpenFenceBodyDropsOneLineBreakAtTheEnd() {
    #expect(ResponseView.displayedCode(ofFenceBody: "let x\n") == "let x")
    #expect(ResponseView.displayedCode(ofFenceBody: "let x\n\n") == "let x\n")
    #expect(ResponseView.displayedCode(ofFenceBody: "let x") == "let x")
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
}
