import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTestSupport
import Foundation
import SwiftUI
import Testing

@testable import AgentViewKit

/// Hosted tests of ``ResponseView``: the text of an answer in the rendered
/// form of EditorKit (AVK-9.7, D185).
@Suite(.serialized, .hostedSerially) @MainActor struct ResponseViewHostedTests {
  /// The size of the host window. It is tall enough for each paragraph.
  static let hostSize = CGSize(width: 480, height: 640)

  /// A text with four paragraphs.
  static let fourParagraphText = "One.\n\nTwo.\n\nThree.\n\nFour"

  /// A text with a fenced code block.
  static let fencedText = "Some code:\n\n```swift\nlet x = 1\n```"

  // MARK: - Elements

  @Test func aTextWithFourParagraphsIsOneTextElement() {
    let harness = HostedViewHarness(
      ResponseView(id: "response-four", markdown: Self.fourParagraphText), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(ResponseTextChecks.texts(in: harness) == [Self.fourParagraphText])
  }

  /// A production change that fails this test: the response shows the
  /// fence in its Markdown editor, and not in a code block view (task
  /// ^4g2xbx1).
  @Test func aFencedBlockShowsInACodeBlockViewAfterItsProse() {
    let harness = HostedViewHarness(
      ResponseView(id: "response-fence", markdown: Self.fencedText), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(ResponseTextChecks.texts(in: harness) == ["Some code:"])
    #expect(harness.element(identifier: CodeBlockView.identifier) != nil)
  }

  @Test func twoResponsesShowTwoTextElements() {
    let harness = HostedViewHarness(
      VStack {
        ResponseView(id: "response-first", markdown: "First.")
        ResponseView(id: "response-second", markdown: "Second.")
      },
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(ResponseTextChecks.texts(in: harness) == ["First.", "Second."])
  }

  // MARK: - Models

  @Test func theModelOfAResponseIsInTheCacheOfTheEnvironment() throws {
    let cache = CodeBlockModelCache()
    let harness = HostedViewHarness(
      ResponseView(id: "response-cached", markdown: "Cached.").environment(
        \.codeBlockModelCache, cache),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    let model = try #require(ResponseTextChecks.model(of: "response-cached", in: cache))
    #expect(model.text == "Cached.")
    #expect(model.presentation == .rendered)
  }

  @Test func aCachedModelWithAnOlderTextGetsTheTextOfTheView() throws {
    let cache = CodeBlockModelCache()
    let model = ResponseView.model(in: cache, id: "response-older", markdown: "Old")
    let harness = HostedViewHarness(
      ResponseView(id: "response-older", markdown: "Old and new.").environment(
        \.codeBlockModelCache, cache),
      size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    #expect(model.text == "Old and new.")
    #expect(ResponseTextChecks.texts(in: harness) == ["Old and new."])
  }
}
