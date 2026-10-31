@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import AgentViewKitDemoSupport
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the agent command scope in a window: the registration of a
/// mounted thread view, and the composer that runs the commands.
///
/// A change that the test makes on the main actor is followed by one render
/// pass. A frame of the agent is followed by a wait for the model value that
/// the frame is certain to change, and then by one render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentCommandScopeHostedTests {
  /// The text that the composer tests send.
  static let message = "Hello"

  /// The size of a window that shows a thread and a composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The number of verbs of the kit.
  static let verbCount = 13

  /// The JSON-RPC id of the permission request that the scripted agent sends.
  static let agentRequestID = 100

  /// The `allow_once` option of ``ScriptedSession/permissionParams``.
  static let allowOptionID = "yes"

  /// The position of the second user message in the transcript of the jump
  /// test.
  static let secondUserMessagePosition = 2

  /// A size that shows each row of the jump test.
  static let tallSize = CGSize(width: 480, height: 1_200)

  /// The path of the scope of a session model at the root of a window.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The path.
  static func path(of model: SessionModel) -> FocusPath {
    .root(AgentCommandTarget.segment(for: model))
  }

  /// Shows the thread view of a session and its connection model, with a
  /// composer in the composer slot when the test gives one, and the deck of
  /// the session below it, in one focus scope, with a command system and a
  /// pasteboard. With no composer, the slot is empty.
  ///
  /// The composer reads the session model from the environment, so that a
  /// submit sends a prompt to the agent.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  ///   - outerScope: `true` to put the thread view in an agent command scope
  ///     of the session that the host applies. `false` to apply no outer
  ///     scope, so that only the scope of ``AgentThreadView`` itself
  ///     registers the commands.
  ///   - composer: The text of the composer, or `nil` for no composer.
  ///   - pasteboard: The pasteboard of the copy command, one of
  ///     `NSPasteboard.withIsolated(_:)`, or `nil` for a test that copies
  ///     nothing.
  ///   - requestStartReport: The report that gets the method of each request
  ///     that a view starts, or `nil`.
  ///   - submitReport: The report that gets each submit outcome of the
  ///     composer, or `nil`.
  ///   - answerReport: The report that gets each answer of a permission
  ///     card of the deck, or `nil`.
  ///   - isFocusEffectEnabled: `false` to apply `.focusEffectDisabled()`
  ///     above the views, as a host does to turn off each focus ring.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, system: CommandSystem, outerScope: Bool,
    composer: PromptInputHostedTestModel? = nil, pasteboard: NSPasteboard? = nil,
    requestStartReport: ObservationReport<String>? = nil,
    submitReport: ObservationReport<PromptSubmitOutcome>? = nil,
    answerReport: ObservationReport<PermissionAnswer>? = nil,
    isFocusEffectEnabled: Bool = true
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: windowSize) {
      scoped(
        VStack {
          AgentThreadView(session: session.model, connection: session.connection) {
            if let composer {
              PromptInputHost(model: composer)
            }
          }
          RequestDeck(session: session.model)
        }
        .accessibilityFocusScope(),
        in: outerScope ? session.model : nil
      )
      .focusEffectDisabled(!isFocusEffectEnabled)
      .environment(\.sessionModel, session.model)
      .transformEnvironment(\.pasteboard) { if let pasteboard { $0 = pasteboard } }
      .environment(\.requestStartReport, requestStartReport)
      .environment(\.promptSubmitReport, submitReport)
      .environment(\.permissionAnswerReport, answerReport)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// Puts `content` in the agent command scope of `session`, or leaves it as
  /// it is when `session` is `nil`.
  ///
  /// - Parameters:
  ///   - content: The view to put in the scope.
  ///   - session: The session model of the scope, or `nil` for no scope.
  /// - Returns: The view.
  @ViewBuilder static func scoped(_ content: some View, in session: SessionModel?) -> some View {
    if let session {
      content.agentCommandScope(session: session)
    } else {
      content
    }
  }

  /// One text message that the agent sends as one chunk.
  struct ChunkMessage {
    /// The `sessionUpdate` tag, such as `user_message_chunk`.
    let kind: String
    /// The `messageId` of the message.
    let messageID: String
    /// The text of the message.
    let text: String
  }

  /// Sends each message from the agent as one text chunk, in order.
  ///
  /// - Parameters:
  ///   - messages: The messages.
  ///   - session: The scripted session.
  /// - Throws: The error of the transport.
  static func send(_ messages: [ChunkMessage], to session: ScriptedSession) async throws {
    for message in messages {
      try await session.sendUpdate(
        WireBlockJSON.makeChunk(
          message.kind, messageID: message.messageID, block: WireBlockJSON.makeText(message.text)))
    }
  }

  /// Sends one user message from the agent, waits until the transcript of
  /// the session holds it, and then renders `harness`. The scroll and expand
  /// commands act only on a transcript with an entry.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The mount that renders the view after the wait: a
  ///     `HostedViewHarness` or a `CaptureMount`.
  /// - Throws: The error of the transport.
  static func sendScopeMessage(
    to session: ScriptedSession, rendering harness: some RenderedMount
  ) async throws {
    try await send([ChunkMessage(kind: "user_message_chunk", messageID: "scope-message", text: message)], to: session)
    let model = session.model
    await harness.render { !model.transcript.isEmpty }
  }

  /// Sends a `state_update` from the agent, waits until the agent state of
  /// the session model changes, and then renders `harness`.
  ///
  /// The update must differ from the agent state of the model, so that its
  /// fold is certain to change the state.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update, such as
  ///     ``ScriptedSession/runningState``.
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Throws: The error of the transport.
  static func sendState(
    _ update: String, to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws {
    let model = session.model
    let before = model.agentState
    try await session.sendUpdate(update)
    await harness.render { model.agentState != before }
  }

  /// The test mounts no outer agent command scope on purpose. The session
  /// path of ``AgentThreadView`` applies the scope itself, and this test
  /// proves it. An outer scope from the host would register the same
  /// commands, and then the test would not find a thread view that lost its
  /// own scope.
  ///
  /// The scope is the root of the window, so EditorKit also registers the
  /// window undo commands there. The test counts the commands of the kit
  /// apart from them.
  @Test func aMountedSessionThreadViewRegistersTheThirteenCommands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    try await Self.sendScopeMessage(to: session, rendering: harness)

    let path = Self.path(of: session.model)
    let ids = WindowUndoChecks.kitCommandIDs(at: path, in: system)
    #expect(ids.count == Self.verbCount)
    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: path, in: system)
    #expect(system.registry.tree.nodes.contains { $0.path == path })
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: path))
    #expect(system.registry.perform(AgentCommandVerb.toggleExpandAll.id, at: path))
  }

  /// The host turns off a group around a thread view with no outer scope, so
  /// the scope that ``AgentThreadView`` applies itself reads the groups. The
  /// groups do not reach the window undo commands that EditorKit registers
  /// at the same root.
  @Test func aMountedThreadViewDoesNotRegisterTheVerbsOfAGroupThatTheHostTurnsOff() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = HostedViewHarness(size: Self.windowSize) {
      AgentThreadView(session: session.model)
        .agentCommandGroups(off: [.navigate])
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.render()
    let path = Self.path(of: session.model)

    let ids = WindowUndoChecks.kitCommandIDs(at: path, in: system)

    #expect(ids == Set(AgentCommandVerb.allCases.filter { $0.group != .navigate }.map(\.id)))
    try WindowUndoChecks.expectUnavailableOnAnEmptyStack(at: path, in: system)
  }

  @Test func aSessionThreadViewInAScopeForItsSessionAddsItsPartsToThatScope() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    try await Self.sendScopeMessage(to: session, rendering: harness)

    // The message rows add item scopes below the thread scope, so the test
    // keeps only the nodes whose last segment is a thread segment.
    let scopes = system.registry.tree.nodes.filter {
      $0.path.segments.last?.kind == AgentCommandTarget.segmentKind
    }
    #expect(scopes.map(\.path) == [Self.path(of: session.model)])
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: Self.path(of: session.model)))
  }

  @Test func sendSubmitsTheComposerInTheScopeOfASessionAsAPrompt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let composer = PromptInputHostedTestModel()
    let submits = ReportRecorder<PromptSubmitOutcome>()
    let harness = Self.mount(
      session: session, system: system, outerScope: true, composer: composer, submitReport: submits.report)
    defer { harness.close() }
    harness.render()
    let path = Self.path(of: session.model)

    #expect(!system.registry.perform(AgentCommandVerb.send.id, at: path))
    composer.text = AttributedString(Self.message)
    harness.render()
    try #require(system.registry.perform(AgentCommandVerb.send.id, at: path))
    // The composer starts the prompt in the same step as the dispatch, so a
    // dispatch that started nothing stops the test here.
    try #require(submits.values == [.sent])
    let agent = session.agent
    await ObservationWait.until { !agent.messages(method: ScriptedSession.promptMethod).isEmpty }

    let prompts = agent.messages(method: ScriptedSession.promptMethod)
    #expect(prompts.map(ScriptedWireAgent.promptText(of:)) == [Self.message])
    #expect(composer.plainText.isEmpty)
    #expect(composer.submitCount == 1)
  }

  @Test func theSubmitButtonOfTheComposerRunsTheSendCommand() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = HostedViewHarness(size: Self.windowSize) {
      PromptInputHost(model: model)
        .agentCommandScope(session: session.model)
        .environment(\.sessionModel, session.model)
    }
    defer { harness.close() }
    harness.render()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    // The composer calls the host closure in the same step as it starts the
    // prompt task, so a press that sent nothing stops the test here.
    try #require(model.submitCount == 1)
    await ObservationWait.until { !session.promptTexts.isEmpty }

    #expect(session.promptTexts == [Self.message])
    #expect(model.submitCount == 1)
  }

  @Test func focusComposerMovesTheFocusToTheEditorInTheScopeOfASession() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(
      session: session, system: system, outerScope: true, composer: PromptInputHostedTestModel())
    defer { harness.close() }
    harness.render()
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    harness.window.makeFirstResponder(nil)
    harness.render()

    #expect(system.registry.perform(AgentCommandVerb.focusComposer.id, at: Self.path(of: session.model)))
    harness.render()

    #expect(harness.window.firstResponder === editor)
  }

  @Test func theScopeOfASessionRemovesItsNodeWhenTheViewGoesAway() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let model = ScopeVisibilityModel()
    let harness = HostedViewHarness(size: Self.windowSize) {
      ScopeVisibilityHost(model: model, session: session.model)
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.render()
    let path = Self.path(of: session.model)
    #expect(system.registry.tree.nodes.contains { $0.path == path })

    model.isShown = false
    harness.render()

    #expect(!system.registry.tree.nodes.contains { $0.path == path })
  }

  /// SwiftUI makes the new thread view of a rebuilt chat, and registers its
  /// path, before it dismantles the old thread view at the same path. The
  /// teardown of the old view must keep the registration of the new view.
  ///
  /// The teardown of the old view clears the store of the expanded items of
  /// the old target, so `toggleExpandAll` acts only through the target of
  /// the new view.
  @Test func theTeardownOfAnOldThreadViewKeepsTheCommandsOfANewThreadViewAtTheSamePath() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let model = ScopeRebuildModel()
    let harness = HostedViewHarness(size: Self.windowSize) {
      ScopeRebuildHost(model: model, session: session.model)
        .commandSystem(system)
    }
    defer { harness.close() }
    try await Self.sendScopeMessage(to: session, rendering: harness)
    let path = Self.path(of: session.model)

    model.generation += 1
    harness.render()

    #expect(system.registry.tree.nodes.contains { $0.path == path })
    let eligible = Set(system.registry.eligible(path: path).map(\.id))
    #expect(eligible.isSuperset(of: [AgentCommandVerb.send.id, AgentCommandVerb.focusComposer.id]))
    #expect(system.registry.perform(AgentCommandVerb.toggleExpandAll.id, at: path))
  }

  /// Two windows show a thread view of one session, so both register at the
  /// same path. When the newer window closes, the path goes back to the
  /// older window on the next pass of the main run loop, with no update of
  /// the older window.
  ///
  /// The teardown of the newer window clears the store of the expanded items
  /// of its own target, so `toggleExpandAll` acts only through the target of
  /// the older window.
  @Test func closingTheNewerOfTwoWindowsAtOnePathHandsTheCommandsBackToTheOlderWindow() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let older = SwitchedWindow(AgentThreadView(session: session.model), system: system, size: Self.windowSize)
    defer { older.harness.close() }
    let newer = SwitchedWindow(AgentThreadView(session: session.model), system: system, size: Self.windowSize)
    try await Self.sendScopeMessage(to: session, rendering: older.harness)
    newer.harness.render()
    let path = Self.path(of: session.model)

    await newer.close()

    #expect(WindowUndoChecks.kitCommandIDs(at: path, in: system).count == Self.verbCount)
    let eligible = Set(system.registry.eligible(path: path).map(\.id))
    #expect(eligible.isSuperset(of: [AgentCommandVerb.send.id, AgentCommandVerb.focusComposer.id]))
    #expect(system.registry.perform(AgentCommandVerb.toggleExpandAll.id, at: path))
  }

  /// The host moves a thread view under another outer scope, so the path of
  /// its scope changes with no new mount. The mount leaves its old path
  /// before it registers at the new one.
  @Test func aThreadViewThatMovesToAnotherPathLeavesItsOldPath() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let model = ScopeMoveModel()
    let harness = HostedViewHarness(size: Self.windowSize) {
      ScopeMoveHost(model: model, session: session.model)
        .commandSystem(system)
    }
    defer { harness.close() }
    harness.render()
    let thread = AgentCommandTarget.segment(for: session.model)
    let oldPath = FocusPath.root(ScopeMoveModel.firstOuterSegment).appending(thread)
    try #require(system.registry.definitions(at: oldPath).count == Self.verbCount)

    model.outerSegment = ScopeMoveModel.secondOuterSegment
    harness.render()

    #expect(system.registry.definitions(at: oldPath).isEmpty)
    let newPath = FocusPath.root(ScopeMoveModel.secondOuterSegment).appending(thread)
    #expect(system.registry.definitions(at: newPath).count == Self.verbCount)
  }

  // MARK: - Session model

  @Test func theCancelCommandOfASessionSendsSessionCancelWhileTheAgentRuns() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, system: system, outerScope: false, requestStartReport: starts.report)
    defer { harness.close() }
    harness.render()
    let path = Self.path(of: session.model)

    #expect(!system.registry.perform(AgentCommandVerb.cancel.id, at: path))
    try await Self.sendState(ScriptedSession.runningState, to: session, rendering: harness)
    try #require(system.registry.perform(AgentCommandVerb.cancel.id, at: path))
    // The command starts the cancel in the same step as the dispatch, so a
    // dispatch that started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.cancelMethod])
    let agent = session.agent
    await ObservationWait.until { !agent.messages(method: ScriptedSession.cancelMethod).isEmpty }

    let cancels = agent.messages(method: ScriptedSession.cancelMethod)
    #expect(cancels.count == 1)
    #expect(cancels.first?["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)

    try await Self.sendState(ScriptedSession.idleState, to: session, rendering: harness)
    #expect(!system.registry.perform(AgentCommandVerb.cancel.id, at: path))
  }

  @Test func theApproveCommandOfASessionSendsTheFirstAllowOptionAndTheCardGoesAway() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let starts = ReportRecorder<String>()
    let harness = Self.mount(session: session, system: system, outerScope: false, requestStartReport: starts.report)
    defer { harness.close() }
    let pending = try await session.sendPermissionRequest(id: Self.agentRequestID, rendering: harness)
    let card = RequestDeck.identifier(for: pending.uuidString)
    #expect(harness.element(identifier: card) != nil)

    try #require(system.registry.perform(AgentCommandVerb.approvePending.id, at: Self.path(of: session.model)))
    // The command starts the answer in the same step as the dispatch, so a
    // dispatch that started nothing stops the test here.
    try #require(starts.values == [ScriptedSession.permissionMethod])
    let result = await session.result(ofRequest: Self.agentRequestID)
    let model = session.model
    await harness.render { model.pendingPermissions.isEmpty }

    #expect(result?["outcome"]?["optionId"]?.stringValue == Self.allowOptionID)
    #expect(model.pendingPermissions.isEmpty)
    #expect(harness.element(identifier: card) == nil)
  }

  @Test func theCopyCommandOfASessionCopiesTheMessageEntriesInTranscriptOrder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    try await NSPasteboard.withIsolatedAsync { pasteboard in
      let harness = Self.mount(session: session, system: system, outerScope: false, pasteboard: pasteboard)
      defer { harness.close() }
      let messages = [
        ChunkMessage(kind: "user_message_chunk", messageID: "copy-u1", text: "Hi."),
        ChunkMessage(kind: "agent_message_chunk", messageID: "copy-m1", text: "Hello."),
        ChunkMessage(kind: "user_message_chunk", messageID: "copy-u2", text: "Again."),
      ]
      try await Self.send(messages, to: session)
      let model = session.model
      await harness.render { model.transcript.count == messages.count }

      #expect(system.registry.perform(AgentCommandVerb.copyThread.id, at: Self.path(of: model)))

      #expect(pasteboard.string(forType: .string) == "User:\nHi.\n\nAssistant:\nHello.\n\nUser:\nAgain.")
    }
  }

  /// The reaction of the jump command of a session to a given visibility
  /// report: the command goes from the first row of the report to the next
  /// user message, and the manager keeps that entry as its anchor.
  ///
  /// After the model has the four messages, one layout pass shows the four
  /// rows in the tall window. The test then gives the manager the
  /// visibility report of the four rows itself, in transcript order, as
  /// `ConversationView` gives it. It does not wait for the report of
  /// SwiftUI: SwiftUI sends it on a later update, and for the off-screen
  /// harness window it can send no report. A wait for it holds the key
  /// window gate of EditorKit (`.hostedSerially`) and stops all hosted tests
  /// of the process.
  ///
  /// The command sets the anchor; the given report does not set it. The
  /// test does not check the rows in view that the manager keeps, because
  /// the given report writes them.
  ///
  /// Gap: the test gives the report to the manager itself.
  /// ``ConversationViewHostedTests/aScrollUpMakesTheListReportItsRowsAndShowThePill()``
  /// checks that the list sends the report.
  @Test func theJumpCommandOfASessionAnchorsTheNextUserMessageOfAGivenReport() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let anchors = ScrollAnchorManager()
    let harness = HostedViewHarness(size: Self.tallSize) {
      ConversationView(session: model, anchors: anchors)
        .agentCommandScope(session: model, anchors: anchors)
        .commandSystem(system)
    }
    defer { harness.close() }
    let messages = [
      ChunkMessage(kind: "user_message_chunk", messageID: "jump-u1", text: "First?"),
      ChunkMessage(kind: "agent_message_chunk", messageID: "jump-m1", text: "One."),
      ChunkMessage(kind: "user_message_chunk", messageID: "jump-u2", text: "Second?"),
      ChunkMessage(kind: "agent_message_chunk", messageID: "jump-m2", text: "Two."),
    ]
    try await Self.send(messages, to: session)
    await ObservationWait.until { model.transcript.count == messages.count }
    harness.hostingView.layoutSubtreeIfNeeded()
    let keys = model.transcript.map(\.rowKey)
    #expect(keys.allSatisfy { harness.element(identifier: ItemRow.identifier(for: $0)) != nil })
    anchors.noteVisible(ids: keys)

    #expect(system.registry.perform(AgentCommandVerb.jumpToNext.id, at: Self.path(of: model)))

    let secondUserMessage = try #require(keys.dropFirst(Self.secondUserMessagePosition).first)
    #expect(anchors.anchorID == secondUserMessage)
  }
}

