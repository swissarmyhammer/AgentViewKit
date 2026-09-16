import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

/// A view that shows whether its environment has a thread, and has a button
/// that calls the cancel verb of its actions.
private struct EnvironmentProbeView: View {
  @Environment(\.agentThread) private var thread
  @Environment(\.threadActions) private var actions

  var body: some View {
    VStack {
      Text(thread == nil ? "no thread" : "thread")
        .accessibilityIdentifier("probe-thread")
      Button("Cancel") {
        let actions = actions
        Task { await actions.cancel() }
      }
      .accessibilityIdentifier("probe-cancel")
    }
  }
}

@Suite(.serialized) @MainActor struct ThreadViewHarnessTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  @Test func theHarnessGivesTheActionsAndTheThreadToTheView() async throws {
    let actions = NoopThreadActions()
    let harness = threadViewHarness(actions: actions, thread: AgentThread()) {
      EnvironmentProbeView()
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "probe-thread")?.label == "thread")
    try harness.press(identifier: "probe-cancel")
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }
    #expect(actions.calls == [.cancel])
  }

  @Test func theHarnessHasNoThreadByDefault() {
    let harness = threadViewHarness(actions: NoopThreadActions()) {
      EnvironmentProbeView()
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: "probe-thread")?.label == "no thread")
  }

  @Test func theHarnessUsesTheSize() {
    let size = CGSize(width: 300, height: 100)
    let harness = threadViewHarness(size: size, actions: NoopThreadActions()) {
      EnvironmentProbeView()
    }
    defer { harness.close() }

    #expect(harness.hostingView.frame.size == size)
  }

  @Test func aViewWithNoTextInputHasNoEditableTextView() {
    let harness = HostedViewHarness(Text("Label"))
    defer { harness.close() }
    harness.pump()

    #expect(harness.firstEditableTextView() == nil)
    #expect(harness.focusFirstEditableTextView() == false)
  }

  @Test func aTextFieldIsAnEditableTextView() {
    let harness = HostedViewHarness(TextField("Name", text: .constant("")))
    defer { harness.close() }
    harness.pump()

    #expect(harness.firstEditableTextView() is NSTextField)
    #expect(harness.focusFirstEditableTextView())
  }

  @Test func aTextEditorIsAnEditableTextView() {
    let harness = HostedViewHarness(TextEditor(text: .constant("")))
    defer { harness.close() }
    harness.pump()

    #expect(harness.firstEditableTextView() is NSTextView)
    #expect(harness.focusFirstEditableTextView())
  }

  @Test func theTypeFilterSkipsATextViewBeforeTheTextField() {
    let harness = HostedViewHarness(
      VStack {
        TextEditor(text: .constant(""))
        TextField("Name", text: .constant(""))
      })
    defer { harness.close() }
    harness.pump()

    #expect(harness.firstEditableTextView() is NSTextView)
    #expect(harness.firstEditableTextView(of: NSTextField.self) != nil)
    #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
  }

  @Test func aReadOnlyTextViewIsNotEditable() {
    let harness = HostedViewHarness(Text("Label"))
    defer { harness.close() }
    let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 100, height: 20))
    textView.isEditable = false
    harness.hostingView.addSubview(textView)

    #expect(harness.firstEditableTextView() == nil)
  }
}
