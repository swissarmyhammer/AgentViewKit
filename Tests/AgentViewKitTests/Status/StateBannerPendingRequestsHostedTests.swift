#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Fixed-order tests of the text of ``StateBanner`` for an agent that
  /// reports idle while its requests wait for the user.
  ///
  /// ACPAgent never sends `requires_action`: a session can be idle with
  /// pending requests. Then the banner shows the message of a request that
  /// waits for the user. Other agents send `requires_action`, and the banner
  /// shows the same message for it. The running and ready texts have no turn
  /// words, because the agent can run with no prompt open.
  ///
  /// After each step, a test waits for the event that the model has the
  /// change (``ObservationWait/until(_:)``), does one layout pass, and reads
  /// the banner. No test reads a clock, polls, or has a time limit.
  @Suite(.serialized, .hostedSerially) @MainActor struct StateBannerPendingRequestsHostedTests {
    /// A size that shows the banner of the thread and a card of the deck.
    static let size = CGSize(width: 480, height: 640)

    /// The word that the running and ready texts do not have.
    static let turnWord = "turn"

    /// The idle state with the `end_turn` stop reason.
    static let endTurn = StateUpdate.idle(IdleStateUpdate(stopReason: .endTurn))

    /// The title of the banner for a request that waits for the user.
    static let waitingTitle = StateBanner.message(for: .requiresAction(RequiresActionStateUpdate())).title

    /// The title of the banner for a prompt that ended with `end_turn`.
    static let endTurnTitle = StateBanner.message(for: endTurn).title

    /// Shows the thread view and the deck of a session model in one focus
    /// scope, as an app arranges them, and lays them out one time. The
    /// thread view shows the banner, and the deck shows the cards.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The harness.
    static func mount(_ model: SessionModel) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: size) {
        VStack {
          AgentThreadView(session: model)
          RequestDeck(session: model)
        }
        .accessibilityFocusScope()
        .transaction { $0.disablesAnimations = true }
      }
      harness.hostingView.layoutSubtreeIfNeeded()
      return harness
    }

    /// Tells whether `text` has the word "turn" in any case.
    ///
    /// - Parameter text: The user-visible text.
    /// - Returns: `true` when the text has the word.
    static func hasTurnWord(_ text: String) -> Bool {
      text.localizedCaseInsensitiveContains(turnWord)
    }

    // MARK: - Idle with a pending request

    @Test func anIdleSessionWithAPendingPermissionShowsTheWaitingMessage() {
      let model = CancelAvailabilityTests.makeSession(
        state: Self.endTurn, pendingPermissions: [CancelAvailabilityTests.permissionRequest])
      let harness = Self.mount(model)
      defer { harness.close() }

      #expect(harness.stateBannerLabel == Self.waitingTitle)
    }

    @Test func anIdleSessionWithNoPendingRequestShowsItsStopReason() {
      let model = CancelAvailabilityTests.makeSession(state: Self.endTurn)
      let harness = Self.mount(model)
      defer { harness.close() }

      #expect(harness.stateBannerLabel == Self.endTurnTitle)
    }

    @Test func aPermissionThatArrivesWhileIdleShowsTheWaitingMessageUntilTheAnswer() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let harness = Self.mount(model)
      defer { harness.close() }

      try await session.sendUpdate(ScriptedSession.endTurnState)
      await AgentWorkOrderHostedTests.layOut(harness) { model.agentState == Self.endTurn }
      #expect(harness.stateBannerLabel == Self.endTurnTitle)

      try await session.sendRequest(
        ScriptedSession.permissionMethod, id: AgentCommandsTests.agentRequestID,
        params: ScriptedSession.permissionParams)
      await AgentWorkOrderHostedTests.layOut(harness) { !model.pendingPermissions.isEmpty }
      #expect(model.agentState == Self.endTurn)
      #expect(harness.stateBannerLabel == Self.waitingTitle)

      let pending = try #require(model.pendingPermissions.first)
      model.answerPermission(pending.id, option: PermissionOptionId(rawValue: "yes"), comment: nil)
      await AgentWorkOrderHostedTests.layOut(harness) { model.pendingPermissions.isEmpty }

      #expect(harness.stateBannerLabel == Self.endTurnTitle)
    }

    @Test func anElicitationThatArrivesWhileIdleShowsTheWaitingMessage() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let harness = Self.mount(model)
      defer { harness.close() }
      try await CancelAvailabilityTests.makeIdleAfterRunning(session)

      try await session.sendRequest(
        ScriptedSession.elicitationMethod, id: AgentCommandsTests.agentRequestID,
        params: ScriptedSession.formElicitationParams)
      await AgentWorkOrderHostedTests.layOut(harness) { !model.pendingElicitations.isEmpty }

      #expect(CancelAvailabilityTests.isIdle(model.agentState))
      #expect(harness.stateBannerLabel == Self.waitingTitle)
    }

    // MARK: - Turn words

    @Test func theRunningTextHasNoTurnWord() {
      let message = StateBanner.message(for: .running(RunningStateUpdate()))

      #expect(!Self.hasTurnWord(message.title))
      #expect(!Self.hasTurnWord(message.explanation))
    }

    @Test func theReadyTextHasNoTurnWord() {
      let message = StateBanner.message(for: .idle(IdleStateUpdate()))

      #expect(!Self.hasTurnWord(message.title))
      #expect(!Self.hasTurnWord(message.explanation))
    }

    @Test func theCancelReasonHasNoTurnWord() {
      #expect(!Self.hasTurnWord(AgentCommandTarget.reason(for: .cancel)))
    }
  }
#endif
