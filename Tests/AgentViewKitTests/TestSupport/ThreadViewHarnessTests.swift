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
        guard let actions else { return }
        Task { await actions.cancel() }
      }
      .accessibilityIdentifier("probe-cancel")
    }
  }
}

@Suite(.serialized, .hostedSerially) @MainActor struct ThreadViewHarnessTests {
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

  @Test func viewsWithAnIdentifierFindsEachNestedAppKitView() {
    let harness = HostedViewHarness(Text("Label"))
    defer { harness.close() }
    let outer = NSView(frame: NSRect(x: 0, y: 0, width: 100, height: 40))
    outer.setAccessibilityIdentifier("marked")
    let inner = NSView(frame: NSRect(x: 0, y: 0, width: 50, height: 20))
    inner.setAccessibilityIdentifier("marked")
    let other = NSView(frame: NSRect(x: 0, y: 20, width: 50, height: 20))
    other.setAccessibilityIdentifier("other")
    outer.addSubview(inner)
    outer.addSubview(other)
    harness.hostingView.addSubview(outer)

    #expect(harness.views(withAccessibilityIdentifier: "marked") == [outer, inner])
    #expect(harness.views(withAccessibilityIdentifier: "other") == [other])
    #expect(harness.views(withAccessibilityIdentifier: "missing").isEmpty)
  }
}
