/// One scripted session of the Gallery tab of the demo app.
///
/// ``InMemoryDemoACPAgent`` lists the session with `session/list`. A
/// `session/resume` with `replayFrom: .start` sends each update of
/// ``history`` before its result. After its result, the agent sends each
/// request of ``requests``, and the request waits for the answer of the user.
/// Thus the thread of the session shows the pending requests, as the thread
/// of a live session does.
///
/// The value is constant data, so the type is not isolated to the main
/// actor, and ``InMemoryDemoACPAgent`` reads it from its own actor.
nonisolated public struct DemoGallerySession: Sendable, CustomStringConvertible {
  /// The id of the session.
  public let id: String

  /// The title that `session/list` gives.
  public let title: String

  /// The JSON text of the `update` member of each `session/update` that a
  /// resume from the start sends, in send order.
  let history: [String]

  /// The requests that the agent sends after the result of each resume.
  let requests: [DemoAgentRequest]

  /// The updates of the child sessions, each one in the stream of its own
  /// session. A resume from the start sends them after ``history``, in the
  /// replay phase. The model is parent and child all the way down, so an
  /// update can name a session at any level.
  let childUpdates: [DemoStreamUpdate]

  /// The current snapshots of the child sessions. A resume sends them after
  /// its result, before ``requests``. A child is unconfirmed until its first
  /// current snapshot.
  let currentSnapshots: [DemoStreamUpdate]

  /// Makes a scripted session.
  ///
  /// - Parameters:
  ///   - id: The id of the session.
  ///   - title: The title that `session/list` gives.
  ///   - history: The JSON text of the updates of a replay.
  ///   - requests: The requests that the agent sends after each resume.
  ///   - childUpdates: The updates of the child sessions, sent in a replay.
  ///   - currentSnapshots: The snapshots of the child sessions that the agent
  ///     sends after the result of a resume.
  init(
    id: String, title: String, history: [String], requests: [DemoAgentRequest],
    childUpdates: [DemoStreamUpdate] = [], currentSnapshots: [DemoStreamUpdate] = []
  ) {
    self.id = id
    self.title = title
    self.history = history
    self.requests = requests
    self.childUpdates = childUpdates
    self.currentSnapshots = currentSnapshots
  }

  /// The id of the session. Swift Testing shows it as the name of a test
  /// argument.
  public var description: String {
    id
  }
}

/// A request from the agent to the client that waits for the user.
nonisolated enum DemoAgentRequest: Sendable {
  /// A `session/request_permission` request, with the JSON text of its
  /// params.
  case permission(String)

  /// An `elicitation/create` request, with the JSON text of its params.
  case elicitation(String)
}

/// One `session/update` of a scripted session, with the session whose stream
/// carries it.
nonisolated struct DemoStreamUpdate: Sendable {
  /// The id of the session whose stream carries the update.
  let sessionId: String

  /// The JSON text of the `update` member.
  let update: String
}
