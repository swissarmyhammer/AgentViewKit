import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Observation
import SwiftUI
import Testing

/// The guarantee "settled paragraphs are not evaluated again" (plan.md §8,
/// research R1).
///
/// ``BodyEvaluationCounter`` exists only in debug builds. These tests
/// count the body evaluations of each ``ParagraphView`` in a hosted
/// ``ResponseView`` while its Markdown text grows one chunk after the other,
/// as the text of a transcript entry grows.
///
/// The tests do not turn the run loop and do not suspend. Each change of the
/// text has exactly one ``HostedViewHarness/render()`` pass before the test
/// reads the counts. Thus a count shows only the evaluations of that change,
/// and no window event or late update from outside the test adds to it.
@Suite(.serialized, .hostedSerially) @MainActor struct ParagraphReuseTests {
  /// The text that the hosted response view shows. A test appends each chunk
  /// to it, as the session model appends a chunk to the text of an entry.
  @Observable final class GrowingText {
    /// The whole text.
    var text: String

    /// Makes the text.
    ///
    /// - Parameter text: The first text.
    init(_ text: String) {
      self.text = text
    }
  }

  /// The response view of a growing text.
  struct GrowingResponse: View {
    /// The id of the response view.
    let id: String

    /// The text to show.
    let growing: GrowingText

    var body: some View {
      ResponseView(id: id, markdown: growing.text)
    }
  }

  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 1_200)

  /// The number of paragraphs of the long text.
  static let paragraphCount = 8

  /// The chunks of the long text. Each paragraph comes in three chunks, and
  /// the first chunk of each paragraph after the first starts a new
  /// paragraph.
  static let chunks: [String] = (0..<paragraphCount).flatMap { index in
    [index == 0 ? "Paragraph" : "\n\nParagraph", " number \(index)", " ends here."]
  }

  /// The body evaluation count of each paragraph of `text`, keyed by counter
  /// key.
  ///
  /// - Parameters:
  ///   - text: The whole text of the response view.
  ///   - id: The id of the response view.
  /// - Returns: The count of each paragraph.
  static func counts(of text: String, id: String) -> [String: Int] {
    Dictionary(
      uniqueKeysWithValues: ParagraphSplitter.paragraphs(text).map { paragraph in
        let key = ParagraphView.counterKey(messageID: id, paragraphID: paragraph.id)
        return (key, BodyEvaluationCounter.count(key))
      })
  }

  /// Appends one chunk to the text, and makes one render pass.
  ///
  /// The change is on the main actor, so the pass applies it to the view
  /// graph at once, with no run loop turn. The caller then checks that the
  /// changed paragraphs evaluated.
  ///
  /// - Parameters:
  ///   - chunk: The chunk.
  ///   - growing: The text of the response view.
  ///   - harness: The harness that hosts the response view.
  static func append(_ chunk: String, to growing: GrowingText, harness: HostedViewHarness<some View>) {
    growing.text += chunk
    harness.render()
  }

  @Test func aChunkThatStartsAParagraphEvaluatesOnlyTheChangedParagraphs() {
    let id = "paragraph-reuse-start"
    let growing = GrowingText("One.\n\nTwo")
    let harness = HostedViewHarness(GrowingResponse(id: id, growing: growing), size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    let paragraphs = ParagraphSplitter.paragraphs(growing.text)
    let firstKey = ParagraphView.counterKey(messageID: id, paragraphID: paragraphs[0].id)
    #expect(BodyEvaluationCounter.count(firstKey) >= 1)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)

    Self.append(".\n\nThree", to: growing, harness: harness)

    let thirdKey = ParagraphView.counterKey(
      messageID: id, paragraphID: ParagraphSplitter.paragraphs(growing.text)[2].id)
    #expect(BodyEvaluationCounter.count(firstKey) == 0, "The first paragraph evaluated again.")
    #expect(BodyEvaluationCounter.count(thirdKey) >= 1, "The new paragraph did not evaluate.")
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
  }

  @Test func aLongTextNeverEvaluatesAnEarlierParagraphAgain() {
    let id = "paragraph-reuse-long"
    let growing = GrowingText("")
    let harness = HostedViewHarness(GrowingResponse(id: id, growing: growing), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    // A chunk can change the text of the last paragraph, and so its id. Each
    // paragraph before the last one keeps its text, its id and its count.
    var previous: [String: Int] = [:]
    var previousLastKey: String?
    for chunk in Self.chunks {
      Self.append(chunk, to: growing, harness: harness)
      let current = Self.counts(of: growing.text, id: id)
      for (key, count) in previous where key != previousLastKey {
        #expect(current[key] == count, "The earlier paragraph \(key) evaluated again.")
      }
      for (key, count) in current where previous[key] == nil {
        #expect(count >= 1, "The new paragraph \(key) did not evaluate.")
      }
      previous = current
      previousLastKey = ParagraphSplitter.paragraphs(growing.text).last.map {
        ParagraphView.counterKey(messageID: id, paragraphID: $0.id)
      }
    }

    #expect(ParagraphSplitter.paragraphs(growing.text).count == Self.paragraphCount)
    BodyEvaluationCounter.reset(prefix: ParagraphView.counterKeyPrefix + id)
  }
}
