@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import Testing

/// The timed thread of the timing images: a scripted session whose
/// connection model reads a ``FixedClock`` from `TimedSessionClock.start`
/// that moves `TimedSessionClock.stepSeconds` after each event, so each
/// entry has a known start time and, once it ends, a duration that shows.
///
/// The thread holds a user message, a thought, a tool call that runs and
/// then completes, and a last agent message that the idle state ends. Each
/// row shows its start time in EditorKit's `DateText`, and each entry that
/// took a shown time shows its duration in `DurationText`. The thought's
/// title tells its duration in words.
@MainActor
enum TimingGalleryFixtures {
  /// The longest wait for the model to take one update, in seconds.
  static let settleSeconds = 10

  /// The longest wait for the model to take one update.
  static let settleLimit = Duration.seconds(settleSeconds)

  /// The title, and thus the `toolCallId`, of the tool call.
  static let callTitle = "Run swift test --filter CheckoutTests"

  /// The user message that starts the turn.
  static let userMessage = WireBlockJSON.makeChunk(
    "user_message_chunk", messageID: "timing-user", block: WireBlockJSON.makeText("Run the checkout tests."))

  /// The thought of the agent.
  static let thought = WireBlockJSON.makeChunk(
    "agent_thought_chunk", messageID: "timing-thought", block: WireBlockJSON.makeText("Run only that module."))

  /// The last agent message, which the idle state ends.
  static let answer = WireBlockJSON.makeChunk(
    "agent_message_chunk", messageID: "timing-answer", block: WireBlockJSON.makeText("The 18 tests pass."))

  /// Opens the timed session and plays the turn, moving the clock one step
  /// after the model takes each event.
  ///
  /// - Returns: The open session. The caller closes it.
  /// - Throws: The error of the session or of the transport.
  static func openSession() async throws -> ScriptedSession {
    let clock = FixedClock(start: TimedSessionClock.start)
    let session = try await ScriptedSession.open(now: clock.now)
    let model = session.model
    try await addEntry(to: model) { try await session.sendUpdate(userMessage) }
    clock.advance(by: TimedSessionClock.stepSeconds)
    try await addEntry(to: model) { try await session.sendUpdate(thought) }
    clock.advance(by: TimedSessionClock.stepSeconds)
    try await addEntry(to: model) { try await session.sendToolCallUpdate(title: callTitle, status: .inProgress) }
    clock.advance(by: TimedSessionClock.stepSeconds)
    try await session.sendToolCallUpdate(title: callTitle, status: .completed)
    await ObservationWait.until(within: settleLimit) { isCallCompleted(in: model) }
    try await addEntry(to: model) { try await session.sendUpdate(answer) }
    clock.advance(by: TimedSessionClock.stepSeconds)
    try await session.sendUpdate(ScriptedSession.idleState)
    await ObservationWait.until(within: settleLimit) { model.transcript.last?.timing.endedAt != nil }
    return session
  }

  /// Sends one event that adds an entry, and waits until the transcript
  /// holds it.
  ///
  /// - Parameters:
  ///   - model: The session model.
  ///   - send: Sends the event.
  /// - Throws: The error of the transport.
  private static func addEntry(to model: SessionModel, by send: () async throws -> Void) async throws {
    let count = model.transcript.count
    try await send()
    await ObservationWait.until(within: settleLimit) { model.transcript.count > count }
  }

  /// Whether the tool call of the turn has completed.
  ///
  /// - Parameter model: The session model.
  /// - Returns: `true` once the status of the call is `completed`.
  private static func isCallCompleted(in model: SessionModel) -> Bool {
    PreviewFixtures.firstEntry(in: model, as: ToolCallEntry.self)?.status == .completed
  }
}
