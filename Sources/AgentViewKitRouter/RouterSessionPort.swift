import FoundationModels
import FoundationModelsExtras
import FoundationModelsRouter

/// The calls that ``RouterThreadSource`` and ``RouterThreadActions`` make on a
/// Router session (plan.md §3.3, §3.4).
///
/// `RoutedSession` is a large actor protocol. This protocol holds only the
/// calls that the adapter uses, so that a test can give a fake session that
/// records each call. ``RoutedSessionPort`` gives these calls to a real
/// `RoutedSession`.
public protocol RouterSessionPort: AnyObject {
  /// The rows of the transcript of the session, grouped as
  /// `SessionProjection.transcript` groups them.
  ///
  /// - Returns: The rows, oldest first.
  func transcriptRows() async -> [SessionProjection.TranscriptEntry]

  /// The events that belong to the session, from
  /// `RoutedSession.streamSessionEvents()`.
  ///
  /// - Returns: A new subscription to the session events.
  func sessionEvents() async -> AsyncStream<SessionEvent>

  /// Starts a turn for the prompt, through `RoutedSession.streamEvents(to:)`.
  ///
  /// - Parameter prompt: The text of the user.
  /// - Returns: The events of the turn.
  func promptEvents(for prompt: String) async -> AsyncThrowingStream<SessionEvent, any Error>

  /// Stops the turn that runs now, through `RoutedSession.cancelCurrentTurn()`.
  func cancelCurrentTurn() async

  /// Sends the answer of the user to a pending elicitation, through
  /// `RoutedSession.respond(elicitationId:response:)`.
  ///
  /// - Parameters:
  ///   - elicitationId: The identifier of the elicitation.
  ///   - response: The answer of the user.
  func respond(elicitationId: String, response: ElicitationResponse) async

  /// Tells the session that the flow of an accepted URL elicitation is
  /// complete, through `RoutedSession.complete(elicitationId:)`.
  ///
  /// - Parameter elicitationId: The identifier of the elicitation.
  func complete(elicitationId: String) async
}

/// A ``RouterSessionPort`` that sends each call to a `RoutedSession`.
public final class RoutedSessionPort: RouterSessionPort {
  /// The session that gets the calls.
  public let session: any RoutedSession

  /// Makes a port.
  ///
  /// - Parameter session: The session that gets the calls.
  public init(session: any RoutedSession) {
    self.session = session
  }

  public func transcriptRows() async -> [SessionProjection.TranscriptEntry] {
    let projection = SessionProjection()
    projection.seed(from: await session.transcript)
    return projection.transcript
  }

  public func sessionEvents() async -> AsyncStream<SessionEvent> {
    await session.streamSessionEvents()
  }

  public func promptEvents(for prompt: String) async -> AsyncThrowingStream<SessionEvent, any Error> {
    await session.streamEvents(to: prompt)
  }

  public func cancelCurrentTurn() async {
    await session.cancelCurrentTurn()
  }

  public func respond(elicitationId: String, response: ElicitationResponse) async {
    await session.respond(elicitationId: elicitationId, response: response)
  }

  public func complete(elicitationId: String) async {
    await session.complete(elicitationId: elicitationId)
  }
}
