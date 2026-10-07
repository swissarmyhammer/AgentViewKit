import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

/// The text view helpers of `HostedViewHarness`: the first editable text view,
/// its focus, and the AppKit views with an accessibility identifier.
@Suite(.serialized, .hostedSerially) @MainActor struct HostedViewHarnessTextViewsTests {
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