/// Tells if ``ScopeVisibilityHost`` shows its thread view.
@Observable final class ScopeVisibilityModel {
  /// `true` while the host shows the thread view.
  var isShown = true
}

/// A host that shows a thread view while its model tells it to.
struct ScopeVisibilityHost: View {
  /// The model that tells if the thread view shows.
  let model: ScopeVisibilityModel

  /// The session model of the thread view.
  let session: SessionModel

  var body: some View {
    if model.isShown {
      AgentThreadView(session: session)
    } else {
      Color.clear
    }
  }
}

/// Tells ``ScopeMoveHost`` which outer scope holds its thread view.
@Observable final class ScopeMoveModel {
  /// The outer segment that the host starts with.
  static let firstOuterSegment = FocusSegment(kind: "pane", id: "first")

  /// The outer segment that the move test gives next.
  static let secondOuterSegment = FocusSegment(kind: "pane", id: "second")

  /// The segment of the outer scope of the thread view.
  var outerSegment = firstOuterSegment
}

/// A host that shows one thread view under an outer scope whose segment its
/// model gives. A new segment changes the path of the thread scope, and keeps
/// the same views.
struct ScopeMoveHost: View {
  /// The model that gives the outer segment.
  let model: ScopeMoveModel

  /// The session model of the thread view.
  let session: SessionModel

  var body: some View {
    AgentThreadView(session: session)
      .commandScope(segment: model.outerSegment)
  }
}

/// Tells ``ScopeRebuildHost`` when to rebuild its thread view.
@Observable final class ScopeRebuildModel {
  /// The identity of the thread view. A new value rebuilds the view.
  var generation = 0
}

/// A host that rebuilds its thread view with a new identity for the same
/// session each time its model gives a new generation, as Swap Chat and View
/// rebuilds a chat.
struct ScopeRebuildHost: View {
  /// The model that gives the identity of the thread view.
  let model: ScopeRebuildModel

  /// The session model of the thread view.
  let session: SessionModel

  var body: some View {
    AgentThreadView(session: session)
      .id(model.generation)
  }
}
