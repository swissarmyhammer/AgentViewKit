@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsTestSupport
import Foundation
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

  /// The objects of one harness test.
  struct Fixture {
    /// The thread of the scope.
    let thread: AgentThread
    /// The actions that the commands call.
    let actions: NoopThreadActions
    /// The target of the scope.
    let target: AgentCommandTarget
    /// The harness with the scope.
    let system: CommandSystemHarness
    /// The path of the scope.
    let path: FocusPath
  }

  /// Makes a harness with one agent command scope for `thread`.
  ///
  /// - Parameters:
  ///   - thread: The thread of the scope.
  ///   - configure: Changes to the target before the test.
  /// - Returns: The fixture, focused at the scope.
  static func fixture(
    thread: AgentThread = AgentThread(),
    configure: (AgentCommandTarget) -> Void = { _ in }
  ) -> Fixture {
    let actions = NoopThreadActions()
    let target = AgentCommandTarget()
    target.thread = thread
    target.actions = actions
    configure(target)
    let segment = AgentCommandTarget.segment(for: thread)
    let bindings: [ScopeBinding] =
      AgentCommand.definitions(for: target).map { .command($0) }
      + AgentKeymap.sortedChords.map { .key($0.chord.asSequence, .command($0.verb.id), .cua) }
    let system = CommandSystemHarness {
      Scope(segment, bindings: bindings)
    }
    let path = FocusPath.root(segment)
    system.focus(path)
    return Fixture(thread: thread, actions: actions, target: target, system: system, path: path)
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
    let fixture = Self.fixture()

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
    let fixture = Self.fixture()

    let send = fixture.system.registry.definition(for: AgentCommandVerb.send.id, at: fixture.path)
    let focus = fixture.system.registry.definition(
      for: AgentCommandVerb.focusComposer.id, at: fixture.path)

    #expect(send?.keys[.cua] == AgentKeymap.commandReturn)
    #expect(focus?.keys.isEmpty == true)
  }

  @Test func aSecondRegistrationDoesNotAddTheKeysAgain() {
    let thread = AgentThread()
    let target = AgentCommandTarget()
    target.thread = thread
    let path = FocusPath.root(AgentCommandTarget.segment(for: thread))
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
    let fixture = Self.fixture()

    #expect(try !Self.isAvailable(.cancel, in: fixture))
    #expect(!fixture.system.perform(AgentCommandVerb.cancel.id))

    fixture.thread.apply(.setState(.running))
    #expect(try Self.isAvailable(.cancel, in: fixture))

    fixture.thread.apply(.setState(.requiresAction))
    #expect(try Self.isAvailable(.cancel, in: fixture))

    fixture.thread.apply(.setState(.idle(.endTurn)))
    #expect(try !Self.isAvailable(.cancel, in: fixture))
  }

  @Test func anUnavailableCommandTellsTheReason() {
    let fixture = Self.fixture()

    let explanation = AgentCommand(verb: .cancel, target: fixture.target, payload: nil)
      .availability(in: fixture.system.context())

    #expect(explanation == .unavailable(reason: AgentCommandTarget.reason(for: .cancel)))
  }

  @Test func aCommandWithNoTargetIsUnavailable() {
    let fixture = Self.fixture()

    let command = AgentCommand(verb: .copyThread, target: nil, payload: nil)

    #expect(!command.availability(in: fixture.system.context()).isAvailable)
    #expect(!command.run(in: fixture.system.context()))
  }

  @Test func theViewCommandsNeedTheirParts() throws {
    let fixture = Self.fixture(thread: Self.turnThread())

    #expect(try !Self.isAvailable(.jumpToNext, in: fixture))
    #expect(try !Self.isAvailable(.scrollToBottom, in: fixture))
    #expect(try !Self.isAvailable(.toggleExpandAll, in: fixture))
    #expect(try !Self.isAvailable(.focusComposer, in: fixture))
    #expect(try !Self.isAvailable(.send, in: fixture))
    #expect(try Self.isAvailable(.copyThread, in: fixture))
  }

  // MARK: - Send and cancel

  @Test func dispatchingSendCallsTheSendAction() async {
    let fixture = Self.fixture()

    let handled = fixture.system.perform(
      AgentCommandVerb.send.id, payload: AgentCommandPayload.text(Self.message))

    #expect(handled)
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })
    #expect(fixture.actions.calls == [.send(UserInput(text: Self.message))])
  }

  @Test func sendWithBlankTextDoesNothing() {
    let fixture = Self.fixture()

    #expect(!fixture.system.perform(AgentCommandVerb.send.id, payload: AgentCommandPayload.text(" \n")))
  }

  @Test func sendWithNoPayloadSubmitsTheComposer() {
    let submits = CallCounter()
    let fixture = Self.fixture { target in
      target.composer = AgentComposerHook(
        owner: ObjectIdentifier(target), canSubmit: { true }, submit: { submits.count += 1 },
        load: { _ in }, focus: { true })
    }

    #expect(fixture.system.perform(AgentCommandVerb.send.id))
    #expect(submits.count == 1)
  }

  @Test func dispatchingCancelCallsTheCancelAction() async {
    let fixture = Self.fixture()
    fixture.thread.apply(.setState(.running))

    #expect(fixture.system.perform(AgentCommandVerb.cancel.id))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })
    #expect(fixture.actions.calls == [.cancel])
  }

  // MARK: - Keymap

  @Test func escapeResolvesToCancelWhileRunning() {
    let fixture = Self.fixture()
    let escape = KeySequence(.escape)

    #expect(fixture.system.registry.resolveKey(escape, mode: .cua, at: fixture.path) == .unbound)

    fixture.thread.apply(.setState(.running))
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
    let fixture = Self.fixture()
    let request = ThreadFixtures.permissionRequest()
    fixture.thread.apply(.addPermission(request))

    #expect(fixture.system.perform(AgentCommandVerb.approvePending.id))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })

    let decision = PermissionDecision(
      outcome: .selected(PermissionOptionID(PermissionOption.Kind.allowOnce.wireValue)))
    #expect(fixture.actions.calls == [.respondToPermission(request, decision)])
  }

  @Test func rejectSendsTheOptionAndTheCommentOfThePayload() async {
    let fixture = Self.fixture()
    let first = ThreadFixtures.permissionRequest(id: "permission-first")
    let second = ThreadFixtures.permissionRequest(id: "permission-second")
    fixture.thread.apply(.addPermission(first))
    fixture.thread.apply(.addPermission(second))
    let option = PermissionOptionID(PermissionOption.Kind.rejectAlways.wireValue)
    let payload = AgentCommandPayload.permission(
      request: second.id, option: option, comment: "Use the test file.")

    #expect(fixture.system.perform(AgentCommandVerb.rejectPending.id, payload: payload))
    #expect(await waitUntil { !fixture.actions.calls.isEmpty })

    let decision = PermissionDecision(outcome: .selected(option), comment: "Use the test file.")
    #expect(fixture.actions.calls == [.respondToPermission(second, decision)])
  }

  @Test func theAnswerCommandsNeedAPendingRequestAndAMatchingOption() throws {
    let fixture = Self.fixture()

    #expect(try !Self.isAvailable(.approvePending, in: fixture))
    #expect(try !Self.isAvailable(.rejectPending, in: fixture))

    let request = ThreadFixtures.permissionRequest()
    fixture.thread.apply(.addPermission(request))
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
    let fixture = Self.fixture(thread: thread) { $0.pasteboard = pasteboard }

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
    let fixture = Self.fixture(thread: thread) { $0.expandedBlocks = store }

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(thread.items.allSatisfy { store.isExpanded($0) })

    #expect(fixture.system.perform(AgentCommandVerb.toggleExpandAll.id))
    #expect(thread.items.allSatisfy { !store.isExpanded($0) })
  }

  @Test func scrollToBottomPinsTheList() async {
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    let thread = Self.turnThread()
    anchors.noteLastItemChanged(to: thread.lastItemID)
    anchors.noteVisible(ids: ["turn-0"], distanceFromBottom: .greatestFiniteMagnitude)
    let fixture = Self.fixture(thread: thread) { $0.anchors = anchors }
    targets.removeAll()

    #expect(fixture.system.perform(AgentCommandVerb.scrollToBottom.id))
    #expect(anchors.isPinnedToBottom)
    #expect(await waitUntil { targets == [.bottom] })
  }

  @Test func theJumpCommandsGoToTheNextAndThePreviousTurn() throws {
    var targets: [ScrollAnchorTarget] = []
    let anchors = ScrollAnchorManager { targets.append($0) }
    let fixture = Self.fixture(thread: Self.turnThread()) { $0.anchors = anchors }

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
    let fixture = Self.fixture { target in
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
}
