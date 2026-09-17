import AgentViewKit
import Foundation

/// A ``SpeechTranscriber`` that a test drives by hand.
///
/// The fake does not touch the microphone or the permission prompts of the
/// system. A test feeds each event of a session with ``feed(_:)`` and
/// ``feed(level:)``, and reads the recorded calls.
///
/// The class is isolated to the main actor, so it meets the `Sendable`
/// requirement of ``SpeechTranscriber``.
@MainActor
public final class FakeSpeechTranscriber: SpeechTranscriber {
  /// One recorded call.
  public enum Call: Equatable, Sendable {
    /// The view asked for permission.
    case requestAuthorization
    /// A session started.
    case start
    /// The session was stopped.
    case stop
  }

  /// The answer of ``requestAuthorization()``.
  public var isAuthorized: Bool

  /// Each call, in call order.
  public private(set) var calls: [Call] = []

  /// The continuation of the stream of the current session.
  private var continuation: AsyncThrowingStream<SpeechTranscriptionEvent, any Error>.Continuation?

  /// Whether a session runs now.
  public var isRunning: Bool { continuation != nil }

  /// Makes a fake.
  ///
  /// - Parameter isAuthorized: The answer of ``requestAuthorization()``.
  public init(isAuthorized: Bool = true) {
    self.isAuthorized = isAuthorized
  }

  /// Records the call and gives ``isAuthorized``.
  ///
  /// - Returns: ``isAuthorized``.
  public func requestAuthorization() async -> Bool {
    calls.append(.requestAuthorization)
    return isAuthorized
  }

  /// Records the call and starts a session.
  ///
  /// - Returns: The events that the test feeds.
  public func start() throws -> AsyncThrowingStream<SpeechTranscriptionEvent, any Error> {
    calls.append(.start)
    let (stream, continuation) = AsyncThrowingStream.makeStream(
      of: SpeechTranscriptionEvent.self, throwing: (any Error).self)
    self.continuation = continuation
    return stream
  }

  /// Records the call and finishes the stream of the session.
  public func stop() {
    calls.append(.stop)
    finish()
  }

  /// Sends a transcript to the current session.
  ///
  /// - Parameter transcript: The full transcript until now.
  public func feed(_ transcript: String) {
    continuation?.yield(.transcript(transcript))
  }

  /// Sends an input level to the current session.
  ///
  /// - Parameter level: The level, from `0` to `1`.
  public func feed(level: Double) {
    continuation?.yield(.level(level))
  }

  /// Ends the current session, as the recognizer does after a final result.
  public func finish() {
    continuation?.finish()
    continuation = nil
  }
}
