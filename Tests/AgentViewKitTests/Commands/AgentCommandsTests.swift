@testable import AgentViewKit
import AgentViewKitTestSupport
import DemoSupport
import EditorCommands
import EditorCommandsTestSupport
import Foundation
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

  /// The number of user messages in the jump thread.
  static let turnCount = 3

  /// The JSON-RPC id of the permission request that the scripted agent sends.
  static let agentRequestID = 100

  /// The `reject_once` option of ``ScriptedSession/permissionParams``.
  static let rejectOptionID = "no"

  /// A text block that is only for the assistant.
  static let assistantOnlyText = #"{"type":"text","text":"Hidden.","annotations":{"audience":["assistant"]}}"#

  /// The objects of one harness test.
  struct Fixture {
    /// The actions that the commands of a thread scope call.
    let actions: NoopThreadActions
    /// The target of the scope.
    let target: AgentCommandTarget
    /// The harness with the scope.
    let system: CommandSystemHarness
    /// The path of the scope.
    let path: FocusPath
  }

  /// Makes a harness with one agent command scope for `source`.
  ///
  /// - Parameters:
  ///   - source: The thread or the session model of the scope.
  ///   - configure: Changes to the target before the test.
  /// - Returns: The fixture, focused at the scope.
  static func makeFixture(
    source: ConversationSource,
    configure: (AgentCommandTarget) -> Void = { _ in }
  ) -> Fixture {
    let actions = NoopThreadActions()
    let target = AgentCommandTarget()
    target.source = source
    target.actions = actions
    configure(target)
    let segment = AgentCommandTarget.segment(for: source)
    let bindings: [ScopeBinding] =
      AgentCommand.definitions(for: target).map { .command($0) }
      + AgentKeymap.sortedChords.map { .key($0.chord.asSequence, .command($0.verb.id), .cua) }
    let system = CommandSystemHarness {
      Scope(segment, bindings: bindings)
    }
    let path = FocusPath.root(segment)
    system.focus(path)
    return Fixture(actions: actions, target: target, system: system, path: path)
  }

  /// Makes a harness with one agent command scope for `thread`.
  ///
  /// - Parameters:
  ///   - thread: The thread of the scope.
  ///   - configure: Changes to the target before the test.
  /// - Returns: The fixture, focused at the scope.
  static func makeFixture(
    thread: AgentThread = AgentThread(),
    configure: (AgentCommandTarget) -> Void = { _ in }
  ) -> Fixture {
    makeFixture(source: .thread(thread), configure: configure)
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

  /// Makes a thread with a user message and an assistant message for each
  /// turn. The user message ids are `turn-<n>`.
  ///
  /// - Returns: The thread.
  static func turnThread() -> AgentThread {
    let thread = AgentThread()
    for turn in 0..<turnCount {
      let user = ThreadFixtures.message(id: "turn-\(turn)", text: "Question \(turn).")
      let answer = ThreadFixtures.message(id: "answer-\(turn)", text: "Answer \(turn).")
      thread.apply(.insert(.userMessage(user), after: nil))
      thread.apply(.insert(.assistantMessage(answer), after: nil))
    }
    return thread
  }

  // MARK: - Registration

  @Test func theScopeListsTheTenCommands() {
    let fixture = Self.makeFixture()

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

  @Test func theDefinitionsCarryTheDefaultKeys() {
    let fixture = Self.makeFixture()

    let send = fixture.system.registry.definition(for: AgentCommandVerb.send.id, at: fixture.path)
    let focus = fixture.system.registry.definition(
      for: AgentCommandVerb.focusComposer.id, at: fixture.path)

    #expect(send?.keys[.cua] == AgentKeymap.commandReturn)
    #expect(focus?.keys.isEmpty == true)
  }

  @Test func aSecondRegistrationDoesNotAddTheKeysAgain() {
    let thread = AgentThread()
    let target = AgentCommandTarget()
    target.source = .thread(thread)
    let path = FocusPath.root(AgentCommandTarget.segment(for: .thread(thread)))
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

  @Test func cancelIsIneligibleWhileIdleAndEligibleWhileRunning() throws {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)

    #expect(try !Self.isAvailable(.cancel, in: fixture))
    #expect(!fixture.system.perform(AgentCommandVerb.cancel.id))

    thread.apply(.setState(.running))
    #expect(try Self.isAvailable(.cancel, in: fixture))

    thread.apply(.setState(.requiresAction))
    #expect(try Self.isAvailable(.cancel, in: fixture))

    thread.apply(.setState(.idle(.endTurn)))
    #expect(try !Self.isAvailable(.cancel, in: fixture))
  }

  @Test func anUnavailableCommandTellsTheReason() {
    let fixture = Self.makeFixture()

    let explanation = AgentCommand(verb: .cancel, target: fixture.target, payload: nil)
      .availability(in: fixture.system.context())

    #expect(explanation == .unavailable(reason: AgentCommandTarget.reason(for: .cancel)))
  }

  @Test func aCommandWithNoTargetIsUnavailable() {
    let fixture = Self.makeFixture()

    let command = AgentCommand(verb: .copyThread, target: nil, payload: nil)

    #expect(!command.availability(in: fixture.system.context()).isAvailable)
    #expect(!command.run(in: fixture.system.context()))
  }

  @Test func theViewCommandsNeedTheirParts() throws {
    let fixture = Self.makeFixture(thread: Self.turnThread())

    #expect(try !Self.isAvailable(.jumpToNext, in: fixture))
    #expect(try !Self.isAvailable(.scrollToBottom, in: fixture))
    #expect(try !Self.isAvailable(.toggleExpandAll, in: fixture))
    #expect(try !Self.isAvailable(.focusComposer, in: fixture))
    #expect(try !Self.isAvailable(.send, in: fixture))
    #expect(try Self.isAvailable(.copyThread, in: fixture))
  }

  // MARK: - Send and cancel

  @Test func dispatchingSendCallsTheSendAction() async {
    let fixture = Self.makeFixture()

    let handled = fixture.system.perform(
      AgentCommandVerb.send.id, payload: AgentCommandPayload.text(Self.message))

    #expect(handled)
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })
    #expect(fixture.actions.calls == [.send(UserInput(text: Self.message))])
  }

  @Test func sendWithBlankTextDoesNothing() {
    let fixture = Self.makeFixture()

    #expect(!fixture.system.perform(AgentCommandVerb.send.id, payload: AgentCommandPayload.text(" \n")))
  }

  @Test func sendWithNoPayloadSubmitsTheComposer() {
    let submits = CallCounter()
    let fixture = Self.makeFixture { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { true }, submit: { submits.count += 1 },
        load: { _ in }, focus: { true })
    }

    #expect(fixture.system.perform(AgentCommandVerb.send.id))
    #expect(submits.count == 1)
  }

  @Test func dispatchingCancelCallsTheCancelAction() async {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)
    thread.apply(.setState(.running))

    #expect(fixture.system.perform(AgentCommandVerb.cancel.id))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })
    #expect(fixture.actions.calls == [.cancel])
  }

  // MARK: - Keymap

  @Test func escapeResolvesToCancelWhileRunning() {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)
    let escape = KeySequence(.escape)

    #expect(fixture.system.registry.resolveKey(escape, mode: .cua, at: fixture.path) == .unbound)

    thread.apply(.setState(.running))
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

  @Test func approveSelectsTheAllowOnceOptionOfTheFirstRequest() async {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)
    let request = ThreadFixtures.permissionRequest()
    thread.apply(.addPermission(request))

    #expect(fixture.system.perform(AgentCommandVerb.approvePending.id))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })

    let decision = PermissionDecision(
      outcome: .selected(PermissionOptionID(PermissionOption.Kind.allowOnce.wireValue)))
    #expect(fixture.actions.calls == [.respondToPermission(request, decision)])
  }

  @Test func rejectSendsTheOptionAndTheCommentOfThePayload() async {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)
    let first = ThreadFixtures.permissionRequest(id: "permission-first")
    let second = ThreadFixtures.permissionRequest(id: "permission-second")
    thread.apply(.addPermission(first))
    thread.apply(.addPermission(second))
    let option = PermissionOptionID(PermissionOption.Kind.rejectAlways.wireValue)
    let payload = AgentCommandPayload.permission(
      request: second.id, option: option, comment: "Use the test file.")

    #expect(fixture.system.perform(AgentCommandVerb.rejectPending.id, payload: payload))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })

    let decision = PermissionDecision(outcome: .selected(option), comment: "Use the test file.")
    #expect(fixture.actions.calls == [.respondToPermission(second, decision)])
  }

  @Test func theAnswerCommandsNeedAPendingRequestAndAMatchingOption() throws {
    let thread = AgentThread()
    let fixture = Self.makeFixture(thread: thread)

    #expect(try !Self.isAvailable(.approvePending, in: fixture))
    #expect(try !Self.isAvailable(.rejectPending, in: fixture))

    let request = ThreadFixtures.permissionRequest()
    thread.apply(.addPermission(request))
    let allow = PermissionOptionID(PermissionOption.Kind.allowOnce.wireValue)
    let wrongKind = AgentCommandPayload.permission(request: request.id, option: allow)

    #expect(!fixture.system.perform(AgentCommandVerb.rejectPending.id, payload: wrongKind))
    #expect(fixture.actions.calls.isEmpty)
  }

  // MARK: - Thread view commands

  @Test func copyThreadCopiesTheMessagesAsPlainText() {
    let pasteboard = FakePasteboard()
    let thread = AgentThread()
    thread.apply(.insert(.userMessage(ThreadFixtures.message(id: "user", text: "Hi.")), after: nil))
    thread.apply(
      .insert(.toolCall(ThreadFixtures.toolCall(id: "call", status: .completed)), after: nil))
    thread.apply(
      .insert(.assistantMessage(ThreadFixtures.message(id: "agent", text: "Hello.")), after: nil))
    let fixture = Self.makeFixture(thread: thread) { $0.pasteboard = pasteboard }

    #expect(fixture.system.perform(AgentCommandVerb.copyThread.id))
    #expect(pasteboard.contents == "User:\nHi.\n\nAssistant:\nHello.")
  }

  @Test func theCopyTextOmitsBlocksThatAreNotForTheUser() {
    let thread = AgentThread()
    let hidden = ContentBlock(
      content: .text("Hidden."), annotations: Annotations(audience: [.assistant]))
    let message = Message(id: "agent", blocks: [ContentBlock(text: "Shown."), hidden])
    thread.apply(.insert(.assistantMessage(message), after: nil))

    #expect(AgentCommandTarget.plainText(of: thread) == "Assistant:\nShown.")
    #expect(AgentCommandTarget.plainText(of: AgentThread()).isEmpty)
  }

  @Test func toggleExpandAllExpandsEachItemThenCollapsesEachItem() {
    let store = ExpandedBlocksStore()
    let thread = Self.turnThread()
    let fixture = Self.makeFixture(thread: thread) { $0.expandedBlocks = store }

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(thread.items.allSatisfy { store.isExpanded($0.id) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(thread.items.allSatisfy { !store.isExpanded($0.id) })
  }

  @Test func scrollToBottomPinsTheList() async {
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    let thread = Self.turnThread()
    anchors.noteLastItemChanged(to: thread.lastItemID)
    anchors.noteVisible(ids: ["turn-0"], distanceFromBottom: .greatestFiniteMagnitude)
    let fixture = Self.makeFixture(thread: thread) { $0.anchors = anchors }
    targets.removeAll()

    #expect(fixture.system.perform(AgentCommandVerb.scrollToBottom.id))
    #expect(anchors.isPinnedToBottom)
    #expect(await waitUntil { targets == [.bottom] })
  }

  @Test func theJumpCommandsGoToTheNextAndThePreviousTurn() throws {
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    let fixture = Self.makeFixture(thread: Self.turnThread()) { $0.anchors = anchors }

    #expect(try !Self.isAvailable(.jumpToPrevious, in: fixture))
    #expect(fixture.system.perform(AgentCommandVerb.jumpToNext.id))
    #expect(targets == [.item("turn-0")])

    anchors.noteVisible(ids: ["answer-1", "turn-2"], distanceFromBottom: .greatestFiniteMagnitude)
    #expect(fixture.system.perform(AgentCommandVerb.jumpToNext.id))
    #expect(fixture.system.perform(AgentCommandVerb.jumpToPrevious.id))
    #expect(targets == [.item("turn-0"), .item("turn-2"), .item("turn-1")])
    #expect(anchors.anchorID == "turn-1")

    anchors.noteVisible(ids: ["turn-2"], distanceFromBottom: 0)
    #expect(try !Self.isAvailable(.jumpToNext, in: fixture))
  }

  @Test func focusComposerCallsTheFocusOfTheComposer() {
    let focuses = CallCounter()
    let fixture = Self.makeFixture { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { false }, submit: {}, load: { _ in },
        focus: {
          focuses.count += 1
          return true
        })
    }

    #expect(fixture.system.perform(AgentCommandVerb.focusComposer.id))
    #expect(focuses.count == 1)

    fixture.target.removeComposer(owner: ObjectIdentifier(fixture.actions))
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
    let fixture = Self.makeFixture(source: .session(session.model))

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
    let fixture = Self.makeFixture(source: .session(model))

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
    let fixture = Self.makeFixture(source: .session(session.model))

    #expect(fixture.system.perform(AgentCommandVerb.send.id, payload: AgentCommandPayload.text(Self.message)))
    #expect(await waitUntil { !session.agent.messages(method: ScriptedSession.promptMethod).isEmpty })

    let prompts = session.agent.messages(method: ScriptedSession.promptMethod)
    #expect(prompts.map(ScriptedWireAgent.promptText(of:)) == [Self.message])
    #expect(fixture.actions.calls.isEmpty)
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
    let fixture = Self.makeFixture(source: .session(model)) { $0.expandedBlocks = store }

    #expect(try !Self.isAvailable(.toggleExpandAll, in: fixture))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("user_message_chunk", messageID: "expand-u", block: WireBlockJSON.makeText("Hi.")))
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: "expand-m", block: WireBlockJSON.makeText("Hello.")))
    #expect(await waitUntil { model.transcript.count == 2 })
    let keys = model.transcript.map(\.rowKey)

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(keys.allSatisfy { store.isExpanded($0) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(keys.allSatisfy { !store.isExpanded($0) })
  }

  @Test func toggleExpandAllCollapsesTheEntriesThatThePolicyExpands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let store = ExpandedBlocksStore { _ in true }
    let fixture = Self.makeFixture(source: .session(model)) { $0.expandedBlocks = store }
    try await session.sendUpdate(
      WireBlockJSON.makeChunk("agent_message_chunk", messageID: "policy-m", block: WireBlockJSON.makeText("Hello.")))
    #expect(await waitUntil { !model.transcript.isEmpty })
    #expect(model.transcript.allSatisfy { store.isExpanded($0) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))

    #expect(model.transcript.allSatisfy { !store.isExpanded($0) })
  }
}
