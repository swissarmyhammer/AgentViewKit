@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Tests of the pure functions of the thread accessibility (plan.md §6).
@MainActor struct ThreadAccessibilityTests {
  typealias Progress = ThreadAccessibility.ToolCallProgress
  typealias Summary = ThreadAccessibility.PendingRequestSummary

  // MARK: - Turn of a session model

  /// The agent state while the agent runs.
  static let running = StateUpdate.running(RunningStateUpdate())

  /// The agent state while the agent waits for the user.
  static let requiresAction = StateUpdate.requiresAction(RequiresActionStateUpdate())

  /// The title of the tool call that the transcript test sends.
  static let toolTitle = "Build"

  /// The number of transcript entries of the transcript test: one agent
  /// message and one tool call.
  static let transcriptEntryCount = 2

  /// The JSON-RPC id of the first request that the agent sends.
  static let agentRequestID = 1

  /// Makes the idle agent state with a stop reason.
  ///
  /// - Parameter reason: The stop reason, or `nil` for none.
  /// - Returns: The state.
  static func makeIdle(_ reason: FoundationModelsACP.StopReason?) -> StateUpdate {
    .idle(IdleStateUpdate(stopReason: reason))
  }

  @Test func aSessionThatStopsForegroundWorkAnnouncesThatTheResponseIsComplete() {
    #expect(
      ThreadAccessibility.turnAnnouncement(old: Self.running, new: Self.makeIdle(.endTurn)) == "Response complete")
    #expect(
      ThreadAccessibility.turnAnnouncement(old: Self.requiresAction, new: Self.makeIdle(nil)) == "Response complete")
  }

  @Test func aCancelledSessionTurnAnnouncesTheCancel() {
    #expect(
      ThreadAccessibility.turnAnnouncement(old: Self.running, new: Self.makeIdle(.cancelled)) == "Response cancelled")
  }

  @Test func aSessionStopReasonWithABannerAnnouncesTheBannerTitle() {
    let reasons: [FoundationModelsACP.StopReason] = [.maxTokens, .maxTurnRequests, .refusal, .unknown("_truncated")]
    for reason in reasons {
      let idle = Self.makeIdle(reason)
      #expect(ThreadAccessibility.turnAnnouncement(old: Self.running, new: idle) == StateBanner.message(for: idle).title)
    }
  }

  @Test func aSessionChangeThatDoesNotStopForegroundWorkIsSilent() {
    #expect(ThreadAccessibility.turnAnnouncement(old: nil, new: Self.makeIdle(.endTurn)) == nil)
    #expect(ThreadAccessibility.turnAnnouncement(old: Self.makeIdle(nil), new: Self.makeIdle(.endTurn)) == nil)
    #expect(ThreadAccessibility.turnAnnouncement(old: Self.running, new: Self.requiresAction) == nil)
    #expect(ThreadAccessibility.turnAnnouncement(old: Self.running, new: nil) == nil)
  }

  // MARK: - Tool result

  @Test func aCallThatGetsItsResultAnnouncesItsTitleAndStatus() {
    let old = [Progress(id: "a", title: "Read file", status: .inProgress)]
    let statuses: [FoundationModelsACP.ToolCallStatus] = [
      .completed, .failed, .cancelled, AgentViewKit.ToolCallStatus.lost.acpStatus,
    ]
    for status in statuses {
      let new = [Progress(id: "a", title: "Read file", status: status)]
      #expect(
        ThreadAccessibility.toolResultAnnouncements(old: old, new: new) == [
          ToolCallView.accessibilityLabel(title: "Read file", status: status)
        ])
    }
  }

  @Test func theProgressOfATranscriptHasOnlyItsToolCallEntries() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    try await session.sendUpdate(
      #"{"sessionUpdate": "agent_message_chunk", "messageId": "m1", "content": {"type": "text", "text": "Hello."}}"#)
    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .inProgress)
    #expect(await waitUntil { session.model.transcript.count == Self.transcriptEntryCount })

    let toolCall = try #require(session.model.transcript.last)
    #expect(
      ThreadAccessibility.toolCallProgress(in: session.model.transcript) == [
        Progress(id: toolCall.id.rowKey, title: Self.toolTitle, status: .inProgress)
      ])
  }

  @Test func aCallWithNoNewResultIsSilent() {
    let pending = [Progress(id: "a", title: "Read", status: .pending)]
    let running = [Progress(id: "a", title: "Read", status: .inProgress)]
    let done = [Progress(id: "a", title: "Read", status: .completed)]
    #expect(ThreadAccessibility.toolResultAnnouncements(old: pending, new: running).isEmpty)
    #expect(ThreadAccessibility.toolResultAnnouncements(old: done, new: done).isEmpty)
    #expect(ThreadAccessibility.toolResultAnnouncements(old: [], new: done).isEmpty)
    #expect(
      ThreadAccessibility.toolResultAnnouncements(
        old: running, new: [Progress(id: "a", title: "Read", status: .unknown("_x"))]
      ).isEmpty)
  }

  @Test func thePendingRequestsOfASessionAndItsConnectionHaveTheOrderOfTheCards() async throws {
    let session = try await ScriptedSession.openWithLoginElicitation(id: Self.agentRequestID)
    defer { session.close() }
    let login = session.startLogin()
    #expect(await waitUntil { !session.connection.pendingElicitations.isEmpty })
    let loginElicitation = try #require(session.connection.pendingElicitations.first)
    let elicitation = try await session.receiveElicitation(
      id: Self.agentRequestID + 1, params: ScriptedSession.formElicitationParams)
    let permission = try await session.receivePermissionRequest(id: Self.agentRequestID + 2)

    let summaries = ThreadAccessibility.pendingRequests(of: session.model, connection: session.connection)
    session.agent.releaseHeldAnswer()
    try await login.value

    #expect(
      summaries == [
        Summary(id: permission.id.uuidString, title: permission.request.title),
        Summary(id: elicitation.id.uuidString, title: elicitation.request.message),
        Summary(id: loginElicitation.id.uuidString, title: ScriptedSession.loginElicitationMessage),
      ])
  }

  // MARK: - Action required

  @Test func eachNewRequestAnnouncesThatAnActionIsRequired() {
    let old = [Summary(id: "a", title: "Old")]
    let new = [Summary(id: "a", title: "Old"), Summary(id: "b", title: "New")]
    #expect(
      ThreadAccessibility.actionRequiredAnnouncements(old: old, new: new) == [
        "Action required: New"
      ])
    #expect(ThreadAccessibility.actionRequiredAnnouncements(old: new, new: old).isEmpty)
  }

  // MARK: - Labels and priorities

  @Test func theReasoningLabelTellsTheProgress() {
    #expect(
      ReasoningView.accessibilityLabel(isInProgress: true, duration: 3)
        == "Reasoning, in progress")
    #expect(
      ReasoningView.accessibilityLabel(isInProgress: false, duration: 4.4)
        == "Reasoning, 4 seconds")
    #expect(ReasoningView.accessibilityLabel(isInProgress: false, duration: nil) == "Reasoning")
  }

  @Test func eachPriorityHasASpeechPriority() {
    #expect(VoiceOverAnnouncer.speechPriority(of: .low) == .low)
    #expect(VoiceOverAnnouncer.speechPriority(of: .medium) == .default)
    #expect(VoiceOverAnnouncer.speechPriority(of: .high) == .high)
  }

  @Test func theMoverCountsEachMove() {
    let mover = AccessibilityFocusMover()
    mover.focusMoved(to: "card")
    mover.focusMoved(to: "card")
    #expect(mover.lastMove == AccessibilityFocusMover.Move(identifier: "card", serial: 2))
  }

  // MARK: - Spoken math

  @Test func theSpokenTextHasEachMathSpanAtItsPlace() {
    let parser = MathMarkdownParser()
    #expect(parser.spokenText(for: "Let $x^2$ be **big**.") == "Let x^2 be big.")
    #expect(parser.spokenText(for: "No math here.") == nil)
    #expect(parser.spokenText(for: "Code `$x$` and $y$.") == "Code $x$ and y.")
  }
}
