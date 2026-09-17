import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// The fast unit form of the benchmark gate "settled paragraphs are not
/// evaluated again" (plan.md §8, research R1, `Benchmarks/README.md`).
///
/// The benchmark package builds in release mode, and
/// ``BodyEvaluationCounter`` exists only in debug builds. Thus these tests
/// count the body evaluations of each ``ParagraphView`` in a hosted
/// ``ResponseView`` while a stream settles one paragraph after the other.
@Suite(.serialized, .hostedSerially) @MainActor struct ParagraphReuseTests {
  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 1_200)

  /// The longest time that a test waits for the view to change, in seconds.
  static let changeWaitSeconds: TimeInterval = 2

  /// The number of paragraphs that the long stream settles.
  static let streamedParagraphCount = 8

  /// The number of streamed paragraphs that stay in the tail. The last
  /// paragraph has no blank line after it, so it does not settle.
  static let tailParagraphCount = 1

  /// The chunks of the long stream. Each paragraph comes in three chunks, and
  /// the first chunk of each paragraph after the first settles the paragraph
  /// before it.
  static let streamedChunks: [String] = (0..<streamedParagraphCount).flatMap { index in
    [index == 0 ? "Paragraph" : "\n\nParagraph", " number \(index)", " ends here."]
  }

  /// Makes an assistant message with no content, for a streaming response.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The message.
  static func emptyMessage(_ id: String) -> Message {
    Message(id: id, blocks: [])
  }

  /// The two layouts of the settled paragraphs: a stack, and a lazy stack in
  /// a scroll view.
  nonisolated static let layouts = [false, true]

  /// Mounts the response view of a stream.
  ///
  /// - Parameters:
  ///   - streaming: The stream.
  ///   - isLazy: Whether the view is in a scroll view with lazy paragraphs,
  ///     as in ``ConversationView``.
  /// - Returns: The harness.
  static func host(_ streaming: StreamingMessage, isLazy: Bool) -> HostedViewHarness<some View> {
    HostedViewHarness(size: hostSize) {
      let response = ResponseView(message: emptyMessage(streaming.id), streaming: streaming)
      if isLazy {
        ScrollView { response }
          .lazyResponseParagraphs()
      } else {
        response
      }
    }
  }

  /// The body evaluation count of each settled paragraph of a stream, keyed
  /// by counter key.
  ///
  /// - Parameter streaming: The stream.
  /// - Returns: The count of each settled paragraph.
  static func settledCounts(of streaming: StreamingMessage) -> [String: Int] {
    Dictionary(
      uniqueKeysWithValues: streaming.settledParagraphs.map { paragraph in
        let key = ParagraphView.counterKey(messageID: streaming.id, paragraphID: paragraph.id)
        return (key, BodyEvaluationCounter.count(key))
      })
  }

  /// Gives one chunk to the stream and waits until the tail evaluates again.
  ///
  /// - Parameters:
  ///   - chunk: The chunk.
  ///   - streaming: The stream.
  ///   - harness: The harness that hosts the view of the stream.
  static func stream(
    _ chunk: String, into streaming: StreamingMessage, harness: HostedViewHarness<some View>
  ) async {
    let tailKey = ResponseView.tailCounterKey(messageID: streaming.id)
    BodyEvaluationCounter.reset(tailKey)
    streaming.append(chunk)
    streaming.flush()
    await harness.pump(until: changeWaitSeconds) {
      BodyEvaluationCounter.count(tailKey) >= 1
    }
    harness.pump()
  }

  @Test(arguments: layouts)
  func aChunkThatSettlesAParagraphEvaluatesOnlyTheNewParagraph(isLazy: Bool) async {
    let id = "paragraph-reuse-settle-\(isLazy)"
    let streaming = StreamingMessage(id: id, text: "One.\n\nTwo")
    let harness = Self.host(streaming, isLazy: isLazy)
    defer { harness.close() }
    harness.pump()
    let firstKey = ParagraphView.counterKey(
      messageID: id, paragraphID: streaming.settledParagraphs[0].id)
    #expect(BodyEvaluationCounter.count(firstKey) >= 1)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)

    await Self.stream(".\n\nThree", into: streaming, harness: harness)

    #expect(streaming.settledParagraphs.map(\.text) == ["One.", "Two."])
    let secondKey = ParagraphView.counterKey(
      messageID: id, paragraphID: streaming.settledParagraphs[1].id)
    #expect(BodyEvaluationCounter.count(firstKey) == 0, "The settled paragraph evaluated again.")
    #expect(BodyEvaluationCounter.count(secondKey) >= 1, "The new paragraph did not evaluate.")
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
    BodyEvaluationCounter.reset(ResponseView.tailCounterKey(messageID: id))
  }

  @Test(arguments: layouts)
  func aLongStreamNeverEvaluatesASettledParagraphAgain(isLazy: Bool) async {
    let id = "paragraph-reuse-long-\(isLazy)"
    let streaming = StreamingMessage(id: id)
    let harness = Self.host(streaming, isLazy: isLazy)
    defer { harness.close() }
    harness.pump()

    var previous: [String: Int] = [:]
    for chunk in Self.streamedChunks {
      await Self.stream(chunk, into: streaming, harness: harness)
      let current = Self.settledCounts(of: streaming)
      for (key, count) in previous {
        #expect(current[key] == count, "The settled paragraph \(key) evaluated again.")
      }
      for (key, count) in current where previous[key] == nil {
        #expect(count >= 1, "The new paragraph \(key) did not evaluate.")
      }
      previous = current
    }

    #expect(streaming.settledParagraphs.count == Self.streamedParagraphCount - Self.tailParagraphCount)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
    BodyEvaluationCounter.reset(ResponseView.tailCounterKey(messageID: id))
  }
}
