import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The slash command menu of the composer over a `SessionModel` (plan.md
/// §3.2 "Last-value state", §3.7 `Commands "not reported"`).
///
/// Each test shows a composer with the EditorKit editor. The composer reads
/// the session model from the environment. The scripted agent sets the
/// commands of the model in one of three states: not reported, reported
/// empty, and reported in the `session/new` response.
@Suite(.serialized, .hostedSerially) @MainActor struct SlashCommandSessionModelTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The time that a test waits to see that no menu opens, in seconds.
  static let settleTime: TimeInterval = 0.3

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
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, draft: PromptInputHostedTestModel
  ) throws -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      EditorKitPromptInputHost(model: draft, fileRoot: nil)
        .environment(\.sessionModel, session.model)
    }
    harness.pump()
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

  @Test func withCommandsNotReportedASlashShowsNoMenu() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let harness = try Self.mount(session: session, draft: draft)
    defer { harness.close() }
    let model = session.model
    try await session.sendUpdate(Self.markerUpdate)
    await harness.pump(until: Self.waitTimeout) { !model.transcript.isEmpty }

    harness.type("/")
    await harness.pump(until: Self.waitTimeout) { draft.plainText == "/" }
    harness.pump(for: Self.settleTime)

    #expect(model.availableCommands == nil)
    #expect(Self.completionLabels(in: harness).isEmpty)
    #expect(Self.noteLabel(in: harness) == nil)
  }

  @Test func afterAnEmptyCommandsUpdateASlashShowsTheNoCommandsNote() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let harness = try Self.mount(session: session, draft: draft)
    defer { harness.close() }
    let model = session.model
    try await session.sendUpdate(Self.emptyCommandsUpdate)
    await harness.pump(until: Self.waitTimeout) { model.availableCommands != nil }

    harness.type("/")
    await harness.pump(until: Self.waitTimeout) { Self.noteLabel(in: harness) != nil }

    #expect(model.availableCommands?.isEmpty == true)
    #expect(Self.noteLabel(in: harness) == EditorKitPromptEditor.noCommandsNote)
    #expect(Self.completionLabels(in: harness).isEmpty)
  }

  @Test func theCommandsOfTheNewSessionResponseShowWithNoUpdate() async throws {
    let session = try await ScriptedSession.open {
      $0.results["session/new"] = Self.newSessionWithCommands
    }
    defer { session.close() }
    let draft = PromptInputHostedTestModel()
    let harness = try Self.mount(session: session, draft: draft)
    defer { harness.close() }

    harness.type("/")
    await harness.pump(until: Self.waitTimeout) { Self.completionLabels(in: harness).count == 2 }

    #expect(session.model.availableCommands?.map(\.name) == ["compact", "plan"])
    #expect(Set(Self.completionLabels(in: harness)) == ["/compact", "/plan"])
    #expect(Self.noteLabel(in: harness) == nil)
  }
}
