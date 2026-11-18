import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for the verbs of the side card of `/btw` (D205, D108): Send to Chat,
/// Open and Close in the scope of each card.
///
/// Each test registers the verbs with ``SideCardRegistration``, as the mount
/// of a card does, in a registry with no window. The fork is a preview
/// session model, so each entry is in the model when the call returns. No
/// test waits, and no test shows a window.
@MainActor struct SideCardCommandsTests {
  /// The question of the card.
  static let question = "Why?"

  /// The answer of the fork.
  static let answer = "Because."

  /// The Send to Chat text of the question and the answer.
  static var chatText: String {
    SideQuestionCard.chatText(question: question, answer: answer)
  }

  /// The id of the thread session that shows the card.
  static let threadID = "side-card-thread"

  /// The calls of the actions of a card and of a composer.
  final class ActionLog {
    /// The texts that Send to Chat gave to the host.
    var sent: [String] = []
    /// The texts that the composer inserted at the caret.
    var inserted: [String] = []
    /// The number of submits of the composer.
    var submits = 0
    /// The number of focus calls of the composer.
    var focuses = 0
    /// The number of runs of Open.
    var opens = 0
    /// The number of runs of Close.
    var closes = 0
  }

  /// The objects of one registration test.
  struct Fixture {
    /// The target of the card.
    let target: SideCardTarget
    /// The target of the thread around the card. The card holds it weakly,
    /// so the fixture keeps it.
    let thread: AgentCommandTarget
    /// The registry with the scope of the card.
    var registry: CommandRegistry
    /// The path of the scope of the card.
    let path: FocusPath
    /// The calls of the actions.
    let log: ActionLog
  }

  /// The path of the thread scope that shows the card.
  static var threadPath: FocusPath {
    .root(FocusSegment(kind: AgentScopeKind.thread, id: threadID))
  }

  /// Makes the fork of a card: a preview session model with the question
  /// and the answer.
  ///
  /// - Returns: The session model.
  static func makeFork() -> SessionModel {
    .preview(transcript: [.user(question), .agent(answer)])
  }

  /// Registers the verbs of a card for `fork` in the scope of a thread.
  ///
  /// - Parameters:
  ///   - fork: The session model of the fork.
  ///   - hostSends: Whether the host gives the Send to Chat action. With no
  ///     host action, the card inserts the text in the composer of the
  ///     thread.
  ///   - groupsOff: The groups that the registration does not register.
  /// - Returns: The fixture.
  static func makeFixture(
    fork: SessionModel = makeFork(), hostSends: Bool = false,
    groupsOff: Set<AgentCommandGroup> = []
  ) -> Fixture {
    let log = ActionLog()
    let target = SideCardTarget()
    target.question = question
    target.session = fork
    target.open = { log.opens += 1 }
    target.close = { log.closes += 1 }
    if hostSends {
      target.hostSend = { log.sent.append($0) }
    }
    let thread = makeThreadTarget(log: log)
    target.thread = thread
    let segment = AgentScopeKind.sideCard(fork.sessionId)
    let path = threadPath.appending(segment)
    var registry = CommandRegistry()
    registry.tree = registry.tree.merging(
      { $0.contributeSubject(segment, fork) }, by: .scope, at: path)
    SideCardRegistration.register(target, at: path, into: &registry, groupsOff: groupsOff)
    return Fixture(target: target, thread: thread, registry: registry, path: path, log: log)
  }

  /// Makes the thread target of a fixture, with a composer hook that writes
  /// to `log`.
  ///
  /// - Parameter log: The log of the calls.
  /// - Returns: The target.
  static func makeThreadTarget(log: ActionLog) -> AgentCommandTarget {
    let thread = AgentCommandTarget()
    thread.composer = AgentComposerHook(
      owner: ObjectIdentifier(thread), canSubmit: { true }, submit: { log.submits += 1 },
      load: { _ in },
      focus: {
        log.focuses += 1
        return true
      },
      insert: { log.inserted.append($0) })
    return thread
  }

  // MARK: - Verbs

  @Test func eachVerbHasTheKitPrefix() {
    CommandTestSupport.expectKitPrefix(of: SideCardVerb.allCases, id: \.id)
  }

  @Test func eachVerbHasItsTitle() {
    #expect(SideCardVerb.allCases.map(\.title) == ["Send to Chat", "Open", "Close"])
  }

  @Test func eachVerbIsInTheSideCardGroup() {
    #expect(SideCardVerb.allCases.allSatisfy { $0.group == .sideCard })
    #expect(AgentCommandGroup.sideCard.id == "agent.sideCard")
    #expect(AgentCommandGroup.sideCard.sideCardVerbs == SideCardVerb.allCases)
  }

  @Test func theVerbsAreInTheSessionMenuAndTheContextMenuInButtonOrder() {
    let verbs = SideCardVerb.allCases

    #expect(verbs.allSatisfy { $0.menu.path == .session })
    #expect(verbs.map(\.menu.order) == verbs.indices.map(Double.init))
    #expect(verbs.map(\.contextMenu.order) == verbs.indices.map(Double.init))
  }

  @Test func closeHasTheSymbolOfDismiss() {
    #expect(SideCardVerb.closeSideCard.icon == EditorSymbol.action(.dismiss).systemImage)
  }

  // MARK: - Registration

