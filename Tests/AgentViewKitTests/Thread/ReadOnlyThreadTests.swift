import ACPMarkdown
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for the read-only thread of a shared session (TestudoApp D208 (i)).
///
/// Each test makes a read-only model from a small share snapshot with
/// `SessionModel(snapshot:sessionId:)`. The model applies the updates of the
/// snapshot before the initializer returns, so no test waits. The tests
/// register the commands with ``AgentCommandRegistration``, as the mount of a
/// scope does, in a registry with no window. No test shows a window.
@MainActor struct ReadOnlyThreadTests {
  /// The id of the shared session.
  static let sessionID = SessionId(rawValue: "shared-session")

  /// The text of the first user message.
  static let question = "Hi."

  /// The text of the first agent message.
  static let answer = "Hello."

  /// The text that Copy Thread gives for the first snapshot.
  static let threadText = "User:\nHi.\n\nAssistant:\nHello."

  /// The verbs that change the session, or that act on the composer that
  /// changes it. A read-only thread does not register them.
  nonisolated static let changeVerbs: [AgentCommandVerb] = [
    .send, .cancel, .approvePending, .rejectPending, .forkFromHere, .focusComposer, .insertMention,
  ]

  /// The updates of the first snapshot: one user message and one agent
  /// message.
  static let firstUpdates: [SessionUpdate] = [
    .userMessageChunk(chunk(question, id: "user-1")),
    .agentMessageChunk(chunk(answer, id: "agent-1")),
  ]

  /// The updates of the newer snapshot: the first updates, then one more
  /// user message and one more agent message.
  static let newerUpdates: [SessionUpdate] =
    firstUpdates + [
      .userMessageChunk(chunk("And then?", id: "user-2")),
      .agentMessageChunk(chunk("Then it ends.", id: "agent-2")),
    ]

  /// The objects of one registration test.
  struct Fixture {
    /// The target of the scope.
    let target: AgentCommandTarget
    /// The registry with the commands of the scope.
    let registry: CommandRegistry
    /// The path of the scope.
    let path: FocusPath
  }

  /// Makes a text chunk of a message.
  ///
  /// - Parameters:
  ///   - text: The text of the chunk.
  ///   - id: The raw message id.
  /// - Returns: The chunk.
  static func chunk(_ text: String, id: String) -> ContentChunk {
    ContentChunk(content: .text(TextContent(text: text)), messageId: MessageId(rawValue: id))
  }

  /// Makes a read-only model that shows a snapshot of `updates`.
  ///
  /// - Parameter updates: The updates of the snapshot.
  /// - Returns: The model.
  static func readOnlyModel(_ updates: [SessionUpdate] = firstUpdates) -> SessionModel {
    SessionModel(snapshot: SessionSnapshot.build(updates: updates), sessionId: sessionID)
  }

  /// Registers the commands of a scope for `session`, with the fork action
  /// of the host and `pasteboard`, as the mount of a scope does.
  ///
  /// - Parameters:
  ///   - session: The session model of the scope.
  ///   - pasteboard: The pasteboard of Copy Thread.
  /// - Returns: The fixture.
  static func makeFixture(session: SessionModel, pasteboard: NSPasteboard = .general) -> Fixture {
    let target = AgentCommandTarget()
    target.session = session
    target.pasteboard = pasteboard
    target.forkFromHere = AgentCommandsTests.forkAction
    let path = FocusPath.root(AgentCommandTarget.segment(for: session))
    var registry = CommandRegistry()
    AgentCommandRegistration.register(target, at: path, into: &registry)
    return Fixture(target: target, registry: registry, path: path)
  }

  // MARK: - Composer

  @Test func aReadOnlyThreadShowsNoComposer() {
    #expect(!AgentThreadLayout.showsComposer(for: Self.readOnlyModel()))
  }

  @Test func aLiveThreadShowsTheComposer() {
    #expect(AgentThreadLayout.showsComposer(for: .preview()))
  }

  // MARK: - Registry

  @Test(arguments: changeVerbs)
  func aReadOnlyThreadDoesNotRegisterAChangeVerb(_ verb: AgentCommandVerb) {
    let fixture = Self.makeFixture(session: Self.readOnlyModel())

    #expect(fixture.registry.definition(for: verb.id, at: fixture.path) == nil)
  }

  @Test func aReadOnlyThreadRegistersEachReadVerb() {
    let fixture = Self.makeFixture(session: Self.readOnlyModel())
    let readVerbs = AgentCommandVerb.allCases.filter { !Self.changeVerbs.contains($0) }
    let ids = Set(fixture.registry.definitions(at: fixture.path).map(\.id))

    #expect(ids == Set(readVerbs.map(\.id)))
  }

  @Test func aLiveThreadRegistersEachChangeVerb() {
    let fixture = Self.makeFixture(session: .preview())
    let ids = Set(fixture.registry.definitions(at: fixture.path).map(\.id))

    #expect(ids.isSuperset(of: Self.changeVerbs.map(\.id)))
  }

  @Test func theContextMenuOfAMessageOfAReadOnlyThreadHasNoChangeVerb() throws {
    let session = Self.readOnlyModel()
    let fixture = Self.makeFixture(session: session)
    let entry = try #require(session.transcript.first)
    let messagePath = fixture.path.appending(AgentScopeKind.message(rowKey: entry.rowKey))
    let ids = Set(fixture.registry.contextMenuMirror(at: messagePath).map(\.id))

    #expect(ids.isDisjoint(with: Self.changeVerbs.map(\.id)))
  }

  @Test func copyThreadCopiesTheTextOfAReadOnlyThread() {
    NSPasteboard.withIsolated { pasteboard in
      let fixture = Self.makeFixture(session: Self.readOnlyModel(), pasteboard: pasteboard)

      #expect(fixture.registry.perform(AgentCommandVerb.copyThread.id, at: fixture.path))
      #expect(pasteboard.string(forType: .string) == Self.threadText)
    }
  }

  // MARK: - Message actions

  @Test(arguments: [MessageRole.user, .assistant])
  func theMessageActionsOfAReadOnlyThreadOnlyRead(_ role: MessageRole) {
    let actions = MessageActions.actions(for: role, canFork: true, isReadOnly: true)

    #expect(actions == [.copy, .copyThread, .export])
  }

  // MARK: - Scroll position

  @Test func aReplaceKeepsTheRowKeyOfEachEntryThatStays() throws {
    let session = Self.readOnlyModel()
    let keys = session.transcript.map(\.rowKey)

    try session.replace(with: SessionSnapshot.build(updates: Self.newerUpdates))

    #expect(Array(session.transcript.map(\.rowKey).prefix(keys.count)) == keys)
  }

  @Test func aReplaceKeepsTheScrollAnchorOfAReaderOfEarlierRows() throws {
    let session = Self.readOnlyModel()
    let scrolls = ReportRecorder<ScrollAnchorTarget>()
    let anchors = ScrollAnchorManager { scrolls.report($0) }
    let keys = session.transcript.map(\.rowKey)
    anchors.noteAppended(ids: keys)
    let first = try #require(keys.first)
    anchors.noteVisible(ids: [first], distanceFromBottom: .greatestFiniteMagnitude)
    anchors.saveAnchor()

    try session.replace(with: SessionSnapshot.build(updates: Self.newerUpdates))
    // The list tells the manager of the new rows after the old last row, as
    // `ConversationView` does when the last row key changes.
    anchors.noteAppended(ids: Array(session.transcript.map(\.rowKey)[keys.count...]))
    anchors.restoreAnchor()

    #expect(scrolls.values == [.item(first)])
    #expect(session.transcript.first?.rowKey == first)
  }
}
