@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorComplete
import SwiftUI
import Testing

/// A host view that shows a composer with an EditorKit editor over a
/// session that the test holds.
///
/// The test reads the model of the session, so that it can wait for the
/// rows of the completion list. The rows land after the debounce of the
/// completion engine, and the model is the observable value that holds them.
struct EditorKitSessionPromptInputHost: View {
  /// The model that holds the text.
  @Bindable var model: PromptInputHostedTestModel

  /// The model and the completion engine of the editor.
  let editorSession: PromptEditorSession

  var body: some View {
    PromptInputView(
      text: $model.text, onSubmit: { model.submitCount += 1 },
      editor: { EditorKitPromptEditor(context: $0, session: editorSession) })
  }
}

/// The menu of the EditorKit editor of the composer: the completion list
/// and the "no commands" note (D110 (c)).
///
/// The menu is a sibling glass of the field in the `GlassEffectContainer`
/// of the composer, and it is above the field. So it is not glass on glass.
/// The editor keeps the focus, and the arrow keys and Return act on the
/// list.
@Suite(.serialized, .hostedSerially) @MainActor struct ComposerEditorMenuHostedTests {
  /// The number of the commands of
  /// ``EditorKitPromptEditorHostedTests/commandsUpdate``.
  static let commandCount = 2

  /// Mounts a composer with the EditorKit editor over the session model of a
  /// scripted session, waits until the model has the commands, and focuses
  /// the editor.
  ///
  /// - Parameters:
  ///   - draft: The model that holds the text of the composer.
  ///   - editorSession: The session of the editor.
  ///   - session: The scripted session.
  ///   - commandsUpdate: The `available_commands_update` to send.
  /// - Returns: The harness.
  /// - Throws: The error of the transport, or an error when the editor
  ///   cannot get the focus.
  static func mount(
    _ draft: PromptInputHostedTestModel, editorSession: PromptEditorSession, session: ScriptedSession,
    commandsUpdate: String
  ) async throws -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: EditorKitPromptEditorHostedTests.composerSize) {
      EditorKitSessionPromptInputHost(model: draft, editorSession: editorSession)
        .environment(\.sessionModel, session.model)
    }
    let model = session.model
    try await session.sendUpdate(commandsUpdate)
    await harness.render { model.availableCommands != nil }
    try #require(harness.focusFirstEditableTextView())
    return harness
  }

  /// Types a slash and waits until the composer has the text.
  ///
  /// - Parameters:
  ///   - draft: The model that holds the text of the composer.
  ///   - harness: The harness of the composer.
  static func typeSlash(_ draft: PromptInputHostedTestModel, in harness: HostedViewHarness<some View>) async throws {
    harness.type(SlashCommandSource.trigger)
    try harness.requireTextViewShows(SlashCommandSource.trigger)
    await harness.render { draft.plainText == SlashCommandSource.trigger }
  }

  /// The completion session of the editor.
  ///
  /// - Parameter editorSession: The session of the editor.
  /// - Returns: The completion session state of its model.
  static func completion(of editorSession: PromptEditorSession) -> CompletionSessionState {
    editorSession.model.state.value(CompletionSessionField.self)
  }

  /// Waits until the editor shows the "no commands" note, and renders, so
  /// that the note is in the accessibility tree with its frame.
  ///
  /// ``typeSlash(_:in:)`` waits for the text of the draft, and the text says
  /// nothing about the menu. The note comes from the completion session of
  /// the editor, so the wait reads that observable value: a session open on
  /// the slash with no row.
  ///
  /// - Parameters:
  ///   - editorSession: The session of the editor.
  ///   - harness: The harness of the composer.
  static func renderNoCommandsNote(of editorSession: PromptEditorSession, in harness: HostedViewHarness<some View>) async {
    await harness.render {
      let completion = Self.completion(of: editorSession)
      return completion.isOpen && completion.listedItems.isEmpty && completion.prefix == SlashCommandSource.trigger
    }
  }

  @Test func theCompletionListIsAboveTheGlassOfTheField() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let editorSession = PromptEditorSession()
    let harness = try await Self.mount(
      draft, editorSession: editorSession, session: session,
      commandsUpdate: EditorKitPromptEditorHostedTests.commandsUpdate)
    defer { harness.close() }

    try await Self.typeSlash(draft, in: harness)
    await harness.render { Self.completion(of: editorSession).listedItems.count == Self.commandCount }

    let list = try #require(harness.frame(identifier: EditorKitPromptEditor.completionListIdentifier))
    let field = try #require(harness.frame(identifier: PromptFieldSurface.identifier))
    #expect(!list.intersects(field), "list \(list), field \(field)")
    #expect(list.minY > field.maxY, "list \(list), field \(field)")
  }

  @Test func downAndReturnAcceptTheSecondItemOfTheList() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let editorSession = PromptEditorSession()
    let harness = try await Self.mount(
      draft, editorSession: editorSession, session: session,
      commandsUpdate: EditorKitPromptEditorHostedTests.commandsUpdate)
    defer { harness.close() }
    try await Self.typeSlash(draft, in: harness)
    await harness.render { Self.completion(of: editorSession).listedItems.count == Self.commandCount }
    let second = Self.completion(of: editorSession).listedItems[1].label

    try harness.sendKey(.downArrow)
    // The editor moves the selection in the same step as the key, so a key
    // that moved nothing stops the test here.
    try #require(Self.completion(of: editorSession).listedSelectedIndex == 1)
    try harness.sendKey(.return)
    let accepted = second + " "
    try #require(editorSession.model.text == accepted)
    await harness.render { draft.plainText == accepted }

    #expect(draft.plainText == accepted)
    #expect(session.promptTexts.isEmpty)
  }

  @Test func theNoCommandsNoteIsAboveTheGlassOfTheField() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let editorSession = PromptEditorSession()
    let harness = try await Self.mount(
      draft, editorSession: editorSession, session: session,
      commandsUpdate: SlashCommandSessionModelTests.emptyCommandsUpdate)
    defer { harness.close() }

    try await Self.typeSlash(draft, in: harness)
    await Self.renderNoCommandsNote(of: editorSession, in: harness)

    let note = try #require(harness.frame(identifier: EditorKitPromptEditor.noCommandsIdentifier))
    let field = try #require(harness.frame(identifier: PromptFieldSurface.identifier))
    #expect(!note.intersects(field), "note \(note), field \(field)")
    #expect(note.minY > field.maxY, "note \(note), field \(field)")
  }
}
