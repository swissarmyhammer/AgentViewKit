import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient

/// The scripted sessions of the turn announcement tests, and the collection
/// of their announcements.
///
/// The turn announcement tests and the hosted tests of the order of the work
/// of the agent share these helpers.
public enum TurnAnnouncementFixtures {
  /// Opens a scripted session whose agent answers each prompt in the
  /// ACPAgent order.
  ///
  /// - Parameter turns: The `session/update` values that the agent sends
  ///   after the echo of each prompt, one list for each prompt, in prompt
  ///   order. A prompt with no list gets no update.
  /// - Returns: The scripted session.
  /// - Throws: The error of the JSON parser, or of the open.
  public static func open(turns: [[String]]) async throws -> ScriptedSession {
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
  public static func collect(
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
}
