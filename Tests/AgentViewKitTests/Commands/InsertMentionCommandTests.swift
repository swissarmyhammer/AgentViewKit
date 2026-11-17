@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import Testing

/// Tests for Mention…, the kit verb that inserts `@` in the composer and
/// opens the `@` popup (AVK-15.6, D199 (j)).
@MainActor struct InsertMentionCommandTests {
  /// Records the calls of a composer hook.
  final class ComposerLog {
    /// The texts that the hook inserted, in order.
    var inserted: [String] = []
    /// The number of focus calls.
    var focuses = 0
  }

  /// A fixture whose target has a composer hook that writes to `log`.
  static func fixture(session: SessionModel, log: ComposerLog) -> AgentCommandsTests.Fixture {
    AgentCommandsTests.makeFixture(session: session) { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { false }, submit: {}, load: { _ in },
        focus: {
          log.focuses += 1
          return true
        },
        insert: { log.inserted.append($0) })
    }
  }

  // MARK: - Place

  @Test func mentionIsAComposeCommandInTheSessionMenuAfterFocusComposer() throws {
    let verb = AgentCommandVerb.insertMention
    let menu = try #require(verb.menu)
    let focus = try #require(AgentCommandVerb.focusComposer.menu)

    #expect(verb.title == "Mention…")
    #expect(verb.group == .compose)
    #expect(menu.path == .session)
    #expect(menu.group == focus.group)
    #expect(menu.order > focus.order)
    #expect(verb.contextMenu != nil)
    #expect(AgentKeymap.defaultChords[verb] == nil)
  }

  @Test func mentionDoesNotShowInTheContextMenuOfAMessage() {
    let message = FocusPath.root(FocusSegment(kind: "thread")).appending(AgentScopeKind.message(rowKey: "m1"))
    let composer = FocusPath.root(FocusSegment(kind: "thread"))
      .appending(AgentScopeKind.control(EditorKitPromptEditor.identifier))

    #expect(!AgentCommandVerb.insertMention.isVisible(at: message))
    #expect(AgentCommandVerb.insertMention.isVisible(at: composer))
  }

  // MARK: - Run

  @Test func mentionFocusesTheComposerAndInsertsAnAtSign() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)

    #expect(fixture.system.perform(AgentCommandVerb.insertMention.id))

    #expect(log.focuses == 1)
    #expect(log.inserted == ["@"])
  }

  @Test func thePayloadGivesTheTextToInsert() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let log = ComposerLog()
    let fixture = Self.fixture(session: session.model, log: log)

    #expect(
      fixture.system.registry.perform(
        AgentCommandVerb.insertMention.id, at: fixture.path, payload: AgentCommandPayload.text("@plan")))

    #expect(log.inserted == ["@plan"])
  }

  @Test func withNoComposerMentionIsNotAvailable() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(try !AgentCommandsTests.isAvailable(.insertMention, in: fixture))
  }

  // MARK: - Insert in the editor

  @Test func theInsertGetsASpaceAfterAWord() {
    #expect(EditorKitPromptEditor.insertion(of: "@", after: "ask") == " @")
    #expect(EditorKitPromptEditor.insertion(of: "@", after: "ask ") == "@")
    #expect(EditorKitPromptEditor.insertion(of: "@", after: "") == "@")
    #expect(EditorKitPromptEditor.insertion(of: "@", after: "line\n") == "@")
  }

  @Test func eachInsertRequestIsTakenOneTime() {
    let insertions = PromptInsertions()
    insertions.request("@")
    insertions.request("@x")

    #expect(insertions.count == 2)
    #expect(insertions.take() == ["@", "@x"])
    #expect(insertions.take().isEmpty)
  }
}
