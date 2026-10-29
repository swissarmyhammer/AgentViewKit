import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// Fixed-order tests of the "Response complete" announcement
/// (elicitation-plan.md task 48, ``ThreadAccessibility/makeTurnAnnouncements(of:)``).
///
/// The scripted agent answers each prompt in the ACPAgent order: the prompt
/// response with its `messageId`, then the echo with that `messageId`, then
/// the scripted updates of that prompt. Each test waits for the event that
/// the model has its last state (``ObservationWait/until(_:)``), then
/// disconnects. The disconnect ends the update tap, so the announcement
/// stream ends after it gave each text. No test reads a clock, polls, or has
/// a time limit.
@MainActor struct TurnAnnouncementTests {
  /// The content of each prompt that the tests send.
  static let promptContent: [ContentBlock] = [.text(TextContent(text: "Hello."))]

  /// The `session/update` value that tells that the agent is idle because
  /// the user cancelled (`cancelled`).
  static let cancelledState = #"{"sessionUpdate":"state_update","state":"idle","stopReason":"cancelled"}"#

  /// The `session/update` value of a user message that this client did not
  /// send.
  static let otherUserMessage =
    #"{"sessionUpdate":"user_message","messageId":"other-client","content":[{"type":"text","text":"Hi."}]}"#

  /// The idle state with no stop reason.
  static let idle = StateUpdate.idle(IdleStateUpdate())

  /// The idle state with the `end_turn` stop reason.
  static let endTurn = StateUpdate.idle(IdleStateUpdate(stopReason: .endTurn))

  /// The idle state with the `cancelled` stop reason, as ``cancelledState``
  /// gives it.
  static let cancelled = StateUpdate.idle(IdleStateUpdate(stopReason: .cancelled))

  @Test func theFirstIdleAfterTheEchoOfAPromptAnnouncesThatTheResponseIsComplete() async throws {
    let session = try await TurnAnnouncementFixtures.open(
      turns: [[ScriptedSession.runningState, ScriptedSession.endTurnState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(
      await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.endTurn)
        == ["Response complete"])
  }

  @Test func anIdleAfterBackgroundWorkOnlyAnnouncesNothing() async throws {
    let session = try await TurnAnnouncementFixtures.open(turns: [])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    try await session.sendUpdate(ScriptedSession.runningState)
    try await session.sendUpdate(ScriptedSession.idleState)

    #expect(await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.idle).isEmpty)
  }

  @Test func aSecondIdleWithNoNewPromptAnnouncesNothing() async throws {
    let session = try await TurnAnnouncementFixtures.open(turns: [
      [
        ScriptedSession.runningState, ScriptedSession.endTurnState,
        ScriptedSession.runningState, ScriptedSession.idleState,
      ]
    ])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(
      await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.idle)
        == ["Response complete"])
  }

  @Test func oneIdleThatEndsTwoOpenPromptsAnnouncesOneTime() async throws {
    let session = try await TurnAnnouncementFixtures.open(
      turns: [[ScriptedSession.runningState], [ScriptedSession.endTurnState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)
    _ = try await session.model.prompt(Self.promptContent)

    #expect(
      await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.endTurn)
        == ["Response complete"])
  }

  @Test func theIdleAfterTheEchoOfACancelledPromptAnnouncesTheCancel() async throws {
    let session = try await TurnAnnouncementFixtures.open(turns: [[ScriptedSession.runningState, Self.cancelledState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(
      await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.cancelled)
        == ["Response cancelled"])
  }

  @Test func anIdleAfterAUserMessageThatThisClientDidNotSendAnnouncesNothing() async throws {
    let session = try await TurnAnnouncementFixtures.open(turns: [])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    try await session.sendUpdate(Self.otherUserMessage)
    try await session.sendUpdate(ScriptedSession.runningState)
    try await session.sendUpdate(ScriptedSession.endTurnState)

    #expect(await TurnAnnouncementFixtures.collect(announcements, of: session, endingWith: Self.endTurn).isEmpty)
  }
}
