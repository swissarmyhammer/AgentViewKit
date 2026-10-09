@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// A count of the calls to a test closure.
final class CallCounter {
  /// The number of calls.
  var count = 0
}

/// Tests for the agent commands through the EditorKit headless harness:
/// registration, eligibility, dispatch, and the default keymap.
@MainActor struct AgentCommandsTests {
  /// The text that the send tests send.
  static let message = "Hello"

  /// The number of verbs of the kit.
  static let verbCount = 10

  /// The number of turns that ``sendTurns(to:)`` sends.
  static let turnCount = 3

  /// The JSON-RPC id of the permission request that the scripted agent sends.
  static let agentRequestID = 100

  /// The JSON-RPC id of the second permission request of the reject test.
  static let secondRequestID = 101

  /// The `allow_once` option of ``ScriptedSession/permissionParams``.
  static let allowOptionID = "yes"

  /// The `reject_once` option of ``ScriptedSession/permissionParams``.
  static let rejectOptionID = "no"

  /// The comment of the reject test.
  static let comment = "Use the test file."

  /// A text block that is only for the assistant.
  static let assistantOnlyText = #"{"type":"text","text":"Hidden.","annotations":{"audience":["assistant"]}}"#

  /// The objects of one harness test.
  struct Fixture {
    /// The target of the scope.
    let target: AgentCommandTarget
    /// The harness with the scope.
    let system: CommandSystemHarness
    /// The path of the scope.
    let path: FocusPath
  }

  /// Makes a harness with one agent command scope for `session`.
  ///
  /// - Parameters:
  ///   - session: The session model of the scope.
  ///   - configure: Changes to the target before the test.
  /// - Returns: The fixture, focused at the scope.
  static func makeFixture(
    session: SessionModel,
    configure: (AgentCommandTarget) -> Void = { _ in }
  ) -> Fixture {
    let target = AgentCommandTarget()
    target.session = session
    configure(target)
    let segment = AgentCommandTarget.segment(for: session)
    let bindings: [ScopeBinding] =
      AgentCommand.definitions(for: target).map { .command($0) }
      + AgentKeymap.sortedChords.map { .key($0.chord.asSequence, .command($0.verb.id), .cua) }
    let system = CommandSystemHarness {
      Scope(segment, bindings: bindings)
    }
    let path = FocusPath.root(segment)
    system.focus(path)
    return Fixture(target: target, system: system, path: path)
  }

  /// Tells if the command of `verb` is available in `fixture`.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - fixture: The fixture.
  /// - Returns: `true` when the command is available.
  static func isAvailable(_ verb: AgentCommandVerb, in fixture: Fixture) throws -> Bool {
    let definition = try #require(fixture.system.registry.definition(for: verb.id, at: fixture.path))
    return definition.make(nil).availability(in: fixture.system.context()).isAvailable
  }

  /// Sends a user message and an agent message from the agent for each of
  /// ``turnCount`` turns, and waits until the model holds each entry.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The row key of each user message entry, in order.
  /// - Throws: The error of the transport, or an issue when the model does
  ///   not hold each entry at the time limit.
  static func sendTurns(to session: ScriptedSession) async throws -> [String] {
    for turn in 0..<turnCount {
      try await session.sendUpdate(
        WireBlockJSON.makeChunk(
          "user_message_chunk", messageID: "turn-\(turn)", block: WireBlockJSON.makeText("Question \(turn).")))
      try await session.sendUpdate(
        WireBlockJSON.makeChunk(
          "agent_message_chunk", messageID: "answer-\(turn)", block: WireBlockJSON.makeText("Answer \(turn).")))
    }
    try #require(await waitUntil { session.model.transcript.count == 2 * turnCount })
    return session.model.transcript.compactMap { entry in
      if case .userMessage = entry { entry.rowKey } else { nil }
    }
  }

  // MARK: - Registration

  @Test func theScopeListsTheTenCommands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    let ids = Set(fixture.system.registry.definitions(at: fixture.path).map(\.id))

