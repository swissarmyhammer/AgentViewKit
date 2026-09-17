@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Hosted tests of ``SpeechInputButton`` in the default composer, with a
/// ``FakeSpeechTranscriber``.
@Suite(.serialized, .hostedSerially) @MainActor struct SpeechInputButtonHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// Mounts a stock composer with `transcriber`.
  ///
  /// - Parameters:
  ///   - model: The model that holds the composer text.
  ///   - transcriber: The transcriber of the environment, or `nil`.
  /// - Returns: The harness.
  static func mount(
    _ model: PromptInputHostedTestModel,
    transcriber: FakeSpeechTranscriber?
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(
      size: PromptInputViewHostedTests.composerSize, actions: NoopThreadActions()
    ) {
      PromptInputHost(model: model)
        .speechTranscriber(transcriber)
    }
    harness.pump()
    return harness
  }

  // MARK: - Mount

  @Test func aComposerWithNoTranscriberShowsNoMic() {
    let harness = Self.mount(PromptInputHostedTestModel(), transcriber: nil)
    defer { harness.close() }

    #expect(harness.element(identifier: SpeechInputButton.identifier) == nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }

  @Test func aButtonOutsideAComposerShowsNothing() {
    let harness = HostedViewHarness(
      SpeechInputButton().speechTranscriber(FakeSpeechTranscriber()))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SpeechInputButton.identifier) == nil)
  }

  // MARK: - Dictation

  @Test func theTranscriptGoesIntoTheComposerText() async throws {
    let transcriber = FakeSpeechTranscriber()
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(model, transcriber: transcriber)
    defer { harness.close() }

    #expect(harness.element(identifier: SpeechInputButton.identifier)?.value == "Not recording")
    try harness.press(identifier: SpeechInputButton.identifier)
    await harness.pump(until: Self.waitTimeout) { transcriber.isRunning }
    transcriber.feed(level: 0.5)
    transcriber.feed("hello")
    await harness.pump(until: Self.waitTimeout) { model.plainText == "hello" }

    #expect(model.plainText == "hello")
    #expect(transcriber.calls == [.requestAuthorization, .start])
    #expect(harness.element(identifier: SpeechInputButton.identifier)?.value == "Recording")
    #expect(model.submitCount == 0)
  }

  @Test func aSecondPressStopsTheSessionAndKeepsTheText() async throws {
    let transcriber = FakeSpeechTranscriber()
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(model, transcriber: transcriber)
    defer { harness.close() }

    try harness.press(identifier: SpeechInputButton.identifier)
    await harness.pump(until: Self.waitTimeout) { transcriber.isRunning }
    transcriber.feed("hello there")
    await harness.pump(until: Self.waitTimeout) { model.plainText == "hello there" }
    try harness.press(identifier: SpeechInputButton.identifier)
    harness.pump()
    transcriber.feed("ignored")
    harness.pump()

    #expect(transcriber.calls == [.requestAuthorization, .start, .stop])
    #expect(!transcriber.isRunning)
    #expect(model.plainText == "hello there")
    #expect(harness.element(identifier: SpeechInputButton.identifier)?.value == "Not recording")
  }

  @Test func theTranscriptGoesAfterTheTextOfTheComposer() async throws {
    let transcriber = FakeSpeechTranscriber()
    let model = PromptInputHostedTestModel(text: "Fix")
    let harness = Self.mount(model, transcriber: transcriber)
    defer { harness.close() }

    try harness.press(identifier: SpeechInputButton.identifier)
    await harness.pump(until: Self.waitTimeout) { transcriber.isRunning }
    transcriber.feed("the")
    transcriber.feed("the bug")
    await harness.pump(until: Self.waitTimeout) { model.plainText == "Fix the bug" }

    #expect(model.plainText == "Fix the bug")
  }

  @Test func theEndOfASessionResetsTheButton() async throws {
    let transcriber = FakeSpeechTranscriber()
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(model, transcriber: transcriber)
    defer { harness.close() }

    try harness.press(identifier: SpeechInputButton.identifier)
    await harness.pump(until: Self.waitTimeout) { transcriber.isRunning }
    transcriber.feed("done")
    transcriber.finish()
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SpeechInputButton.identifier)?.value == "Not recording"
    }

    #expect(harness.element(identifier: SpeechInputButton.identifier)?.value == "Not recording")
    #expect(model.plainText == "done")
    #expect(transcriber.calls == [.requestAuthorization, .start])
  }

  @Test func aDeniedPermissionStartsNoSession() async throws {
    let transcriber = FakeSpeechTranscriber(isAuthorized: false)
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(model, transcriber: transcriber)
    defer { harness.close() }

    try harness.press(identifier: SpeechInputButton.identifier)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: SpeechInputButton.identifier)?.value == "Not allowed"
    }

    #expect(harness.element(identifier: SpeechInputButton.identifier)?.value == "Not allowed")
    #expect(transcriber.calls == [.requestAuthorization])
    #expect(model.plainText.isEmpty)
  }

  // MARK: - Text

  @Test(arguments: [
    ("", "hello", "hello"),
    ("Fix", "the bug", "Fix the bug"),
    ("Fix ", "the bug", "Fix the bug"),
    ("Line\n", "next", "Line\nnext"),
  ])
  func theTranscriptJoinsTheStartText(base: String, transcript: String, expected: String) {
    let text = SpeechInputButton.transcribedText(
      base: AttributedString(base), transcript: transcript)

    #expect(String(text.characters) == expected)
  }

  @Test func theStartTextKeepsItsLinks() throws {
    let file = URL(fileURLWithPath: "/tmp/notes.md")
    var base = AttributedString("notes.md")
    base.link = file
    let text = SpeechInputButton.transcribedText(base: base, transcript: "summarize")

    #expect(String(text.characters) == "notes.md summarize")
    #expect(text.runs.compactMap(\.link) == [file])
  }
}
