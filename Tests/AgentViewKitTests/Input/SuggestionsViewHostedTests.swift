import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``SuggestionsView`` in the default composer.
@Suite(.serialized, .hostedSerially) @MainActor struct SuggestionsViewHostedTests {
  /// The suggestions of the tests.
  static let suggestions = ["Explain this code", "Write the tests"]

  /// Mounts a stock composer with `suggestions`.
  ///
  /// - Parameters:
  ///   - model: The model that holds the composer text.
  ///   - suggestions: The suggestions of the environment.
  ///   - thread: The thread of the environment, or `nil`.
  /// - Returns: The harness.
  static func mount(
    _ model: PromptInputHostedTestModel,
    suggestions: [String] = Self.suggestions,
    thread: AgentThread? = nil
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(
      size: PromptInputViewHostedTests.composerSize, actions: NoopThreadActions(), thread: thread
    ) {
      PromptInputHost(model: model)
        .promptSuggestions(suggestions)
    }
    harness.pump()
    return harness
  }

  @Test func eachSuggestionShowsAsAChipWithItsText() {
    let harness = Self.mount(PromptInputHostedTestModel())
    defer { harness.close() }

    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 0))?.label == "Explain this code")
    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 1))?.label == "Write the tests")
  }

  @Test func aTapOnASuggestionSetsTheComposerText() throws {
    let model = PromptInputHostedTestModel(text: "Old text")
    let harness = Self.mount(model)
    defer { harness.close() }

    try harness.press(identifier: SuggestionsView.chipIdentifier(at: 1))
    harness.pump()

    #expect(model.plainText == "Write the tests")
    #expect(model.submitCount == 0)
  }

  @Test func anEmptyListShowsNoChip() {
    let harness = Self.mount(PromptInputHostedTestModel(), suggestions: [])
    defer { harness.close() }

    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 0)) == nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }

  @Test func whileTheThreadRunsTheSuggestionsAreHidden() {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let harness = Self.mount(PromptInputHostedTestModel(), thread: thread)
    defer { harness.close() }

    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 0)) == nil)
    thread.apply(.setState(.idle(nil)))
    harness.pump()

    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 0)) != nil)
  }

  @Test func aViewOutsideAComposerShowsNoChip() {
    let harness = HostedViewHarness(SuggestionsView(suggestions: Self.suggestions))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SuggestionsView.chipIdentifier(at: 0)) == nil)
  }
}