    #expect(ids.count == Self.verbCount)
    #expect(ids == Set(AgentCommandVerb.allCases.map(\.id)))
  }

  @Test func eachVerbHasATitleAndAnIdThatMapsBack() {
    for verb in AgentCommandVerb.allCases {
      #expect(!verb.title.isEmpty)
      #expect(verb.id.rawValue == "agent.\(verb.rawValue)")
      #expect(AgentCommandVerb(id: verb.id) == verb)
    }
    #expect(AgentCommandVerb(id: "editor.copy") == nil)
  }

  @Test func theDefinitionsCarryTheDefaultKeys() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    let send = fixture.system.registry.definition(for: AgentCommandVerb.send.id, at: fixture.path)
    let focus = fixture.system.registry.definition(
      for: AgentCommandVerb.focusComposer.id, at: fixture.path)

    #expect(send?.keys[.cua] == AgentKeymap.commandReturn)
    #expect(focus?.keys.isEmpty == true)
  }

  @Test func aSecondRegistrationDoesNotAddTheKeysAgain() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let target = AgentCommandTarget()
    target.session = session.model
    let path = FocusPath.root(AgentCommandTarget.segment(for: session.model))
    var registry = CommandRegistry()

    AgentCommandRegistration.register(target, at: path, into: &registry)
    AgentCommandRegistration.register(target, at: path, into: &registry)

    let bindings = registry.keymapStack(for: .cua, at: path).bindings(for: KeySequence(.escape))
    #expect(bindings.count == 1)
    #expect(registry.tree.nodes.filter { $0.path == path }.count == 1)

    AgentCommandRegistration.deregister(at: path, from: &registry)
    #expect(registry.tree.nodes.isEmpty)
  }

  // MARK: - Eligibility

  @Test func anUnavailableCommandTellsTheReason() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    let explanation = AgentCommand(verb: .cancel, target: fixture.target, payload: nil)
      .availability(in: fixture.system.context())

    #expect(explanation == .unavailable(reason: AgentCommandTarget.reason(for: .cancel)))
  }

  @Test func aCommandWithNoTargetIsUnavailable() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    let command = AgentCommand(verb: .copyThread, target: nil, payload: nil)

    #expect(!command.availability(in: fixture.system.context()).isAvailable)
    #expect(!command.run(in: fixture.system.context()))
  }

  @Test func theViewCommandsNeedTheirParts() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    _ = try await Self.sendTurns(to: session)
    let fixture = Self.makeFixture(session: session.model)

    #expect(try !Self.isAvailable(.jumpToNext, in: fixture))
    #expect(try !Self.isAvailable(.scrollToBottom, in: fixture))
    #expect(try !Self.isAvailable(.toggleExpandAll, in: fixture))
    #expect(try !Self.isAvailable(.focusComposer, in: fixture))
    #expect(try !Self.isAvailable(.send, in: fixture))
    #expect(try Self.isAvailable(.copyThread, in: fixture))
  }

  // MARK: - Send and cancel

  @Test func sendWithBlankTextDoesNothing() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    #expect(!fixture.system.perform(AgentCommandVerb.send.id, payload: AgentCommandPayload.text(" \n")))
  }

  @Test func sendWithNoPayloadSubmitsTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let submits = CallCounter()
    let fixture = Self.makeFixture(session: session.model) { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { true }, submit: { submits.count += 1 },
        load: { _ in }, focus: { true })
    }

    #expect(fixture.system.perform(AgentCommandVerb.send.id))
    #expect(submits.count == 1)
  }

  @Test func dispatchingCancelSendsSessionCancel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)
    try await Self.sendState(ScriptedSession.runningState, to: session)

    #expect(fixture.system.perform(AgentCommandVerb.cancel.id))
    #expect(await waitUntil { !session.agent.messages(method: ScriptedSession.cancelMethod).isEmpty })
    #expect(session.agent.messages(method: ScriptedSession.cancelMethod).count == 1)
  }

  // MARK: - Keymap

  @Test func escapeResolvesToCancelWhileRunning() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)
    let escape = KeySequence(.escape)

    #expect(fixture.system.registry.resolveKey(escape, mode: .cua, at: fixture.path) == .unbound)

    try await Self.sendState(ScriptedSession.runningState, to: session)
    #expect(
      fixture.system.registry.resolveKey(escape, mode: .cua, at: fixture.path)
        == .command(AgentCommandVerb.cancel.id, scope: fixture.path))
  }

  @Test func theDefaultKeymapBindsTheFiveChords() {
    let expected: [(String, AgentCommandVerb)] = [
      ("⌘↩", .send), ("⎋", .cancel), ("⇧⌘C", .copyThread), ("⌥↑", .jumpToPrevious),
      ("⌥↓", .jumpToNext),
    ]

    #expect(AgentKeymap.defaultChords.count == expected.count)
    for (chord, verb) in expected {
      let actions = AgentKeymap.defaultKeymap.bindings(for: KeySequence(canonical: chord))
        .map(\.action)
      #expect(actions == [.command(verb.id)], "\(chord)")
    }
  }

  // MARK: - Permission

  @Test func approveSelectsTheAllowOnceOptionOfTheFirstRequest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)
    _ = try await session.receivePermissionRequest(id: Self.agentRequestID)

    #expect(fixture.system.perform(AgentCommandVerb.approvePending.id))
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result?["outcome"]?["optionId"]?.stringValue == Self.allowOptionID)
  }

  @Test func rejectAnswersTheRequestOfThePayloadAndSendsTheComment() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = Self.makeFixture(session: model)
    _ = try await session.receivePermissionRequest(id: Self.agentRequestID)
    try await session.sendRequest(
      ScriptedSession.permissionMethod, id: Self.secondRequestID, params: ScriptedSession.permissionParams)
    try #require(await waitUntil { model.pendingPermissions.count == 2 })
    let second = try #require(model.pendingPermissions.last)
    let payload = AgentCommandPayload.permission(
      request: second.id, option: PermissionOptionId(rawValue: Self.rejectOptionID), comment: Self.comment)

    #expect(fixture.system.perform(AgentCommandVerb.rejectPending.id, payload: payload))
    let result = await session.result(ofRequest: Self.secondRequestID)
    #expect(await waitUntil { !session.promptTexts.isEmpty })

    #expect(result?["outcome"]?["optionId"]?.stringValue == Self.rejectOptionID)
    #expect(model.pendingPermissions.count == 1)
    #expect(session.promptTexts == [Self.comment])
  }

  @Test func theAnswerCommandsNeedAMatchingOption() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = Self.makeFixture(session: model)
    let request = try await session.receivePermissionRequest(id: Self.agentRequestID)
    let allow = PermissionOptionId(rawValue: Self.allowOptionID)
    let wrongKind = AgentCommandPayload.permission(request: request.id, option: allow)

    #expect(!fixture.system.perform(AgentCommandVerb.rejectPending.id, payload: wrongKind))
    #expect(model.pendingPermissions.count == 1)
  }

  // MARK: - Thread view commands

  @Test func copyThreadCopiesTheMessagesAsPlainText() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let pasteboard = FakePasteboard()
    let fixture = Self.makeFixture(session: model) { $0.pasteboard = pasteboard }
    #expect(AgentCommandTarget.plainText(of: model).isEmpty)
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "copy-u", block: WireBlockJSON.makeText("Hi.")))
    try await session.sendUpdate(
      WireBlockJSON.makeToolCallUpdate(id: "copy-c", fields: #""title": "Read", "kind": "read", "status": "completed""#))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: "copy-m", block: WireBlockJSON.makeText("Hello.")))
    try #require(await waitUntil { model.transcript.count == 3 })

    #expect(fixture.system.perform(AgentCommandVerb.copyThread.id))
    #expect(pasteboard.contents == "User:\nHi.\n\nAssistant:\nHello.")
  }

  @Test func scrollToBottomPinsTheList() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await Self.sendTurns(to: session)
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    anchors.noteLastItemChanged(to: session.model.transcript.last?.rowKey)
    anchors.noteVisible(ids: [try #require(userKeys.first)], distanceFromBottom: .greatestFiniteMagnitude)
    let fixture = Self.makeFixture(session: session.model) { $0.anchors = anchors }
    targets.removeAll()

    #expect(fixture.system.perform(AgentCommandVerb.scrollToBottom.id))
    #expect(anchors.isPinnedToBottom)
    #expect(await waitUntil { targets == [.bottom] })
  }

  @Test func theJumpCommandsGoToTheNextAndThePreviousTurn() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let userKeys = try await Self.sendTurns(to: session)
    try #require(userKeys.count == Self.turnCount)
    let keys = session.model.transcript.map(\.rowKey)
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    let fixture = Self.makeFixture(session: session.model) { $0.anchors = anchors }

    #expect(try !Self.isAvailable(.jumpToPrevious, in: fixture))
    #expect(fixture.system.perform(AgentCommandVerb.jumpToNext.id))
    #expect(targets == [.item(userKeys[0])])
    // The list reports the rows of the jump. Until this report, the manager
    // keeps the jump item as the visible item.
    anchors.noteVisible(ids: [keys[0], keys[1]], distanceFromBottom: .greatestFiniteMagnitude)

    // The answer of the second turn and the user message of the third turn.
    anchors.noteVisible(ids: [keys[3], userKeys[2]], distanceFromBottom: .greatestFiniteMagnitude)
    #expect(fixture.system.perform(AgentCommandVerb.jumpToNext.id))
    #expect(fixture.system.perform(AgentCommandVerb.jumpToPrevious.id))
    #expect(targets == [.item(userKeys[0]), .item(userKeys[2]), .item(userKeys[1])])
    #expect(anchors.anchorID == userKeys[1])

    anchors.noteVisible(ids: [userKeys[2]], distanceFromBottom: 0)
    #expect(try !Self.isAvailable(.jumpToNext, in: fixture))
  }

  @Test func focusComposerCallsTheFocusOfTheComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let focuses = CallCounter()
    let fixture = Self.makeFixture(session: session.model) { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { false }, submit: {}, load: { _ in },
        focus: {
          focuses.count += 1
          return true
        })
    }

    #expect(fixture.system.perform(AgentCommandVerb.focusComposer.id))
    #expect(focuses.count == 1)

    fixture.target.removeComposer(owner: ObjectIdentifier(focuses))
    #expect(fixture.target.composer != nil)
    fixture.target.removeComposer(owner: ObjectIdentifier(fixture.target))
    #expect(fixture.target.composer == nil)
  }

  // MARK: - Session model

  /// Sends a `state_update` from the agent, and waits until the agent state
  /// of the session model changes.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update, such as
  ///     ``ScriptedSession/runningState``.
  ///   - session: The scripted session.
  /// - Throws: The error of the transport.
  static func sendState(_ update: String, to session: ScriptedSession) async throws {
    let before = session.model.agentState
    try await session.sendUpdate(update)
    #expect(await waitUntil { session.model.agentState != before })
  }

  @Test func cancelFollowsTheAgentStateOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    #expect(try !Self.isAvailable(.cancel, in: fixture))

    try await Self.sendState(ScriptedSession.runningState, to: session)
    #expect(try Self.isAvailable(.cancel, in: fixture))

    try await Self.sendState(ScriptedSession.requiresActionState, to: session)
    #expect(try Self.isAvailable(.cancel, in: fixture))

    try await Self.sendState(ScriptedSession.idleState, to: session)
    #expect(try !Self.isAvailable(.cancel, in: fixture))
  }

  @Test func theAnswerCommandsFollowThePendingPermissionsOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let fixture = Self.makeFixture(session: model)

    #expect(try !Self.isAvailable(.approvePending, in: fixture))
    #expect(try !Self.isAvailable(.rejectPending, in: fixture))

    _ = try await session.receivePermissionRequest(id: Self.agentRequestID)
    #expect(try Self.isAvailable(.approvePending, in: fixture))
    #expect(try Self.isAvailable(.rejectPending, in: fixture))

    #expect(fixture.system.perform(AgentCommandVerb.rejectPending.id))
    let result = await session.result(ofRequest: Self.agentRequestID)

    #expect(result?["outcome"]?["optionId"]?.stringValue == Self.rejectOptionID)
    #expect(model.pendingPermissions.isEmpty)
    #expect(try !Self.isAvailable(.approvePending, in: fixture))
    #expect(try !Self.isAvailable(.rejectPending, in: fixture))
  }

  @Test func sendWithATextPayloadSendsAPromptOfTheSessionModel() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = Self.makeFixture(session: session.model)

    #expect(fixture.system.perform(AgentCommandVerb.send.id, payload: AgentCommandPayload.text(Self.message)))
    #expect(await waitUntil { !session.agent.messages(method: ScriptedSession.promptMethod).isEmpty })

    #expect(session.promptTexts == [Self.message])
  }

  @Test func theCopyTextOfASessionJoinsTheChunksAndOmitsBlocksThatAreNotForTheUser() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let expected = "User:\nHi.\n\nAssistant:\nHello."

    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "copy-u", block: WireBlockJSON.makeText("Hi.")))
    for block in [WireBlockJSON.makeText("Hel"), WireBlockJSON.makeText("lo."), Self.assistantOnlyText] {
      try await session.sendUpdate(WireBlockJSON.makeChunk("agent_message_chunk", messageID: "copy-m", block: block))
    }
    _ = await waitUntil { AgentCommandTarget.plainText(of: model) == expected }

    #expect(AgentCommandTarget.plainText(of: model) == expected)
  }

  @Test func toggleExpandAllExpandsEachEntryOfTheSessionModelThenCollapsesEachEntry() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let store = ExpandedBlocksStore()
    let fixture = Self.makeFixture(session: model) { $0.expandedBlocks = store }

    #expect(try !Self.isAvailable(.toggleExpandAll, in: fixture))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "expand-u", block: WireBlockJSON.makeText("Hi.")))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: "expand-m", block: WireBlockJSON.makeText("Hello.")))
    #expect(await waitUntil { model.transcript.count == 2 })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(model.transcript.allSatisfy { store.isExpanded(entry: $0) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(model.transcript.allSatisfy { !store.isExpanded(entry: $0) })
  }

  @Test func toggleExpandAllCollapsesTheEntriesThatThePolicyExpands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let store = ExpandedBlocksStore { _ in true }
    let fixture = Self.makeFixture(session: model) { $0.expandedBlocks = store }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: "policy-m", block: WireBlockJSON.makeText("Hello.")))
    #expect(await waitUntil { !model.transcript.isEmpty })
    #expect(model.transcript.allSatisfy { store.isExpanded(entry: $0) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))

    #expect(model.transcript.allSatisfy { !store.isExpanded(entry: $0) })
  }
}
