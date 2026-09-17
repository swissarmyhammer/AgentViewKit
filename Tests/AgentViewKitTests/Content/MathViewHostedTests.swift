import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``MathView`` and of the math spans in ``ResponseView``.
@Suite(.serialized, .hostedSerially) @MainActor struct MathViewHostedTests {
  /// The size of the host window. It is large enough for each expression.
  static let hostSize = CGSize(width: 480, height: 320)

  /// An inline expression, with no dollar signs.
  static let inlineSource = "E = mc^2"

  /// A block expression, with no dollar signs.
  static let blockSource = #"\int_0^1 x\,dx"#

  /// An expression that the engine cannot parse: the command does not exist.
  static let malformedSource = #"\nosuchcommand{x}"#

  /// The number of elements in `harness` that have `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier to count.
  ///   - harness: The harness that hosts the view.
  /// - Returns: The number of elements.
  static func count(
    _ identifier: String, in harness: HostedViewHarness<some View>
  ) -> Int {
    harness.accessibilityElements().filter { $0.identifier == identifier }.count
  }

  /// Mounts a response with one text block that does not stream.
  ///
  /// - Parameters:
  ///   - id: The id of the message.
  ///   - text: The Markdown text of the message.
  /// - Returns: The harness that hosts the response.
  static func mountResponse(id: String, text: String) -> HostedViewHarness<ResponseView> {
    let message = Message(id: id, blocks: [ContentBlock(text: text)])
    let harness = HostedViewHarness(
      ResponseView(message: message, streaming: nil), size: hostSize)
    harness.pump()
    return harness
  }

  // MARK: - MathView

  @Test func inlineMathMountsAnInlineElementLabeledWithTheSource() {
    let harness = HostedViewHarness(
      MathView(latex: Self.inlineSource, display: false), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: MathView.inlineIdentifier)
    #expect(element?.label == Self.inlineSource)
    #expect(harness.element(identifier: MathView.blockIdentifier) == nil)
  }

  @Test func blockMathMountsABlockElementLabeledWithTheSource() {
    let harness = HostedViewHarness(
      MathView(latex: Self.blockSource, display: true), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: MathView.blockIdentifier)
    #expect(element?.label == Self.blockSource)
    #expect(harness.element(identifier: MathView.inlineIdentifier) == nil)
  }

  @Test(arguments: [false, true])
  func malformedMathMountsAnElementWhoseValueIsTheSource(display: Bool) {
    let harness = HostedViewHarness(
      MathView(latex: Self.malformedSource, display: display), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: MathView.identifier(display: display))
    #expect(element?.value == Self.malformedSource)
    #expect(element?.label == Self.malformedSource)
  }

  @Test func theEngineTypesetsOnlyValidSource() {
    #expect(MathView.canTypeset(Self.inlineSource, display: false))
    #expect(MathView.canTypeset(Self.blockSource, display: true))
    #expect(!MathView.canTypeset(Self.malformedSource, display: false))
    #expect(!MathView.canTypeset("", display: false))
  }

  @Test func theIdentifierFollowsTheDisplayStyle() {
    #expect(MathView.identifier(display: false) == "math-inline")
    #expect(MathView.identifier(display: true) == "math-block")
  }

  // MARK: - ResponseView

  @Test func inlineMathInAParagraphMountsOneInlineElement() {
    let harness = Self.mountResponse(
      id: "math-paragraph-inline", text: "The energy is $\(Self.inlineSource)$ here.")
    defer { harness.close() }

    #expect(Self.count(MathView.inlineIdentifier, in: harness) == 1)
    #expect(Self.count(MathView.blockIdentifier, in: harness) == 0)
    #expect(harness.element(identifier: MathView.inlineIdentifier)?.label == Self.inlineSource)
    #expect(harness.element(identifier: ResponseView.paragraphIdentifier(index: 0)) != nil)
  }

  @Test func blockMathInAParagraphMountsOneBlockElement() {
    let harness = Self.mountResponse(
      id: "math-paragraph-block", text: "$$\(Self.blockSource)$$")
    defer { harness.close() }

    #expect(Self.count(MathView.blockIdentifier, in: harness) == 1)
    #expect(Self.count(MathView.inlineIdentifier, in: harness) == 0)
    #expect(harness.element(identifier: MathView.blockIdentifier)?.label == Self.blockSource)
  }

  @Test func aParagraphWithNoMathMountsNoMathElement() {
    let harness = Self.mountResponse(id: "math-paragraph-none", text: "It costs 5 dollars.")
    defer { harness.close() }

    #expect(Self.count(MathView.inlineIdentifier, in: harness) == 0)
    #expect(Self.count(MathView.blockIdentifier, in: harness) == 0)
  }

  @Test func malformedMathInAParagraphShowsTheSource() {
    let harness = Self.mountResponse(
      id: "math-paragraph-malformed", text: "Bad $\(Self.malformedSource)$ math.")
    defer { harness.close() }

    #expect(Self.count(MathView.inlineIdentifier, in: harness) == 0)
    let texts = harness.accessibilityElements().compactMap { $0.value ?? $0.label }
    #expect(texts.contains { $0.contains(Self.malformedSource) })
  }

  @Test func inlineMathInTheStreamingTailMountsOneInlineElement() {
    let id = "math-tail-inline"
    let streaming = StreamingMessage(id: id, text: "The energy is $\(Self.inlineSource)$ so far")
    let harness = HostedViewHarness(
      ResponseView(message: Message(id: id, blocks: []), streaming: streaming),
      size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ResponseView.tailIdentifier) != nil)
    #expect(Self.count(MathView.inlineIdentifier, in: harness) == 1)
  }
}
