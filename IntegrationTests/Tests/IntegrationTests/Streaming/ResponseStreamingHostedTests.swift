@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTestSupport
import Foundation
import Observation
import SwiftUI
import Testing

/// The guarantee "a chunk changes only the model of its own text block"
/// (plan.md §8, AVK-9.7).
///
/// These tests host a ``ResponseView`` whose Markdown text grows one chunk
/// after the other, as the text of a transcript entry grows, beside a
/// response whose text does not change. The models are in a
/// ``CodeBlockModelCache`` of the environment, so the tests read them.
///
/// The tests do not turn the run loop and do not suspend. Each change of the
/// text has exactly one ``HostedViewHarness/render()`` pass before the test
/// reads the models.
///
/// The tests check the models with and without a transaction modifier that
/// disables animations above the hosted views, as the other hosted tests
/// apply it.
@Suite(.serialized, .hostedSerially) @MainActor struct ResponseStreamingHostedTests {
  /// The text that the streamed response view shows. A test appends each
  /// chunk to it, as the session model appends a chunk to the text of an
  /// entry.
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

  /// A streamed response above a response that does not change.
  struct TwoResponses: View {
    /// The id of the streamed response view.
    let streamedID: String

    /// The id of the response view that does not change.
    let settledID: String

    /// The text of the streamed response.
    let growing: GrowingText

    /// Whether a transaction modifier above the response views disables
    /// animations, as the other hosted tests do.
    let disablesAnimations: Bool

    var body: some View {
      let content = VStack {
        ResponseView(id: streamedID, markdown: growing.text)
        ResponseView(id: settledID, markdown: ResponseStreamingHostedTests.settledText)
      }
      if disablesAnimations {
        content.transaction { $0.disablesAnimations = true }
      } else {
        content
      }
    }
  }

  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 1_200)

  /// The number of paragraphs of the streamed text.
  static let paragraphCount = 8

  /// The text of the response that does not change.
  static let settledText = "This answer does not change."

  /// The chunks of the streamed text. Each paragraph comes in three chunks,
  /// and the first chunk of each paragraph after the first starts a new
  /// paragraph.
  static let chunks: [String] = (0..<paragraphCount).flatMap { index in
    [index == 0 ? "Paragraph" : "\n\nParagraph", " number \(index)", " ends here."]
  }

  /// The check runs with and without a transaction modifier above the
  /// response views. Each case has its own response ids, so the models of the
  /// two cases are apart.
  ///
  /// - Parameter disablesAnimations: Whether the transaction modifier is
  ///   above the response views.
  @Test(arguments: [true, false])
  func eachChunkChangesOnlyTheModelOfItsResponse(disablesAnimations: Bool) throws {
    let suffix = disablesAnimations ? "transaction" : "plain"
    let streamedID = "streamed-\(suffix)"
    let settledID = "settled-\(suffix)"
    let cache = CodeBlockModelCache()
    let growing = GrowingText("")
    let harness = HostedViewHarness(
      TwoResponses(
        streamedID: streamedID, settledID: settledID, growing: growing, disablesAnimations: disablesAnimations
      )
      .environment(\.codeBlockModelCache, cache),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()
    let streamed = try #require(ResponseTextChecks.model(of: streamedID, in: cache))
    let settled = try #require(ResponseTextChecks.model(of: settledID, in: cache))
    let settledVersion = settled.state.version

    for chunk in Self.chunks {
      growing.text += chunk
      harness.render()

      #expect(streamed.text == growing.text)
      #expect(settled.state.version == settledVersion)
    }

    #expect(ResponseTextChecks.model(of: streamedID, in: cache) === streamed)
    #expect(ResponseTextChecks.texts(in: harness) == [growing.text, Self.settledText])
  }
}
