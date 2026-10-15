import AgentViewKit
import AgentViewKitTestSupport
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

  /// Opens a scripted session whose agent answers each prompt in the
  /// ACPAgent order.
  ///
  /// - Parameter turns: The `session/update` values that the agent sends
  ///   after the echo of each prompt, one list for each prompt, in prompt
  ///   order. A prompt with no list gets no update.
  /// - Returns: The scripted session.
  /// - Throws: The error of the JSON parser, or of the open.
  static func open(turns: [[String]]) async throws -> ScriptedSession {
    let frames = try turns.map { turn in
      try turn.map { ScriptedSession.sessionUpdateFrame(update: try JSONValue(json: $0)) }
    }
    return try await ScriptedSession.open {
      $0.promptEchoOrder = .afterResult
      $0.followUps[ScriptedSession.promptMethod] = { _, count in
        frames.indices.contains(count - 1) ? frames[count - 1] : []
      }
    }
  }

  /// Waits until the model of `session` has `last` as its agent state, then
  /// disconnects, and gives each announcement of `announcements`.
  ///
  /// - Parameters:
  ///   - announcements: The announcement stream of the session model.
  ///   - session: The scripted session.
  ///   - last: The last agent state that the agent sends.
  /// - Returns: The announcements, in order.
  static func collect(
    _ announcements: AsyncStream<String>, of session: ScriptedSession, endingWith last: StateUpdate
  ) async -> [String] {
    await ObservationWait.until { session.model.agentState == last }
    await session.connection.disconnect()
    // An async sequence has no `map` into an array, so the loop collects it.
    var texts: [String] = []
    for await text in announcements {
      texts.append(text)
    }
    return texts
  }

  @Test func theFirstIdleAfterTheEchoOfAPromptAnnouncesThatTheResponseIsComplete() async throws {
    let session = try await Self.open(turns: [[ScriptedSession.runningState, ScriptedSession.endTurnState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.endTurn) == ["Response complete"])
  }

  @Test func anIdleAfterBackgroundWorkOnlyAnnouncesNothing() async throws {
    let session = try await Self.open(turns: [])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    try await session.sendUpdate(ScriptedSession.runningState)
    try await session.sendUpdate(ScriptedSession.idleState)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.idle).isEmpty)
  }

  @Test func aSecondIdleWithNoNewPromptAnnouncesNothing() async throws {
    let session = try await Self.open(turns: [
      [
        ScriptedSession.runningState, ScriptedSession.endTurnState,
        ScriptedSession.runningState, ScriptedSession.idleState,
      ]
    ])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.idle) == ["Response complete"])
  }

  @Test func oneIdleThatEndsTwoOpenPromptsAnnouncesOneTime() async throws {
    let session = try await Self.open(turns: [[ScriptedSession.runningState], [ScriptedSession.endTurnState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)
    _ = try await session.model.prompt(Self.promptContent)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.endTurn) == ["Response complete"])
  }

  @Test func theIdleAfterTheEchoOfACancelledPromptAnnouncesTheCancel() async throws {
    let session = try await Self.open(turns: [[ScriptedSession.runningState, Self.cancelledState]])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    _ = try await session.model.prompt(Self.promptContent)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.cancelled) == ["Response cancelled"])
  }

  @Test func anIdleAfterAUserMessageThatThisClientDidNotSendAnnouncesNothing() async throws {
    let session = try await Self.open(turns: [])
    defer { session.close() }
    let announcements = ThreadAccessibility.makeTurnAnnouncements(of: session.model)

    try await session.sendUpdate(Self.otherUserMessage)
    try await session.sendUpdate(ScriptedSession.runningState)
    try await session.sendUpdate(ScriptedSession.endTurnState)

    #expect(await Self.collect(announcements, of: session, endingWith: Self.endTurn).isEmpty)
  }
}
