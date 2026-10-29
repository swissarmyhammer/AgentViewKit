#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import DemoSupport
  import EditorTestSupport
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Fixed-order tests of the Send button and the Stop button of
  /// ``DefaultPromptAccessory``.
  ///
  /// The Send button shows at all times, so that the user can send a second
  /// prompt while the agent works. It keeps its own enable rule. The Stop
  /// button shows beside it while the one cancel rule of the kit,
  /// ``AgentCommandTarget/canCancel(_:)``, is true: while the agent runs, and
  /// while the session is idle with a pending request.
  ///
  /// Each test sets the state of the session model in a fixed order. After a
  /// change, it waits for the event that the model has the change
  /// (``ObservationWait/until(_:)``), does one layout pass, and reads the
  /// buttons. No test reads a clock, polls, or has a time limit.
  @Suite(.serialized, .hostedSerially) @MainActor struct PromptAccessoryButtonsHostedTests {
    /// The size of a window that shows the full composer.
    static let size = CGSize(width: 480, height: 200)

    /// The text of the composer.
    static let message = "Hello"

    /// The accessibility label of the Send button.
    static let sendLabel = "Send"

    /// The accessibility label of the Stop button.
    static let stopLabel = "Stop"

    /// The running state.
    static let running = StateUpdate.running(RunningStateUpdate())

    /// Shows a composer with text over a session model, and lays it out one
    /// time.
    ///
    /// - Parameter model: The session model of the environment.
    /// - Returns: The harness.
    static func mount(_ model: SessionModel) -> HostedViewHarness<some View> {
      let draft = PromptInputHostedTestModel(text: message)
      let harness = HostedViewHarness(size: size) {
        PromptInputHost(model: draft)
          .environment(\.sessionModel, model)
          .transaction { $0.disablesAnimations = true }
      }
      harness.hostingView.layoutSubtreeIfNeeded()
      return harness
    }

    /// The Send button in `harness`, or `nil` when it does not show.
    ///
    /// - Parameter harness: The harness that shows the composer.
    /// - Returns: The element.
    static func sendButton<Content: View>(in harness: HostedViewHarness<Content>) -> AccessibilityElementSnapshot? {
      harness.element(identifier: DefaultPromptAccessory.submitIdentifier)
    }

    /// The Stop button in `harness`, or `nil` when it does not show.
    ///
    /// - Parameter harness: The harness that shows the composer.
    /// - Returns: The element.
    static func stopButton<Content: View>(in harness: HostedViewHarness<Content>) -> AccessibilityElementSnapshot? {
      harness.element(identifier: DefaultPromptAccessory.stopIdentifier)
    }

    /// What the accessory row shows of its two buttons.
    struct Buttons: Equatable {
      /// The label of the Send button, or `nil` when it does not show.
      let send: String?

      /// Whether the Send button is enabled, or `nil` when it does not show.
      let isSendEnabled: Bool?

      /// The label of the Stop button, or `nil` when it does not show.
      let stop: String?
    }

    /// The Send button, enabled, and the Stop button beside it.
    static let sendAndStop = Buttons(send: sendLabel, isSendEnabled: true, stop: stopLabel)

    /// The Send button, enabled, and no Stop button.
    static let sendOnly = Buttons(send: sendLabel, isSendEnabled: true, stop: nil)

    /// The two buttons that `harness` shows.
    ///
    /// - Parameter harness: The harness that shows the composer.
    /// - Returns: The labels and the enable state.
    static func buttons<Content: View>(in harness: HostedViewHarness<Content>) -> Buttons {
      let send = sendButton(in: harness)
      return Buttons(send: send?.label, isSendEnabled: send?.isEnabled, stop: stopButton(in: harness)?.label)
    }

    // MARK: - Running

    @Test func whileTheAgentRunsTheSendButtonAndTheStopButtonShowTogether() {
      let model = CancelAvailabilityTests.makeSession(state: Self.running)
      let harness = Self.mount(model)
      defer { harness.close() }

      #expect(Self.buttons(in: harness) == Self.sendAndStop)
    }

    @Test func theSendButtonSendsAPromptWhileTheAgentRuns() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model
      let harness = Self.mount(model)
      defer { harness.close() }
      try await session.sendUpdate(ScriptedSession.runningState)
      await AgentWorkOrderHostedTests.layOut(harness) { model.agentState == Self.running }
      #expect(Self.buttons(in: harness) == Self.sendAndStop)

      try harness.press(identifier: DefaultPromptAccessory.submitIdentifier)
      await AgentWorkOrderHostedTests.layOut(harness) {
        ComposerSessionModelHostedTests.userMessages(of: model).first?.sendState == .sent
      }

      #expect(session.agent.messages(method: ScriptedSession.promptMethod).count == 1)
      #expect(model.agentState == Self.running)
      #expect(Self.buttons(in: harness) == Buttons(send: Self.sendLabel, isSendEnabled: false, stop: Self.stopLabel))
    }

    // MARK: - Idle

    @Test func anIdleSessionWithAPendingPermissionShowsTheStopButtonBesideTheSendButton() {
      let model = CancelAvailabilityTests.makeSession(
        state: CancelAvailabilityTests.idle, pendingPermissions: [CancelAvailabilityTests.permissionRequest])
      let harness = Self.mount(model)
      defer { harness.close() }

      #expect(Self.buttons(in: harness) == Self.sendAndStop)
    }

    @Test func anIdleSessionWithNoPendingRequestShowsOnlyTheSendButton() {
      let model = CancelAvailabilityTests.makeSession(state: CancelAvailabilityTests.idle)
      let harness = Self.mount(model)
      defer { harness.close() }

      #expect(Self.buttons(in: harness) == Self.sendOnly)
    }

    @Test func theEndOfThePendingRequestOfAnIdleSessionHidesTheStopButton() async {
      let model = CancelAvailabilityTests.makeSession(
        state: CancelAvailabilityTests.idle, pendingPermissions: [CancelAvailabilityTests.permissionRequest])
      let harness = Self.mount(model)
      defer { harness.close() }
      #expect(Self.buttons(in: harness) == Self.sendAndStop)

      model.cancelAllPending()
      await AgentWorkOrderHostedTests.layOut(harness) { model.pendingPermissions.isEmpty }

      #expect(Self.buttons(in: harness) == Self.sendOnly)
    }
  }
#endif
