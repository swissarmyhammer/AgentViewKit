#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The composer over a `SessionModel` (update.md §4.2 "Prompt helper", §4.7
  /// "Composer", §5 `PromptResponse.messageId`).
  ///
  /// Each test shows the transcript of the session and a composer below it.
  /// The composer reads the session model from the environment, and it gets
  /// no thread actions, so each request goes through the session model.
  @Suite(.serialized, .hostedSerially) @MainActor struct ComposerSessionModelHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows the transcript and the composer.
    static let size = CGSize(width: 480, height: 800)

    /// The text of the first prompt.
    static let firstMessage = "Hello"

    /// The text of the second prompt.
    static let secondMessage = "And then?"

    /// The method of a prompt request.
    static let promptMethod = "session/prompt"

    /// The method of a cancel notification.
    static let cancelMethod = "session/cancel"

    /// The JSON-RPC code of the error that the scripted agent sends.
    static let scriptedErrorCode = -32603

    /// The `session/update` value that tells that the agent runs.
    static let runningState = #"{"sessionUpdate":"state_update","state":"running"}"#

    /// The `session/update` value that tells that the agent is idle.
    static let idleState = #"{"sessionUpdate":"state_update","state":"idle"}"#

    /// The `messageId` of the agent message that marks the end of the frames
    /// of a prompt.
    static let markerMessageID = "composer-marker"

    /// An `agent_message_chunk` value. The agent sends it after the frames of
    /// a prompt, so that a test knows that the client read those frames.
    static let markerUpdate =
      #"{"sessionUpdate":"agent_message_chunk","messageId":"\#(markerMessageID)","content":{"type":"text","text":"Done."}}"#

    /// The label of the send state of each state.
    static let sendStateLabels: [SendState: String] = [
      .pending: "Sending", .sent: "Sent", .failed: "Not sent",
    ]

    /// Shows the transcript and a composer over a session.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - draft: The model that holds the text of the composer.
    /// - Returns: The harness.
    static func mount(
      session: ScriptedSession, draft: PromptInputHostedTestModel
    ) -> HostedViewHarness<some View> {
      HostedViewHarness(size: size) {
        VStack(spacing: 0) {
          AgentThreadView(session: session.model, actions: NoopThreadActions())
          PromptInputHost(model: draft)
        }
        .environment(\.sessionModel, session.model)
        .transaction { $0.disablesAnimations = true }
      }
    }

    /// The user message entries of a session model, in transcript order.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entries.
    static func userMessages(of model: SessionModel) -> [UserMessageEntry] {
      model.transcript.compactMap { entry in
        if case .userMessage(let message) = entry { message } else { nil }
      }
    }

    /// Tells whether the agent state of a session model is `running`.
    ///
    /// - Parameter model: The session model.
    /// - Returns: `true` when `agentState` is `.running`.
    static func isRunning(_ model: SessionModel) -> Bool {
      if case .running = model.agentState { true } else { false }
    }

    /// The label of the send state of a user message in the view.
    ///
    /// - Parameters:
    ///   - entry: The user message entry.
    ///   - harness: The harness that shows the entry.
    /// - Returns: The label, or `nil` when the view shows no send state.
    static func sendStateLabel<Content: View>(
      of entry: UserMessageEntry, in harness: HostedViewHarness<Content>
    ) -> String? {
      harness.element(identifier: UserMessageView.sendStateIdentifier(for: entry.id.rowKey))?.label
    }

    // MARK: - Send

    @Test(arguments: [ScriptedWireAgent.PromptEchoOrder.beforeResult, .afterResult])
    func aSentPromptShowsAsPendingAtOnceAndThenAsSent(order: ScriptedWireAgent.PromptEchoOrder) async throws {
      let session = try await ScriptedSession.open {
        $0.promptEchoOrder = order
        $0.heldMethods = [Self.promptMethod]
        $0.followUps[Self.promptMethod] = { request, _ in
          [Self.updateFrame(carrying: Self.markerUpdate, for: request)]
        }
      }
      defer { session.close() }
      let draft = PromptInputHostedTestModel(text: Self.firstMessage)
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }
      let model = session.model

      try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
      await harness.pump(until: Self.waitTimeout) { !Self.userMessages(of: model).isEmpty }
      let entry = try #require(Self.userMessages(of: model).first)
      await harness.pump(until: Self.waitTimeout) { Self.sendStateLabel(of: entry, in: harness) != nil }

      #expect(entry.sendState == .pending)
      #expect(Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.pending])
      #expect(draft.plainText.isEmpty)

      session.agent.releaseHeldAnswer()
      await harness.pump(until: Self.waitTimeout) { model.transcript.contains { $0.rowKey.hasSuffix(Self.markerMessageID) } }
      await harness.pump(until: Self.waitTimeout) {
        Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.sent]
      }

      #expect(entry.sendState == .sent)
      #expect(entry.messageId != nil)
      #expect(Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.sent])
      #expect(Self.userMessages(of: model).map(\.id) == [entry.id])
      #expect(session.agent.messages(method: Self.promptMethod).count == 1)
    }

    @Test func aFailedPromptShowsTheMessageAsNotSentAndAddsAnErrorRow() async throws {
      let session = try await ScriptedSession.open { $0.failingMethods = [Self.promptMethod] }
      defer { session.close() }
      let draft = PromptInputHostedTestModel(text: Self.firstMessage)
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }
      let model = session.model
      let errorIdentifier = ErrorView.identifier(for: .acp(code: Self.scriptedErrorCode, message: "failed"))

      try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: errorIdentifier) != nil }
      let entry = try #require(Self.userMessages(of: model).first)
      await harness.pump(until: Self.waitTimeout) {
        Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.failed]
      }

      #expect(entry.sendState == .failed)
      #expect(Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.failed])
      #expect(harness.element(identifier: errorIdentifier) != nil)
    }

    // MARK: - Send while the agent runs

    @Test func aSubmitWhileTheAgentRunsSendsAPromptFrameAtOnce() async throws {
      let session = try await ScriptedSession.open { $0.heldMethods = [Self.promptMethod] }
      defer { session.close() }
      let draft = PromptInputHostedTestModel(text: Self.firstMessage)
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }
      let model = session.model
      try await Self.startRunning(session, in: harness)

      try Self.submitWithReturn(in: harness)
      await harness.pump(until: Self.waitTimeout) { !session.agent.messages(method: Self.promptMethod).isEmpty }
      let entry = try #require(Self.userMessages(of: model).first)
      await harness.pump(until: Self.waitTimeout) { Self.sendStateLabel(of: entry, in: harness) != nil }

      #expect(Self.promptTexts(of: session.agent) == [Self.firstMessage])
      #expect(entry.sendState == .pending)
      #expect(Self.sendStateLabel(of: entry, in: harness) == Self.sendStateLabels[.pending])
      #expect(draft.plainText.isEmpty)
    }

    @Test func aSecondSubmitWhileTheAgentRunsSendsASecondPromptFrameAtOnce() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let draft = PromptInputHostedTestModel(text: Self.firstMessage)
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }
      let model = session.model
      try await Self.startRunning(session, in: harness)

      try Self.submitWithReturn(in: harness)
      await harness.pump(until: Self.waitTimeout) { session.agent.messages(method: Self.promptMethod).count == 1 }
      draft.text = AttributedString(Self.secondMessage)
      harness.pump()
      try Self.submitWithReturn(in: harness)
      await harness.pump(until: Self.waitTimeout) { session.agent.messages(method: Self.promptMethod).count == 2 }

      #expect(Self.promptTexts(of: session.agent) == [Self.firstMessage, Self.secondMessage])
      #expect(Self.isRunning(model))
      #expect(Self.userMessages(of: model).count == 2)
    }

    @Test func aChangeOfTheAgentStateSendsNoFrame() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let draft = PromptInputHostedTestModel()
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }
      let framesBefore = session.agent.received.count

      try await Self.startRunning(session, in: harness)
      try await session.sendUpdate(Self.idleState)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil
      }

      #expect(session.agent.received.count == framesBefore)
    }

    // MARK: - Stop

    @Test func theStopButtonShowsWhileTheAgentRunsAndGoesAwayWhenItIsIdle() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let draft = PromptInputHostedTestModel()
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }

      #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
      try await Self.startRunning(session, in: harness)

      #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) != nil)
      #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) == nil)

      try await session.sendUpdate(Self.idleState)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil
      }

      #expect(harness.element(identifier: DefaultPromptAccessory.stopIdentifier) == nil)
      #expect(harness.element(identifier: DefaultPromptAccessory.submitIdentifier) != nil)
    }

    @Test func theStopButtonSendsSessionCancel() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let draft = PromptInputHostedTestModel()
      let harness = Self.mount(session: session, draft: draft)
      defer { harness.close() }

      try await Self.startRunning(session, in: harness)
      try harness.press(identifier: DefaultPromptAccessory.stopIdentifier)
      await harness.pump(until: Self.waitTimeout) {
        !session.agent.messages(method: Self.cancelMethod).isEmpty
      }

      let cancels = session.agent.messages(method: Self.cancelMethod)
      #expect(cancels.count == 1)
      #expect(cancels.first?["params"]?["sessionId"]?.stringValue == ScriptedSession.sessionID)
    }

    // MARK: - Helpers

    /// Sends the running state of the agent, and waits until the composer
    /// shows the Stop button.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - harness: The harness that shows the composer.
    /// - Throws: The error of the transport.
    static func startRunning<Content: View>(
      _ session: ScriptedSession, in harness: HostedViewHarness<Content>
    ) async throws {
      try await session.sendUpdate(runningState)
      await harness.pump(until: waitTimeout) {
        harness.element(identifier: DefaultPromptAccessory.stopIdentifier) != nil
      }
    }

    /// Submits the text of the composer with the Return key of the editor.
    ///
    /// While the agent runs, the Stop button replaces the submit button. Thus
    /// a submit goes through the editor.
    ///
    /// - Parameter harness: The harness that shows the composer.
    /// - Throws: An error when the window cannot get the key event.
    static func submitWithReturn<Content: View>(in harness: HostedViewHarness<Content>) throws {
      try #require(harness.focusFirstEditableTextView())
      try harness.sendKey(.return)
      harness.pump()
    }

    /// The text of the first prompt block of each `session/prompt` frame, in
    /// arrival order.
    ///
    /// - Parameter agent: The scripted agent.
    /// - Returns: The texts.
    static func promptTexts(of agent: ScriptedWireAgent) -> [String] {
      agent.messages(method: promptMethod).compactMap { $0["params"]?["prompt"]?[0]?["text"]?.stringValue }
    }

    /// A `session/update` frame of the session of a request.
    ///
    /// - Parameters:
    ///   - update: The JSON text of the update.
    ///   - request: The request frame whose session gets the update.
    /// - Returns: The JSON text of the frame.
    static func updateFrame(carrying update: String, for request: AgentViewKit.JSONValue) -> String {
      let sessionID = request["params"]?["sessionId"]?.stringValue ?? ""
      return
        #"{"jsonrpc":"2.0","method":"session/update","params":{"sessionId":"\#(sessionID)","update":\#(update)}}"#
    }
  }
#endif
