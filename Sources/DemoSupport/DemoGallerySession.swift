/// One scripted session of the Gallery tab of the demo app.
///
/// ``InMemoryDemoACPAgent`` lists the session with `session/list`. A
/// `session/resume` with `replayFrom: .start` sends each update of
/// ``history`` before its result. After its result, the agent sends each
/// request of ``requests``, and the request waits for the answer of the user.
/// Thus the thread of the session shows the pending requests, as a thread of
/// a live turn does.
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
