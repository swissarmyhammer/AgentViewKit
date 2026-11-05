@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import Testing

/// The timed thread of the timing images, played as a ``TimedTurn``: each
/// entry has a known start time and, once it ends, a duration that shows.
///
/// The thread holds a user message, a thought, a tool call that runs and
/// then completes, and a last agent message that the idle state ends. Each
/// row shows its start time, and each entry that took a shown time shows its
/// duration after it, in one line such as "6:13 AM · 1m 15s". The thought's
/// title tells its duration in words.
@MainActor
enum TimingGalleryFixtures {
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

  /// Opens the timed session and plays the turn, one ``TimedTurn`` step
  /// for each event.
  ///
  /// - Returns: The open session. The caller closes it.
  /// - Throws: The error of the session or of the transport.
  static func openSession() async throws -> ScriptedSession {
    let turn = try await TimedTurn.open()
    let session = turn.session
    let model = turn.model
    try await turn.addEntry(userMessage)
    try await turn.addEntry(thought)
    try await turn.addEntry { try await session.sendToolCallUpdate(title: callTitle, status: .inProgress) }
    try await turn.step({ try await session.sendToolCallUpdate(title: callTitle, status: .completed) }) {
      isCallCompleted(in: model)
    }
    try await turn.addEntry(answer)
    try await turn.step({ try await session.sendUpdate(ScriptedSession.idleState) }) {
      model.transcript.last?.timing.endedAt != nil
    }
    return session
  }

  /// Whether the tool call of the turn has completed.
  ///
  /// - Parameter model: The session model.
  /// - Returns: `true` once the status of the call is `completed`.
  private static func isCallCompleted(in model: SessionModel) -> Bool {
    PreviewFixtures.firstEntry(in: model, as: ToolCallEntry.self)?.status == .completed
  }
}
