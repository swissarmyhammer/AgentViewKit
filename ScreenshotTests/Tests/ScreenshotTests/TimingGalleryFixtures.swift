@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import Testing

/// The timed thread of the timing images: a scripted session whose
/// connection model reads a ``FixedClock`` that moves ``stepSeconds`` after
/// each update, so each entry has a known start time and, once it ends, a
/// duration that shows.
///
/// The thread holds a user message, a thought, a tool call that runs and
/// then completes, and a last agent message that the idle state ends. Each
/// row shows its start time in EditorKit's `DateText`, and each entry that
/// took a shown time shows its duration in `DurationText`. The thought's
/// title tells its duration in words.
@MainActor
enum TimingGalleryFixtures {
  /// The first time of the clock, which the clock of
  /// ``InspectorGalleryFixtures`` starts at too.
  static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

  /// The time the clock moves after each update, in seconds: one minute and
  /// fifteen seconds, so each duration shows both of its units.
  static let stepSeconds: TimeInterval = 75

  /// The longest wait for the model to take one update, in seconds.
  static let settleSeconds = 10

  /// The longest wait for the model to take one update.
  static let settleLimit = Duration.seconds(settleSeconds)

  /// The `messageId` of the user message.
  static let userMessageID = "timing-user"

  /// The `messageId` of the thought.
  static let thoughtID = "timing-thought"

  /// The `messageId` of the last agent message.
  static let answerID = "timing-answer"

  /// The title, and thus the `toolCallId`, of the tool call.
  static let callTitle = "Run swift test --filter CheckoutTests"

  /// A chunk of one text block.
  ///
  /// - Parameters:
  ///   - kind: The `sessionUpdate` tag, such as `agent_message_chunk`.
  ///   - messageID: The `messageId` of the chunk.
  ///   - text: The text of the block.
  /// - Returns: The JSON text of the update.
  private static func chunk(_ kind: String, messageID: String, text: String) -> String {
    WireBlockJSON.makeChunk(kind, messageID: messageID, block: WireBlockJSON.makeText(text))
  }

  /// Opens the timed session and plays the turn, moving the clock one step
  /// after the model takes each update.
  ///
  /// - Returns: The open session. The caller closes it.
  /// - Throws: The error of the session or of the transport.
  static func openSession() async throws -> ScriptedSession {
    let clock = FixedClock(start: start)
    let session = try await ScriptedSession.open(now: clock.now)
    let model = session.model
    try await send(chunk("user_message_chunk", messageID: userMessageID, text: "Run the checkout tests."), to: session) {
      model.transcript.count == 1
    }
    clock.advance(by: stepSeconds)
    try await send(chunk("agent_thought_chunk", messageID: thoughtID, text: "Run only that module."), to: session) {
      model.transcript.count == 2
    }
    clock.advance(by: stepSeconds)
    try await session.sendToolCallUpdate(title: callTitle, status: .inProgress)
    await ObservationWait.until(within: settleLimit) { model.transcript.count == 3 }
    clock.advance(by: stepSeconds)
    try await session.sendToolCallUpdate(title: callTitle, status: .completed)
    await ObservationWait.until(within: settleLimit) { isCallCompleted(in: model) }
    try await send(chunk("agent_message_chunk", messageID: answerID, text: "The 18 tests pass."), to: session) {
      model.transcript.count == 4
    }
    clock.advance(by: stepSeconds)
    try await send(ScriptedSession.idleState, to: session) { model.transcript.last?.timing.endedAt != nil }
    return session
  }

  /// Sends one update and waits until the model took it.
  ///
  /// - Parameters:
  ///   - update: The JSON text of the update.
  ///   - session: The scripted session.
  ///   - isTaken: Whether the model shows the update.
  /// - Throws: The error of the transport.
  private static func send(
    _ update: String, to session: ScriptedSession, until isTaken: @MainActor () -> Bool
  ) async throws {
    try await session.sendUpdate(update)
    await ObservationWait.until(within: settleLimit, isTaken)
  }

  /// Whether the tool call of the turn has completed.
  ///
  /// - Parameter model: The session model.
  /// - Returns: `true` once the status of the call is `completed`.
  private static func isCallCompleted(in model: SessionModel) -> Bool {
    PreviewFixtures.firstEntry(in: model, as: ToolCallEntry.self)?.status == .completed
  }
}
