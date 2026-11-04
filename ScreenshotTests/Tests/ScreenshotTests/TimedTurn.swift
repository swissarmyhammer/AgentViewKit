import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import Testing

/// A scripted session on a `FixedClock` that starts at
/// `TimedSessionClock.start`, played one event at a time: each step sends
/// one event, waits until the model takes it, and then moves the clock
/// `TimedSessionClock.stepSeconds`.
///
/// The timed gallery fixtures play their turns through it, so every entry
/// they show starts at a known time and each entry that ends takes known
/// steps. Each fixture keeps its own list of events.
@MainActor
struct TimedTurn {
  /// The longest wait for the model to take one event, in seconds.
  static let settleSeconds = 10

  /// The longest wait for the model to take one event.
  static let settleLimit = Duration.seconds(settleSeconds)

  /// The clock that the connection model reads.
  let clock: FixedClock

  /// The scripted session. The caller closes it.
  let session: ScriptedSession

  /// The session model.
  var model: SessionModel { session.model }

  /// Opens the scripted session on a clock at `TimedSessionClock.start`.
  ///
  /// - Returns: The turn, with no event sent yet.
  /// - Throws: The error of the session.
  static func open() async throws -> TimedTurn {
    let clock = FixedClock(start: TimedSessionClock.start)
    return TimedTurn(clock: clock, session: try await ScriptedSession.open(now: clock.now))
  }

  /// Sends one event, waits until the model takes it, and moves the clock
  /// one step.
  ///
  /// - Parameters:
  ///   - send: Sends the event.
  ///   - isTaken: Whether the model shows the event.
  /// - Throws: The error of the transport.
  func step(_ send: () async throws -> Void, until isTaken: @MainActor () -> Bool) async throws {
    try await send()
    await ObservationWait.until(within: Self.settleLimit, isTaken)
    clock.advance(by: TimedSessionClock.stepSeconds)
  }

  /// Sends one event that adds an entry: a ``step(_:until:)`` that waits
  /// until the transcript holds one more entry.
  ///
  /// - Parameter send: Sends the event.
  /// - Throws: The error of the transport.
  func addEntry(_ send: () async throws -> Void) async throws {
    let model = model
    let count = model.transcript.count
    try await step(send) { model.transcript.count > count }
  }

  /// Sends one `session/update` that adds an entry.
  ///
  /// - Parameter update: The JSON text of the update.
  /// - Throws: The error of the transport.
  func addEntry(_ update: String) async throws {
    try await addEntry { try await session.sendUpdate(update) }
  }
}
