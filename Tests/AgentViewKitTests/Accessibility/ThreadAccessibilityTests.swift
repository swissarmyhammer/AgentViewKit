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

  /// The message id of a prompt that this client sent.
  static let sentPromptID = MessageId(rawValue: "sent-prompt")

  /// The message id of a user message that this client did not send.
  static let otherMessageID = MessageId(rawValue: "other-message")

  /// Makes the echo of a user message.
  ///
  /// - Parameter messageID: The message id of the echo.
  /// - Returns: The `user_message` update.
  static func makeEcho(_ messageID: MessageId) -> SessionUpdate {
    .userMessage(UserMessage(messageId: messageID))
  }

  @Test func theEndOfAPromptWithNoStopReasonOrEndTurnAnnouncesThatTheResponseIsComplete() {
    #expect(ThreadAccessibility.turnAnnouncement(for: IdleStateUpdate(stopReason: .endTurn)) == "Response complete")
    #expect(ThreadAccessibility.turnAnnouncement(for: IdleStateUpdate()) == "Response complete")
  }

  @Test func theEndOfACancelledPromptAnnouncesTheCancel() {
    #expect(ThreadAccessibility.turnAnnouncement(for: IdleStateUpdate(stopReason: .cancelled)) == "Response cancelled")
  }

  @Test func aStopReasonWithABannerAnnouncesTheBannerTitle() {
    let reasons: [FoundationModelsACP.StopReason] = [
      .maxTokens, .maxTurnRequests, .refusal, .error, .unknown("_truncated"),
    ]
    for reason in reasons {
      let idle = IdleStateUpdate(stopReason: reason)
      #expect(ThreadAccessibility.turnAnnouncement(for: idle) == StateBanner.message(for: .idle(idle)).title)
    }
  }

  @Test func anIdleWithNoEchoOfASentPromptIsSilent() {
    var tracker = PromptEndTracker()
    #expect(tracker.receive(.stateUpdate(Self.running), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(tracker.receive(.stateUpdate(Self.makeIdle(.endTurn)), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(tracker.receive(Self.makeEcho(Self.otherMessageID), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(tracker.receive(.stateUpdate(Self.requiresAction), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(tracker.receive(.stateUpdate(Self.makeIdle(nil)), sentPromptIDs: [Self.sentPromptID]) == nil)
  }

  @Test func onlyTheFirstIdleAfterTheEchoOfASentPromptAnnounces() {
    var tracker = PromptEndTracker()
    #expect(tracker.receive(Self.makeEcho(Self.sentPromptID), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(tracker.receive(.stateUpdate(Self.running), sentPromptIDs: [Self.sentPromptID]) == nil)
    #expect(
      tracker.receive(.stateUpdate(Self.makeIdle(.endTurn)), sentPromptIDs: [Self.sentPromptID])
        == "Response complete")
    #expect(tracker.receive(.stateUpdate(Self.makeIdle(.endTurn)), sentPromptIDs: [Self.sentPromptID]) == nil)
  }

  // MARK: - Tool result

  @Test func aCallThatGetsItsResultAnnouncesItsTitleAndStatus() {
    let old = [Progress(id: "a", title: "Read file", status: .inProgress)]
    let statuses: [FoundationModelsACP.ToolCallStatus] = [
      .completed, .failed, .cancelled, .unknown(ToolStatusSymbol.lostWireValue),
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
    let model = session.model
    await ObservationWait.until { model.transcript.count == Self.transcriptEntryCount }

    let toolCall = try #require(model.transcript.last)
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
    let connection = session.connection
    await ObservationWait.until { !connection.pendingElicitations.isEmpty }
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

  // MARK: - Labels and the focus mover

  @Test func theReasoningLabelTellsTheProgress() {
    #expect(
      ReasoningView.accessibilityLabel(isInProgress: true, duration: 3)
        == "Reasoning, in progress")
    #expect(
      ReasoningView.accessibilityLabel(isInProgress: false, duration: 4.4)
        == "Reasoning, 4 seconds")
    #expect(ReasoningView.accessibilityLabel(isInProgress: false, duration: nil) == "Reasoning")
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
