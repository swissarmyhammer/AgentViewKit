@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import SwiftUI
import Testing

/// A thread view of a scripted session whose composer slot holds a
/// ``DefaultThreadComposer`` in a command scope of the host, as TestudoApp
/// mounts it.
struct ScopedDefaultComposerThreadHost: View {
  /// The segment of the command scope that the host puts around the composer.
  static let composerSegment = FocusSegment(kind: "composer")

  /// The scripted session of the thread.
  let session: ScriptedSession

  var body: some View {
    AgentThreadView(session: session.model, connection: session.connection) {
      DefaultThreadComposer()
        .commandScope(segment: Self.composerSegment)
    }
  }
}

/// Tests for ``DefaultThreadComposer``: the editor of the composer is the
/// EditorKit editor (``EditorKitPromptEditor``), it carries the
/// `prompt-editor` identifier that a UI test types into, and a focus that
/// lands on a command scope of the host around the composer goes into the
/// text view of the editor.
@Suite(.serialized, .hostedSerially) @MainActor struct DefaultThreadComposerHostedTests {
  /// The accessibility role of an editable multiline text view.
  static let textAreaRole = NSAccessibility.Role.textArea.rawValue

  /// The element with the `prompt-editor` identifier is the text area of the
  /// EditorKit editor: the editable text view, the element that takes typing.
  ///
  /// The test reads `isEditable` on the text view, not the accessibility
  /// enabled state: AppKit reports an `NSTextView` as not enabled to
  /// accessibility, even an editable one.
  @Test func theEditorThatTakesTypingCarriesThePromptEditorIdentifier() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(size: ComposerHarness.windowSize) {
      DefaultThreadComposer()
        .environment(\.sessionModel, session.model)
    }
    defer { harness.close() }
    harness.render()

    let editor = try #require(harness.element(identifier: EditorKitPromptEditor.identifier))
    let textView = try #require(harness.firstEditableTextView(of: NSTextView.self))

    #expect(EditorKitPromptEditor.identifier == "prompt-editor")
    #expect(editor.role == Self.textAreaRole)
    #expect(textView.accessibilityIdentifier() == EditorKitPromptEditor.identifier)
    #expect(harness.views(withAccessibilityIdentifier: EditorKitPromptEditor.identifier) == [textView])
  }

  /// A `nav.*` move or a jump that lands on the command scope of the host
  /// around the composer makes the text view of the editor the first
  /// responder. In a host scope, the editor yields its own control scope to
  /// the host scope, so the focus does not stop at an inner scope.
  @Test(arguments: AgentItemFocusRingHostedTests.FocusLanding.allCases)
  func aFocusOnTheHostScopeOfTheComposerGoesIntoTheTextOfTheEditor(
    landing: AgentItemFocusRingHostedTests.FocusLanding
  ) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let thread = try ComposerHarness.mountThread(of: session.model) {
      ScopedDefaultComposerThreadHost(session: session)
        .environment(\.sessionModel, session.model)
    }
    defer { thread.harness.close() }
    let composer = thread.path.appending(ScopedDefaultComposerThreadHost.composerSegment)

    try AgentItemFocusRingHostedTests.land(on: composer, in: thread.path, system: thread.system, by: landing)
    thread.harness.render()

    let editor = try #require(thread.harness.firstEditableTextView(of: NSTextView.self))
    #expect(thread.harness.window.firstResponder === editor)
  }
}
