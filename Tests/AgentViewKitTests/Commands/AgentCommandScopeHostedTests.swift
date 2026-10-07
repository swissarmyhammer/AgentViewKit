@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import DemoSupport
import EditorCommands
import EditorCommandsUI
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the agent command scope in a window: the registration of a
/// mounted thread view, and the composer that runs the commands.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentCommandScopeHostedTests {
  /// The text that the composer tests send.
  static let message = "Hello"

  /// The size of a window that shows a thread and a composer.
  static let windowSize = CGSize(width: 480, height: 480)

  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The number of verbs of the kit.
  static let verbCount = 10

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
    .root(AgentCommandTarget.segment(for: .session(model)))
  }

  /// Shows the thread view of a session and its connection model, and a
  /// composer below it when the test gives one, with a command system and a
  /// pasteboard.
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
  ///   - pasteboard: The pasteboard of the copy command.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, system: CommandSystem, outerScope: Bool,
    composer: PromptInputHostedTestModel? = nil, pasteboard: FakePasteboard = FakePasteboard()
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: windowSize) {
      scoped(
        VStack {
          AgentThreadView(session: session.model, connection: session.connection, actions: NoopThreadActions())
          if let composer {
            PromptInputHost(model: composer)
          }
        },
        in: outerScope ? session.model : nil
      )
      .environment(\.sessionModel, session.model)
      .environment(\.pasteboard, pasteboard)
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

  /// Sends one user message from the agent, and pumps `harness` until the
  /// transcript of the session holds it. The scroll and expand commands act
  /// only on a transcript with an entry.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness to pump while the test waits.
  /// - Throws: The error of the transport.
  static func sendScopeMessage(
    to session: ScriptedSession, pumping harness: HostedViewHarness<some View>
  ) async throws {
    try await send([ChunkMessage(kind: "user_message_chunk", messageID: "scope-message", text: message)], to: session)
    await harness.pump(until: waitTimeout) { !session.model.transcript.isEmpty }
    harness.pump()
  }

  /// Sends a `state_update` from the agent, and pumps `harness` until the
  /// agent state of the session model changes.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update, such as
  ///     ``ScriptedSession/runningState``.
  ///   - session: The scripted session.
  ///   - harness: The harness to pump while the test waits.
  /// - Throws: The error of the transport.
  static func sendState(
    _ update: String, to session: ScriptedSession, pumping harness: HostedViewHarness<some View>
  ) async throws {
    let before = session.model.agentState
    try await session.sendUpdate(update)
    await harness.pump(until: waitTimeout) { session.model.agentState != before }
  }

  /// The test mounts no outer agent command scope on purpose. The session
  /// path of ``AgentThreadView`` applies the scope itself, and this test
  /// proves it. An outer scope from the host would register the same
  /// commands, and then the test would not find a thread view that lost its
  /// own scope.
  @Test func aMountedSessionThreadViewRegistersTheTenCommands() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    try await Self.sendScopeMessage(to: session, pumping: harness)

    let path = Self.path(of: session.model)
    let ids = Set(system.registry.definitions(at: path).map(\.id))
    #expect(ids.count == Self.verbCount)
    #expect(system.registry.tree.nodes.contains { $0.path == path })
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: path))
    #expect(system.registry.perform(AgentCommandVerb.toggleExpandAll.id, at: path))
  }

  @Test func aSessionThreadViewInAScopeForItsSessionAddsItsPartsToThatScope() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    try await Self.sendScopeMessage(to: session, pumping: harness)

    let scopes = system.registry.tree.nodes.filter {
      $0.path.segments.contains { $0.kind == AgentCommandTarget.segmentKind }
    }
    #expect(scopes.map(\.path) == [Self.path(of: session.model)])
    #expect(system.registry.perform(AgentCommandVerb.scrollToBottom.id, at: Self.path(of: session.model)))
  }

  @Test func sendSubmitsTheComposerInTheScopeOfASessionAsAPrompt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let composer = PromptInputHostedTestModel()
    let harness = Self.mount(session: session, system: system, outerScope: true, composer: composer)
    defer { harness.close() }
    harness.pump()
    let path = Self.path(of: session.model)

    #expect(!system.registry.perform(AgentCommandVerb.send.id, at: path))
    composer.text = AttributedString(Self.message)
    harness.pump()
    #expect(system.registry.perform(AgentCommandVerb.send.id, at: path))
    await harness.pump(until: Self.waitTimeout) {
      !session.agent.messages(method: ScriptedSession.promptMethod).isEmpty
    }

    let prompts = session.agent.messages(method: ScriptedSession.promptMethod)
    #expect(prompts.map(ScriptedWireAgent.promptText(of:)) == [Self.message])
    #expect(composer.plainText.isEmpty)
    #expect(composer.submitCount == 1)
  }

  @Test func theSubmitButtonOfTheComposerRunsTheSendCommand() async throws {
    let thread = AgentThread()
    let actions = NoopThreadActions()
    let model = PromptInputHostedTestModel(text: Self.message)
    let harness = threadViewHarness(size: Self.windowSize, actions: actions, thread: thread) {
      PromptInputHost(model: model)
        .agentCommandScope(thread: thread)
    }
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.message))])
    #expect(model.submitCount == 1)
  }

  @Test func focusComposerMovesTheFocusToTheEditorInTheScopeOfASession() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(
      session: session, system: system, outerScope: true, composer: PromptInputHostedTestModel())
    defer { harness.close() }
    harness.pump()
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    harness.window.makeFirstResponder(nil)
    harness.pump()

    #expect(system.registry.perform(AgentCommandVerb.focusComposer.id, at: Self.path(of: session.model)))
    harness.pump()

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
    harness.pump()
    let path = Self.path(of: session.model)
    #expect(system.registry.tree.nodes.contains { $0.path == path })

    model.isShown = false
    harness.pump()

    #expect(!system.registry.tree.nodes.contains { $0.path == path })
  }

  // MARK: - Session model

  @Test func theCancelCommandOfASessionSendsSessionCancelWhileTheAgentRuns() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    harness.pump()
    let path = Self.path(of: session.model)

    #expect(!system.registry.perform(AgentCommandVerb.cancel.id, at: path))
    try await Self.sendState(ScriptedSession.runningState, to: session, pumping: harness)
    #expect(system.registry.perform(AgentCommandVerb.cancel.id, at: path))
    await harness.pump(until: Self.waitTimeout) {
      !session.agent.messages(method: ScriptedSession.cancelMethod).isEmpty
    }

    let cancels = session.agent.messages(method: ScriptedSession.cancelMethod)
    #expect(cancels.count == 1)
    #expect(cancels.first?["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)

    try await Self.sendState(ScriptedSession.idleState, to: session, pumping: harness)
    #expect(!system.registry.perform(AgentCommandVerb.cancel.id, at: path))
  }

  @Test func theApproveCommandOfASessionSendsTheFirstAllowOptionAndTheCardGoesAway() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    let pending = try await session.sendPermissionRequest(
      id: Self.agentRequestID, pumping: harness, timeout: Self.waitTimeout)
    let card = PendingRequestsHost.identifier(for: try #require(pending).uuidString)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: card) != nil }

    #expect(system.registry.perform(AgentCommandVerb.approvePending.id, at: Self.path(of: session.model)))
    await harness.pump(until: Self.waitTimeout) { session.agent.response(to: Double(Self.agentRequestID)) != nil }
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: card) == nil }

    let response = try #require(session.agent.response(to: Double(Self.agentRequestID)))
    #expect(response["result"]?["outcome"]?["optionId"]?.stringValue == Self.allowOptionID)
    #expect(session.model.pendingPermissions.isEmpty)
    #expect(harness.element(identifier: card) == nil)
  }

  @Test func theCopyCommandOfASessionCopiesTheMessageEntriesInTranscriptOrder() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let pasteboard = FakePasteboard()
    let harness = Self.mount(session: session, system: system, outerScope: false, pasteboard: pasteboard)
    defer { harness.close() }
    let messages = [
      ChunkMessage(kind: "user_message_chunk", messageID: "copy-u1", text: "Hi."),
      ChunkMessage(kind: "agent_message_chunk", messageID: "copy-m1", text: "Hello."),
      ChunkMessage(kind: "user_message_chunk", messageID: "copy-u2", text: "Again."),
    ]
    try await Self.send(messages, to: session)
    await harness.pump(until: Self.waitTimeout) { session.model.transcript.count == messages.count }

    #expect(system.registry.perform(AgentCommandVerb.copyThread.id, at: Self.path(of: session.model)))

    #expect(pasteboard.contents == "User:\nHi.\n\nAssistant:\nHello.\n\nUser:\nAgain.")
  }

  @Test func theJumpCommandOfASessionGoesToTheNextUserMessageEntry() async throws {
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
    await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.count == messages.count }
    let keys = model.transcript.map(\.rowKey)
    #expect(anchors.visibleIDs.first == keys.first)

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
      AgentThreadView(session: session, actions: NoopThreadActions())
    } else {
      Color.clear
    }
  }
}
