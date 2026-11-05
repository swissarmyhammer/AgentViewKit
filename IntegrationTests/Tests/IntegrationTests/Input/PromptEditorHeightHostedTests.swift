#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import EditorTestSupport
  import SwiftUI
  import Testing

  /// The height of the prompt editor (style.md, "A multiline field fits its
  /// content").
  ///
  /// The editor takes the height of its text, grows as the text grows, and has
  /// no scroll of its own. The composer is its host: it bounds the editor
  /// (`.boundedHeight(_:)` of EditorStyle) and scrolls a longer prompt, so a
  /// long prompt leaves the transcript of the thread in view and the line that
  /// the person types stays in view.
  @Suite(.serialized, .hostedSerially) @MainActor struct PromptEditorHeightHostedTests {
    /// A prompt editor over `session`, with a constant draft: a test changes
    /// the text after the mount through the model of the session.
    ///
    /// - Parameters:
    ///   - session: The model and the completion engine of the editor.
    ///   - text: The first text of the editor.
    /// - Returns: The editor.
    static func editor(_ session: PromptEditorSession, text: String = "") -> EditorKitPromptEditor {
      EditorKitPromptEditor(
        context: PromptEditorContext(text: .constant(AttributedString(text)), placeholder: "", onSubmit: {}),
        session: session)
    }

    /// The height of the window of the editor: taller than a bound the editor
    /// could set itself, and shorter than ``ContentSizedBed/tallText``.
    static let editorWindowHeight: CGFloat = 400

    /// A production change that fails this test: the editor stops at a height
    /// of its own and scrolls its text inside the host.
    @Test func theEditorGrowsWithItsTextAndTheHostScrollsIt() async {
      let session = PromptEditorSession()
      let bed = await ContentSizedBed(Self.editor(session), windowHeight: Self.editorWindowHeight)
      defer { bed.harness.close() }

      session.model.replaceAll(ContentSizedBed.tallText)

      #expect(await bed.growsPastTheWindowAndScrollsAsOne())
    }

    /// A production change that fails this test: the editor keeps a long line
    /// on one row and scrolls it sideways.
    @Test func theEditorWrapsALongLine() async {
      let threeLines = await ContentSizedBed.settledHeight(
        of: Self.editor(PromptEditorSession(), text: ContentSizedBed.threeLines))

      #expect(
        await ContentSizedBed.grows(
          Self.editor(PromptEditorSession(), text: ContentSizedBed.longLine), tallerThan: threeLines))
    }

    /// A production change that fails this test: the composer shows a long
    /// prompt with no bound, so it covers the thread, or scrolls the prompt in
    /// two scroll views.
    @Test func theComposerScrollsALongPromptAsOne() async {
      let draft = PromptInputHostedTestModel(text: ContentSizedBed.tallText)
      let harness = HostedViewHarness(
        PromptInputHost(model: draft), size: EditorKitPromptEditorHostedTests.composerSize)
      defer { harness.close() }
      let hosting = harness.hostingView

      #expect(await settle(until: { hosting.scrollsAsOne }))
    }

    /// A production change that fails this test: the line of the caret leaves
    /// the visible part of the composer as the person types at the end of a
    /// long prompt.
    @Test func theComposerKeepsTheLineOfTheCaretInView() async throws {
      let draft = PromptInputHostedTestModel(text: ContentSizedBed.tallText)
      let harness = HostedViewHarness(
        PromptInputHost(model: draft), size: EditorKitPromptEditorHostedTests.composerSize)
      defer { harness.close() }
      try harness.perform(.focus, on: EditorKitPromptEditor.identifier)

      harness.type(PromptInputViewHostedTests.message)

      let textView = try #require(harness.firstEditableTextView(of: NSTextView.self))
      let hosting = harness.hostingView
      #expect(await settle(until: { textView.isCaretVisible(inHostScrollOf: hosting) }))
    }
  }
#endif
