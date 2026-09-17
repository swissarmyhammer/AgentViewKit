@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

/// Tests of the pure functions of the thread accessibility (plan.md §6).
@MainActor struct ThreadAccessibilityTests {
  typealias Progress = ThreadAccessibility.ToolCallProgress
  typealias Summary = ThreadAccessibility.PendingRequestSummary

  // MARK: - Turn

  @Test func aTurnThatEndsAnnouncesThatTheResponseIsComplete() {
    #expect(
      ThreadAccessibility.turnAnnouncement(old: .running, new: .idle(.endTurn))
        == "Response complete")
    #expect(
      ThreadAccessibility.turnAnnouncement(old: .running, new: .idle(nil)) == "Response complete")
    #expect(
      ThreadAccessibility.turnAnnouncement(old: .requiresAction, new: .idle(.unknown("other")))
        == "Response complete")
  }

  @Test func aCancelledTurnAnnouncesTheCancel() {
    #expect(
      ThreadAccessibility.turnAnnouncement(old: .running, new: .idle(.cancelled))
        == "Response cancelled")
  }

  @Test func aStopReasonWithABannerAnnouncesTheBannerTitle() throws {
    let banner = try #require(StateBanner.message(for: .idle(.maxTokens)))
    #expect(
      ThreadAccessibility.turnAnnouncement(old: .running, new: .idle(.maxTokens)) == banner.title)
  }

  @Test func aChangeThatDoesNotStopATurnIsSilent() {
    #expect(ThreadAccessibility.turnAnnouncement(old: .idle(nil), new: .running) == nil)
    #expect(ThreadAccessibility.turnAnnouncement(old: .idle(nil), new: .idle(.endTurn)) == nil)
    #expect(ThreadAccessibility.turnAnnouncement(old: .running, new: .requiresAction) == nil)
  }

  // MARK: - Tool result

  @Test func aCallThatGetsItsResultAnnouncesItsTitleAndStatus() {
    let old = [Progress(id: "a", title: "Read file", status: .inProgress)]
    for status in [ToolCallStatus.completed, .failed, .cancelled, .lost] {
      let new = [Progress(id: "a", title: "Read file", status: status)]
      #expect(
        ThreadAccessibility.toolResultAnnouncements(old: old, new: new) == [
          ToolCallView.accessibilityLabel(title: "Read file", status: status)
        ])
    }
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

  @Test func theProgressListHasOnlyTheToolCalls() {
    let call = ThreadFixtures.toolCall(status: .inProgress)
    let items: [ThreadItem] = [
      .assistantMessage(ThreadFixtures.message()), .toolCall(call),
    ]
    #expect(
      ThreadAccessibility.toolCallProgress(in: items) == [
        Progress(id: call.id, title: call.title, status: .inProgress)
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

  @Test func thePendingRequestsHaveTheOrderOfTheCards() {
    let thread = AgentThread()
    let permission = ThreadFixtures.permissionRequest(id: "p")
    let elicitation = ThreadFixtures.formElicitationRequest(id: "e")
    let authorization = AuthorizationRequest(
      id: AuthorizationRequestID("z"), serverName: "GitHub", scopes: [],
      authorizationURL: URL(string: "https://example.com")!)
    thread.apply(.addAuthorization(authorization))
    thread.apply(.addElicitation(elicitation))
    thread.apply(.addPermission(permission))

    #expect(
      ThreadAccessibility.pendingRequests(of: thread) == [
        Summary(id: "p", title: permission.title),
        Summary(id: "e", title: elicitation.message),
        Summary(id: "z", title: "Connect GitHub"),
      ])
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
