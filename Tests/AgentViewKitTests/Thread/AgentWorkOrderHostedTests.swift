#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// Fixed-order tests of the thread view for the orders of ACPAgent that are
  /// not one prompt from its start to its end.
  ///
  /// ACPAgent reports `running` and `idle` also with no prompt open. After
  /// background work only, the idle has no stop reason. One idle can end two
  /// open prompts. A compaction entry can change after the prompt ended. The
  /// kit has no prompt rule for these orders: each view shows only what the
  /// session model reports.
  ///
  /// The scripted agent answers each prompt in the ACPAgent order (the
  /// response, then the echo, then the scripted updates). After each update,
  /// a test waits for the event that the model has the change
  /// (``ObservationWait/until(_:)``). Then it does one layout pass, and
  /// compares the views with the model: the rows, the state banner and the
  /// activity indicator. At the end, it reads the announcements of the
  /// thread. No test reads a clock, polls, or has a time limit.
  @Suite(.serialized, .hostedSerially) @MainActor struct AgentWorkOrderHostedTests {
    /// A size that shows each row, the state banner and the activity
    /// indicator.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The content of each prompt that the tests send.
    static let promptContent: [ContentBlock] = [.text(TextContent(text: "Hello."))]

    /// The `messageId` of the reply of the agent.
    static let replyMessageID = "order-reply"

    /// The text of the reply of the agent.
    static let replyText = "Done."

    /// The `compactionId` of the compaction after the prompt.
    static let compactionID = "order-compaction"

    /// The idle state with no stop reason.
    static let idle = StateUpdate.idle(IdleStateUpdate())

    /// The idle state with the `end_turn` stop reason.
    static let endTurn = StateUpdate.idle(IdleStateUpdate(stopReason: .endTurn))

    /// The running state.
    static let running = StateUpdate.running(RunningStateUpdate())

    /// The one announcement of the idle that ends the work of the prompts.
    static let responseComplete = ThreadAccessibility.turnAnnouncement(for: IdleStateUpdate(stopReason: .endTurn))

    /// The compaction updates after the prompt, in send order: the wire
    /// status, the status of the model, and the label of the row.
    static let compactionSteps: [(wire: String, status: CompactionStatus, label: String)] = [
      ("in_progress", .inProgress, "Context compaction, In progress"),
      ("completed", .completed, "Context compaction, Completed"),
    ]

    /// The `agent_message_chunk` value of the reply, as JSON text.
    static var replyChunk: String {
      get throws {
        try ScriptedSession.agentMessageChunkUpdate(messageID: replyMessageID, text: replyText).jsonString
      }
    }

    /// The row key of the compaction entry.
    static var compactionKey: String {
      TranscriptEntry.ID.wire(.compaction(CompactionId(rawValue: compactionID))).rowKey
    }

    /// A `compaction_update` value of the compaction, as JSON text.
    ///
    /// - Parameter status: The wire value of the status.
    /// - Returns: The JSON text of the update.
    static func compactionUpdate(status: String) -> String {
      #"{"sessionUpdate":"compaction_update","compactionId":"\#(compactionID)","status":"\#(status)"}"#
    }

    /// Mounts the thread of `session` and the activity indicator of its
    /// session model.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness.
    static func mount(_ session: ScriptedSession) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        VStack {
          AgentThreadView(session: session.model)
          ActivityIndicator(session: session.model)
        }
        .transaction { $0.disablesAnimations = true }
      }
    }

    /// Tells whether the activity indicator in `harness` shows the activity
    /// of `model`: the shimmer only while the agent runs and no tool call
    /// runs.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - harness: The harness that shows the indicator.
    /// - Returns: `true` when the indicator shows what the model reports.
    static func showsTheActivity<Content: View>(of model: SessionModel, in harness: HostedViewHarness<Content>) -> Bool {
      let showsShimmer = harness.element(identifier: ShimmerView.identifier) != nil
      return showsShimmer == (ActivityState(session: model) == .thinking)
    }

    /// Tells whether `harness` shows the rows, the state banner and the
    /// activity of `model`.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - harness: The harness that shows the thread.
    /// - Returns: `true` when the views show what the model reports.
    static func showsTheThread<Content: View>(of model: SessionModel, in harness: HostedViewHarness<Content>) -> Bool {
      BackgroundRunsHostedTests.showsTheModel(model, in: harness) && showsTheActivity(of: model, in: harness)
    }

    /// Waits until `predicate` is true, and then lays out the views of
    /// `harness` one time.
    ///
    /// - Parameters:
    ///   - harness: The harness that shows the thread.
    ///   - predicate: The change of the model to wait for.
    static func layOut<Content: View>(_ harness: HostedViewHarness<Content>, after predicate: @MainActor () -> Bool) async {
      await ObservationWait.until(predicate)
      harness.hostingView.layoutSubtreeIfNeeded()
    }

    /// The `messageId` of each user message of `model`, in transcript order.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The IDs. A user message with no ID gives `nil`.
    static func userMessageIDs(in model: SessionModel) -> [MessageId?] {
      model.transcript.compactMap { entry in
        if case .userMessage(let message) = entry { .some(message.messageId) } else { nil }
      }
    }

    /// The compaction entry of `model` with ``compactionID``, or `nil`.
    ///
    /// - Parameter model: The session model.
    /// - Returns: The entry.
    static func compaction(in model: SessionModel) -> CompactionEntry? {
      model.transcript.lazy.compactMap { entry in
        if case .compaction(let compaction) = entry { compaction } else { nil }
      }.first { $0.compactionId.rawValue == compactionID }
    }

    @Test func runningAndIdleWithNoPromptOpenShowTheStateAndAnnounceNothing() async throws {
      let session = try await TurnAnnouncementTests.open(turns: [])
      defer { session.close() }
      let harness = Self.mount(session)
      defer { harness.close() }
      let model = session.model
      let announcements = ThreadAccessibility.makeTurnAnnouncements(of: model)

      try await session.sendUpdate(ScriptedSession.runningState)
      await Self.layOut(harness) { model.agentState == Self.running }
      #expect(Self.showsTheThread(of: model, in: harness))
      #expect(harness.element(identifier: ShimmerView.identifier) != nil)

      try await session.sendUpdate(ScriptedSession.idleState)
      await Self.layOut(harness) { model.agentState == Self.idle }
      #expect(Self.showsTheThread(of: model, in: harness))
      #expect(harness.stateBannerLabel == StateBanner.message(for: Self.idle).title)
      #expect(model.transcript.isEmpty)

      #expect(await TurnAnnouncementTests.collect(announcements, of: session, endingWith: Self.idle).isEmpty)
    }

    @Test func anIdleWithNoStopReasonAfterBackgroundWorkOnlyShowsTheWorkAndAnnouncesNothing() async throws {
      let session = try await TurnAnnouncementTests.open(turns: [])
      defer { session.close() }
      let harness = Self.mount(session)
      defer { harness.close() }
      let model = session.model
      let announcements = ThreadAccessibility.makeTurnAnnouncements(of: model)

      for step in BackgroundRunScript.backgroundOnlySteps {
        try await session.send(update: step.update)
        await Self.layOut(harness) { BackgroundRunsHostedTests.isReported(change: step.change, by: model) }
        #expect(Self.showsTheThread(of: model, in: harness), "\(step.change)")
      }

      #expect(model.agentState == Self.idle)
      #expect(harness.stateBannerLabel == StateBanner.message(for: Self.idle).title)
      #expect(await TurnAnnouncementTests.collect(announcements, of: session, endingWith: Self.idle).isEmpty)
    }

    @Test func oneIdleThatEndsTwoOpenPromptsShowsBothPromptsAndTheEndOneTime() async throws {
      let session = try await TurnAnnouncementTests.open(turns: [
        [ScriptedSession.runningState], [Self.replyChunk, ScriptedSession.endTurnState],
      ])
      defer { session.close() }
      let harness = Self.mount(session)
      defer { harness.close() }
      let model = session.model
      let announcements = ThreadAccessibility.makeTurnAnnouncements(of: model)

      let first = try await model.prompt(Self.promptContent)
      let second = try await model.prompt(Self.promptContent)
      await Self.layOut(harness) { model.agentState == Self.endTurn }

      #expect(Self.userMessageIDs(in: model) == [first.messageId, second.messageId])
      #expect(Self.showsTheThread(of: model, in: harness))
      #expect(harness.stateBannerLabel == StateBanner.message(for: Self.endTurn).title)
      #expect(
        await TurnAnnouncementTests.collect(announcements, of: session, endingWith: Self.endTurn)
          == [Self.responseComplete])
    }

    @Test func aCompactionAfterThePromptEndedShowsInProgressThenCompletedAndKeepsTheEnd() async throws {
      let session = try await TurnAnnouncementTests.open(turns: [
        [ScriptedSession.runningState, Self.replyChunk, ScriptedSession.endTurnState]
      ])
      defer { session.close() }
      let harness = Self.mount(session)
      defer { harness.close() }
      let model = session.model
      let announcements = ThreadAccessibility.makeTurnAnnouncements(of: model)
      _ = try await model.prompt(Self.promptContent)
      await ObservationWait.until { model.agentState == Self.endTurn }

      for step in Self.compactionSteps {
        try await session.sendUpdate(Self.compactionUpdate(status: step.wire))
        await Self.layOut(harness) { Self.compaction(in: model)?.status == step.status }
        #expect(model.transcript.last?.rowKey == Self.compactionKey, "\(step.wire)")
        #expect(harness.element(identifier: CompactionEntryView.identifier(for: Self.compactionKey))?.label == step.label)
        #expect(Self.showsTheThread(of: model, in: harness), "\(step.wire)")
        #expect(model.agentState == Self.endTurn, "\(step.wire)")
      }

      #expect(
        await TurnAnnouncementTests.collect(announcements, of: session, endingWith: Self.endTurn)
          == [Self.responseComplete])
    }
  }
#endif
