import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

/// A host view that owns the text of a stock composer.
///
/// The view reads the text from ``PromptInputHostedTestModel``, so that a test
/// can read the text after the composer changes it.
private struct PromptInputHost: View {
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

@Suite(.serialized) @MainActor struct PromptInputViewHostedTests {
  /// The text that the tests type.
  static let message = "Hello"

  /// The size of a window that shows the full composer.
  static let composerSize = CGSize(width: 480, height: 200)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The `mode` option of the thread in the picker test.
  static let modeOption = ConfigOption(
    id: ConfigOptionID("mode"), name: "Mode", category: .mode,
    kind: .select(
      current: "ask",
      choices: .flat([
        SelectOption(id: "ask", name: "Ask"), SelectOption(id: "auto", name: "Auto"),
      ])))

  /// A harness that shows `content` with `actions` and `thread`.
  ///
  /// - Parameters:
  ///   - actions: The actions that the composer calls.
  ///   - thread: The thread of the environment, or `nil`.
  ///   - content: The composer.
  /// - Returns: The harness.
  static func harness(
    actions: NoopThreadActions, thread: AgentThread? = nil,
    @ViewBuilder content: () -> some View
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(
      content()
        .threadActions(actions)
        .environment(\.agentThread, thread)
        .transaction { $0.disablesAnimations = true },
      size: composerSize
    )
  }

  /// The first editable text view under `view`.
  ///
  /// - Parameter view: The view to search.
  /// - Returns: The text view, or `nil`.
  static func firstTextView(in view: NSView) -> NSTextView? {
    for subview in view.subviews {
      if let textView = subview as? NSTextView, textView.isEditable {
        return textView
      }
      if let textView = firstTextView(in: subview) {
        return textView
      }
    }
    return nil
  }

  /// Gives the focus to the stock editor of `harness`.
  ///
  /// - Parameter harness: The harness.
  /// - Throws: An error when the harness has no editable text view.
  static func focusEditor(of harness: HostedViewHarness<some View>) throws {
    let textView = try #require(firstTextView(in: harness.hostingView))
    harness.window.makeFirstResponder(textView)
    harness.pump()
  }

  // MARK: - Mount

  @Test func theDefaultComposerMountsTheEditorAndTheSubmitButton() {
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: NoopThreadActions()) {
      PromptInputView(text: Bindable(model).text, onSubmit: {})
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: StockPromptEditor.identifier) != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
  }

  @Test func theSubmitButtonIsDisabledWhileTheTextIsBlank() {
    let model = PromptInputHostedTestModel(text: "  \n")
    let harness = Self.harness(actions: NoopThreadActions()) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier)?.isEnabled == false)
  }

  @Test func theAccessoryShowsThePermissionModePickerOfTheThread() {
    let thread = AgentThread()
    thread.apply(.setConfigOptions([Self.modeOption]))
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: NoopThreadActions(), thread: thread) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: PermissionModePicker.pickerIdentifier) != nil)
  }

  // MARK: - Custom editor

  @Test func aCustomEditorGetsTheContextOfTheComposer() async throws {
    let thread = AgentThread()
    let command = SlashCommand(name: "plan", description: "Make a plan")
    thread.apply(.setAvailableCommands([command]))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = Self.harness(actions: actions, thread: thread) {
      PromptInputView(text: Bindable(model).text, onSubmit: {}) { context in
        Button(context.commands.map(\.name).joined()) { context.onSubmit() }
          .accessibilityIdentifier("custom-editor")
      }
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: StockPromptEditor.identifier) == nil)
    #expect(harness.element(identifier: "custom-editor")?.label == "plan")
    try harness.press(identifier: "custom-editor")
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
  }

  // MARK: - Keys

  @Test func returnSendsTheTextAndClearsTheEditor() async throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: actions) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try Self.focusEditor(of: harness)
    harness.type(Self.message)
    #expect(model.plainText == Self.message)
    try harness.sendKey(.return)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func shiftReturnInsertsANewlineAndDoesNotSend() async throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: actions) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try Self.focusEditor(of: harness)
    harness.type(Self.message)
    try harness.sendKey(.return, modifiers: .shift)
    harness.pump()

    #expect(actions.calls.isEmpty)
    #expect(model.plainText == Self.message + "\n")
    #expect(model.submitCount == 0)
  }

  @Test func returnWithBlankTextSendsNothing() throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: actions) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try Self.focusEditor(of: harness)
    try harness.sendKey(.return)
    harness.pump()

    #expect(actions.calls.isEmpty)
    #expect(model.submitCount == 0)
  }

  // MARK: - Submit and stop

  @Test func theSubmitButtonSendsTheText() async throws {
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = Self.harness(actions: actions) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.plainText.isEmpty)
    #expect(model.submitCount == 1)
  }

  @Test func whileTheThreadRunsTheStopButtonCallsCancel() async throws {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = Self.harness(actions: actions, thread: thread) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) == nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) != nil)
    try harness.press(identifier: DefaultPromptAccessory.stopIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.cancel])
    #expect(model.plainText == Self.message)
  }

  @Test func returnWhileTheThreadRunsSendsNothing() throws {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: actions, thread: thread) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    try Self.focusEditor(of: harness)
    harness.type(Self.message)
    try harness.sendKey(.return)
    harness.pump()

    #expect(actions.calls.isEmpty)
    #expect(model.plainText == Self.message)
  }

  @Test func theStopButtonGoesBackToSubmitWhenTheTurnEnds() {
    let thread = AgentThread()
    thread.apply(.setState(.running))
    let model = PromptInputHostedTestModel()
    let harness = Self.harness(actions: NoopThreadActions(), thread: thread) {
      PromptInputHost(model: model)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) != nil)
    thread.apply(.setState(.idle(nil)))
    harness.pump()

    #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
    #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
  }
}
