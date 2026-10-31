@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The slash command menu of the composer over a `SessionModel` (plan.md
/// §3.2 "Last-value state", §3.7 `Commands "not reported"`).
///
/// The scripted agent sets the commands of the model in one of three states:
/// not reported, reported empty, and reported in the `session/new` response.
/// The test of the empty state shows a composer with the EditorKit editor:
/// the "no commands" note needs no completion query, so the hosted check
/// waits for no debounce. The tests of the other two states give the
/// commands of the model to the completion engine of the editor and await
/// its query, because the query of the hosted editor waits for the debounce
/// of EditorKit on a clock. The hosted completion-row checks can come back
/// when EditorKit ^c3ya9ed gives an injectable debounce clock.
@Suite(.serialized, .hostedSerially) @MainActor struct SlashCommandSessionModelTests {
  /// A size that shows the composer and the menu above it.
  static let size = CGSize(width: 480, height: 400)

  /// The `session/new` result with two commands.
  static let newSessionWithCommands = #"""
    {"sessionId": "\#(ScriptedSession.sessionID)",
     "availableCommands": [
       {"name": "compact", "description": "Compact the thread",
        "input": {"type": "text", "hint": "instructions"}},
       {"name": "plan", "description": "Make a plan"}]}
    """#

  /// An `available_commands_update` with no command.
  static let emptyCommandsUpdate = #"{"sessionUpdate":"available_commands_update","availableCommands":[]}"#

  /// The `messageId` of the agent message that marks the end of the frames
  /// that a test sent.
  static let markerMessageID = "commands-marker"

  /// An `agent_message_chunk` value. The agent sends it after the frames of
  /// a test, so that the test knows that the client read those frames.
  static let markerUpdate =
    #"{"sessionUpdate":"agent_message_chunk","messageId":"\#(markerMessageID)","content":{"type":"text","text":"Done."}}"#

  /// Shows a composer with the EditorKit editor over a session, and focuses
  /// the editor.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - draft: The model that holds the text of the composer.
  ///   - editorSession: The session of the editor, which the test reads to
  ///     wait for the menu.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, draft: PromptInputHostedTestModel, editorSession: PromptEditorSession
  ) throws -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      EditorKitSessionPromptInputHost(model: draft, editorSession: editorSession)
        .environment(\.sessionModel, session.model)
    }
    harness.render()
    try #require(harness.focusFirstEditableTextView())
    return harness
  }

  /// The labels of the rows of the completion list.
  ///
  /// - Parameter harness: The harness of the composer.
  /// - Returns: The labels, in order.
  static func completionLabels(in harness: HostedViewHarness<some View>) -> [String] {
    harness.accessibilityElements()
      .filter { $0.identifier == EditorKitPromptEditor.completionRowIdentifier }
      .compactMap(\.label)
  }

  /// The label of the "no commands" note, or `nil` when the menu shows no
  /// note.
  ///
  /// - Parameter harness: The harness of the composer.
  /// - Returns: The label of the note.
  static func noteLabel(in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: EditorKitPromptEditor.noCommandsIdentifier)?.label
  }

  /// While the agent did not report its commands, a slash is no trigger, and
  /// the engine of the editor lists nothing for it.
  ///
  /// The test calls the completion engine of the editor directly, as the
  /// tests of `EditorKitPromptEditorHostedTests` do. A hosted check of the
  /// rows can come back when EditorKit ^c3ya9ed gives an injectable debounce
  /// clock.
  @Test func withCommandsNotReportedTheEditorEngineListsNothingForASlash() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    try await session.sendUpdate(Self.markerUpdate)
    await ObservationWait.until { !model.transcript.isEmpty }

    #expect(model.availableCommands == nil)
    #expect(!EditorKitPromptEditor.isTrigger("/", reportsCommands: model.availableCommands != nil, hasRoot: false))
    #expect(await CompletionFixture.editor("/", commands: model.availableCommands, root: nil).query().isEmpty)
  }

  @Test func afterAnEmptyCommandsUpdateASlashShowsTheNoCommandsNote() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let editorSession = PromptEditorSession()
    let harness = try Self.mount(session: session, draft: draft, editorSession: editorSession)
    defer { harness.close() }
    let model = session.model
    try await session.sendUpdate(Self.emptyCommandsUpdate)
    await harness.render { model.availableCommands != nil }

    harness.type("/")
    try harness.requireTextViewShows("/")
    await harness.render { draft.plainText == "/" }
    await ComposerEditorMenuHostedTests.renderNoCommandsNote(of: editorSession, in: harness)

    #expect(model.availableCommands?.isEmpty == true)
    #expect(Self.noteLabel(in: harness) == EditorKitPromptEditor.noCommandsNote)
    #expect(Self.completionLabels(in: harness).isEmpty)
  }

  /// The commands of the `session/new` response reach the session model with
  /// no `available_commands_update`, and the engine of the editor lists them
  /// for a slash.
  ///
  /// The test calls the completion engine of the editor directly, as the
  /// tests of `EditorKitPromptEditorHostedTests` do. A hosted check of the
  /// rows can come back when EditorKit ^c3ya9ed gives an injectable debounce
  /// clock.
  @Test func theCommandsOfTheNewSessionResponseGoToTheEditorEngineWithNoUpdate() async throws {
    let session = try await ScriptedSession.open {
      $0.results["session/new"] = Self.newSessionWithCommands
    }
    defer { session.close() }
    let commands = session.model.availableCommands

    #expect(commands?.map(\.name) == ["compact", "plan"])
    #expect(EditorKitPromptEditor.isTrigger("/", reportsCommands: commands != nil, hasRoot: false))
    let labels = await CompletionFixture.editor("/", commands: commands, root: nil).query()
    #expect(Set(labels) == ["/compact", "/plan"])
  }
}
