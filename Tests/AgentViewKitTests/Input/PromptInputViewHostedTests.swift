@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import Foundation
import SwiftUI
import Testing

/// A host view that owns the text of a stock composer.
///
/// The view reads the text from ``PromptInputHostedTestModel``, so that a test
/// can read the text after the composer changes it.
struct PromptInputHost: View {
  /// The model that holds the text.
  @Bindable var model: PromptInputHostedTestModel

  var body: some View {
    PromptInputView(text: $model.text) {
      model.submitCount += 1
    }
  }
}

/// The text of a hosted composer, and a count of the host submit calls.
@Observable final class PromptInputHostedTestModel {
  /// The text of the composer.
  var text: AttributedString

  /// The number of times that the composer called the host `onSubmit`.
  var submitCount = 0

  /// Makes a model.
  ///
  /// - Parameter text: The first text of the composer.
  init(text: String = "") {
    self.text = AttributedString(text)
  }

  /// The text of the composer as a plain string.
  var plainText: String {
    String(text.characters)
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct PromptInputViewHostedTests {
  /// The text that the tests type.
  static let message = "Hello"

  /// The size of a window that shows the full composer.
  static let composerSize = CGSize(width: 480, height: 200)

  /// The `session/new` result with the one command `plan`.
  static let newSessionWithPlan = #"""
    {"sessionId": "\#(ScriptedSession.sessionID)",
     "availableCommands": [{"name": "plan", "description": "Make a plan"}]}
    """#

  /// Shows a composer over the session model of a scripted session.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - model: The model that holds the text of the composer.
  ///   - recorder: The recorder of the submit outcomes that the composer
  ///     reports through ``SwiftUI/EnvironmentValues/promptSubmitReport``,
  ///     or `nil`.
  /// - Returns: The harness.
  static func mount(
    _ session: ScriptedSession, model: PromptInputHostedTestModel,
    recorder: ReportRecorder<PromptSubmitOutcome>? = nil
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: composerSize) {
      PromptInputHost(model: model)
        .environment(\.sessionModel, session.model)
        .environment(\.promptSubmitReport, recorder?.report)
    }
  }

  /// The `session/new` result with a `mode` option, for the picker test.
  static let newSessionWithMode = #"""
    {"sessionId": "\#(ScriptedSession.sessionID)",
     "configOptions": [{"configId": "mode", "name": "Mode", "category": "mode", "type": "select",
                        "currentValue": "ask",
                        "options": [{"value": "ask", "name": "Ask"}, {"value": "auto", "name": "Auto"}]}]}
    """#

  // MARK: - Mount

  @Test func theDefaultComposerMountsTheEditorAndTheSubmitButton() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(size: Self.composerSize) {
      PromptInputView(text: Bindable(PromptInputHostedTestModel(text: Self.message)).text, onSubmit: {})
        .environment(\.sessionModel, session.model)
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: StockPromptEditor.identifier) != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == true)
    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
  }

  @Test func theSubmitButtonIsDisabledWhileTheTextIsBlank() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session, model: PromptInputHostedTestModel(text: "  \n"))
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
  }

  @Test func theSubmitButtonIsDisabledWithNoSessionModel() {
    let harness = HostedViewHarness(PromptInputHost(model: PromptInputHostedTestModel(text: Self.message)), size: Self.composerSize)
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
  }

  @Test func theAccessoryShowsThePermissionModePickerOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open {
      $0.results["session/new"] = Self.newSessionWithMode
    }
    defer { session.close() }
    let harness = Self.mount(session, model: PromptInputHostedTestModel())
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) != nil)
  }

  // MARK: - Glass

  @Test func theSubmitButtonIsOutsideTheGlassOfTheField() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session, model: PromptInputHostedTestModel(text: Self.message))
    defer { harness.close() }
    harness.render()

    let field = try #require(harness.frame(identifier: PromptFieldSurface.identifier))
    let submit = try #require(harness.frame(identifier: DefaultPromptAccessory.submitIdentifier))
    #expect(!field.intersects(submit), "field \(field), submit \(submit)")
  }

  // MARK: - Custom editor

  @Test func aCustomEditorGetsTheContextOfTheComposer() async throws {
    let session = try await ScriptedSession.open {
      $0.results["session/new"] = Self.newSessionWithPlan
    }
    defer { session.close() }
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = HostedViewHarness(size: Self.composerSize) {
      PromptInputView(text: Bindable(model).text, onSubmit: {}) { context in
        Button((context.commands ?? []).map(\.name).joined()) { context.onSubmit() }
          .accessibilityIdentifier("custom-editor")
      }
      .environment(\.sessionModel, session.model)
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: StockPromptEditor.identifier) == nil)
    #expect(harness.element(identifier: "custom-editor")?.label == "plan")
    try harness.press(identifier: "custom-editor")
    // The composer takes the text in the same step as it starts the prompt
    // task, so a press that sent nothing stops the test here.
    try #require(model.plainText.isEmpty)
    await ObservationWait.until { !session.agent.messages(method: ScriptedSession.promptMethod).isEmpty }

    let prompts = session.agent.messages(method: ScriptedSession.promptMethod)
    #expect(prompts.map(ScriptedWireAgent.promptText(of:)) == [Self.message])
    #expect(model.plainText.isEmpty)
  }

  // MARK: - Keys

  @Test func returnSendsTheTextAndClearsTheEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(session, model: model)
    defer { harness.close() }
    harness.render()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try #require(model.plainText == Self.message)
    try harness.sendKey(.return)
    // The composer calls the host closure in the same step as it starts the
    // prompt task, so a key that sent nothing stops the test here.
    try #require(model.submitCount == 1)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let recorder = ReportRecorder<PromptSubmitOutcome>()
    let harness = Self.mount(session, model: model, recorder: recorder)
    defer { harness.close() }
    harness.render()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try harness.sendKey(.return, modifiers: .shift)
    // The editor reports the outcome in the same step as the key.
    try #require(!recorder.values.isEmpty)
    harness.render()

    #expect(recorder.values == [.newline])
    #expect(session.promptTexts.isEmpty)
    #expect(model.plainText == Self.message + "\n")
    #expect(model.submitCount == 0)
  }

  @Test func returnWithBlankTextSendsNothing() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let recorder = ReportRecorder<PromptSubmitOutcome>()
    let harness = Self.mount(session, model: model, recorder: recorder)
    defer { harness.close() }
    harness.render()

    try #require(harness.focusFirstEditableTextView())
    try harness.sendKey(.return)
    try #require(!recorder.values.isEmpty)
    harness.render()

    #expect(recorder.values == [.notSent])
    #expect(session.promptTexts.isEmpty)
    #expect(model.submitCount == 0)
  }

  // MARK: - Submit

  @Test func theSubmitButtonSendsTheText() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = Self.mount(session, model: model)
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    try #require(model.submitCount == 1)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }
}
