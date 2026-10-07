import AgentViewKit
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

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

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
  /// - Returns: The harness.
  static func mount(_ session: ScriptedSession, model: PromptInputHostedTestModel) -> HostedViewHarness<some View> {
    HostedViewHarness(size: composerSize) {
      PromptInputHost(model: model)
        .environment(\.sessionModel, session.model)
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
    harness.pump()

    #expect(harness.element(identifier: StockPromptEditor.identifier) != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == true)
    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
  }

  @Test func theSubmitButtonIsDisabledWhileTheTextIsBlank() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session, model: PromptInputHostedTestModel(text: "  \n"))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
  }

  @Test func theSubmitButtonIsDisabledWithNoSessionModel() {
    let harness = HostedViewHarness(PromptInputHost(model: PromptInputHostedTestModel(text: Self.message)), size: Self.composerSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
  }

  @Test func theAccessoryShowsThePermissionModePickerOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open {
      $0.results["session/new"] = Self.newSessionWithMode
    }
    defer { session.close() }
    let harness = Self.mount(session, model: PromptInputHostedTestModel())
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) != nil)
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
    harness.pump()

    #expect(harness.element(identifier: StockPromptEditor.identifier) == nil)
    #expect(harness.element(identifier: "custom-editor")?.label == "plan")
    try harness.press(identifier: "custom-editor")
    await harness.pump(until: Self.waitTimeout) { !session.agent.messages(method: ScriptedSession.promptMethod).isEmpty }

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
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    #expect(model.plainText == Self.message)
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(session, model: model)
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    harness.type(Self.message)
    try harness.sendKey(.return, modifiers: .shift)
    harness.pump()

    #expect(session.promptTexts.isEmpty)
    #expect(model.plainText == Self.message + "\n")
    #expect(model.submitCount == 0)
  }

  @Test func returnWithBlankTextSendsNothing() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel()
    let harness = Self.mount(session, model: model)
    defer { harness.close() }
    harness.pump()

    try #require(harness.focusFirstEditableTextView())
    try harness.sendKey(.return)
    harness.pump()

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
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }
}