  @Test func eachVerbIsInTheRegistryAtThePathOfTheCard() {
    let fixture = Self.makeFixture()

    let ids = fixture.registry.definitions(at: fixture.path).map(\.id)

    #expect(Set(ids) == Set(SideCardVerb.allCases.map(\.id)))
    #expect(ids.count == SideCardVerb.allCases.count)
  }

  @Test func noVerbIsInTheRegistryAtThePathOfTheThread() {
    let fixture = Self.makeFixture()

    #expect(fixture.registry.definitions(at: Self.threadPath).isEmpty)
  }

  @Test func theContextMenuOfACardShowsTheThreeVerbsAndNoThreadVerb() {
    var fixture = Self.makeFixture()
    let thread = AgentCommandTarget()
    thread.session = SessionModel.preview(requestSender: PreviewSessionRequestSender())
    AgentCommandRegistration.register(thread, at: Self.threadPath, into: &fixture.registry)

    let ids = fixture.registry.contextMenuMirror(at: fixture.path).map(\.id)

    #expect(ids == SideCardVerb.allCases.map(\.id))
  }

  @Test func aGroupThatIsOffRegistersNoVerb() {
    let fixture = Self.makeFixture(groupsOff: [.sideCard])

    #expect(fixture.registry.definitions(at: fixture.path).isEmpty)
  }

  @Test func theDeregistrationRemovesEachVerb() {
    var fixture = Self.makeFixture()

    SideCardRegistration.deregister(at: fixture.path, from: &fixture.registry)

    #expect(fixture.registry.definitions(at: fixture.path).isEmpty)
  }

  /// Escape stops the agent in a thread. On a focused card, the card is
  /// nearer than the thread, so Escape closes the card.
  @Test func escapeOnAFocusedCardRunsClose() {
    var fixture = Self.makeFixture()
    let thread = AgentCommandTarget()
    thread.session = SessionModel.preview(requestSender: PreviewSessionRequestSender())
    AgentCommandRegistration.register(thread, at: Self.threadPath, into: &fixture.registry)

    let resolved = fixture.registry.resolveKey(
      KeyChord.escape.asSequence, mode: .cua, at: fixture.path)

    #expect(resolved == .command(SideCardVerb.closeSideCard.id, scope: fixture.path))
  }

  // MARK: - Runs

  @Test func sendToChatInsertsTheTextInTheComposerOfTheThreadWithNoSend() {
    let fixture = Self.makeFixture()

    #expect(fixture.registry.perform(SideCardVerb.sendSideCardToChat.id, at: fixture.path))

    #expect(fixture.log.inserted == [Self.chatText])
    #expect(fixture.log.submits == 0)
  }

  @Test func sendToChatFocusesTheComposer() {
    let fixture = Self.makeFixture()

    #expect(fixture.registry.perform(SideCardVerb.sendSideCardToChat.id, at: fixture.path))

    #expect(fixture.log.focuses == 1)
  }

  @Test func sendToChatGivesTheTextToTheHostAction() {
    let fixture = Self.makeFixture(hostSends: true)

    #expect(fixture.registry.perform(SideCardVerb.sendSideCardToChat.id, at: fixture.path))

    #expect(fixture.log.sent == [Self.chatText])
    #expect(fixture.log.inserted.isEmpty)
  }

  @Test func openRunsTheOpenActionOfTheCard() {
    let fixture = Self.makeFixture()

    #expect(fixture.registry.perform(SideCardVerb.openSideCard.id, at: fixture.path))

    #expect(fixture.log.opens == 1)
  }

  @Test func closeRunsTheCloseActionOfTheCard() {
    let fixture = Self.makeFixture()

    #expect(fixture.registry.perform(SideCardVerb.closeSideCard.id, at: fixture.path))

    #expect(fixture.log.closes == 1)
  }

  // MARK: - Availability

  @Test func sendToChatIsNotAvailableWithNoComposerAndNoHostAction() throws {
    let fixture = Self.makeFixture()
    fixture.target.thread = nil

    #expect(
      try CommandTestSupport.availability(
        of: SideCardVerb.sendSideCardToChat.id, at: fixture.path, in: fixture.registry)
        == .unavailable(reason: "The composer is not shown."))
  }

  @Test func sendToChatIsNotAvailableBeforeTheAnswer() throws {
    let fixture = Self.makeFixture(fork: .preview(transcript: [.user(Self.question)]))

    #expect(
      try CommandTestSupport.availability(
        of: SideCardVerb.sendSideCardToChat.id, at: fixture.path, in: fixture.registry)
        == .unavailable(reason: "The side question has no answer yet."))
  }

  @Test func sendToChatAndCloseAreNotAvailableWhileTheForkNeedsInput() throws {
    let fork = SessionModel.preview(
      transcript: [.user(Self.question)],
      pendingElicitations: [try SideQuestionCardTests.elicitation])
    let fixture = Self.makeFixture(fork: fork)
    let reason = Availability.unavailable(
      reason: "The side question needs input. Open it to answer.")

    #expect(
      try CommandTestSupport.availability(
        of: SideCardVerb.sendSideCardToChat.id, at: fixture.path, in: fixture.registry) == reason)
    #expect(
      try CommandTestSupport.availability(
        of: SideCardVerb.closeSideCard.id, at: fixture.path, in: fixture.registry) == reason)
    #expect(
      try CommandTestSupport.availability(
        of: SideCardVerb.openSideCard.id, at: fixture.path, in: fixture.registry) == .available)
  }
}
