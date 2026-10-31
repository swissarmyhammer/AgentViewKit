import AgentViewKit
import FoundationModelsACP
import Testing

@testable import AgentViewKitDemoSupport

/// Fixed-order wire tests of `session/cancel` on ``InMemoryDemoACPAgent``.
///
/// A raw client resumes a scripted session of the gallery script. After the
/// resume result, the agent sends the elicitation of the session, which
/// waits for an answer. The client then sends `session/cancel`, and then a
/// marker request. The connection of the agent handles a notification before
/// it reads the next frame, so the agent ends its work for the cancel before
/// it reads the marker request: each frame that the cancel handler writes
/// comes before the response to the marker request.
///
/// The connection of the agent sends the `$/cancel_request` of a cancelled
/// request from a task of its own, so that frame can also come after the
/// response to the marker request. The test then reads on until it comes.
/// No test reads a clock, polls, or has a time limit.
@MainActor @Suite struct InMemoryDemoACPAgentCancelTests {
  /// The JSON-RPC id of the `session/resume` request.
  static let resumeRequestID = 1.0

  /// The JSON-RPC id of the marker request after the cancel.
  static let markerRequestID = 2.0

  /// The scripted session that waits for the answer to an elicitation.
  static let session = DemoGallery.formElicitation

  /// The `sessionId` and the `cwd` of the `session/resume` request, with no
  /// replay.
  static var resumeParams: JSONValue {
    .object(["sessionId": .string(session.id), "cwd": .string(InMemoryDemoAgent.sessionCwd)])
  }

  /// The params of the `session/cancel` notification.
  static var cancelParams: JSONValue {
    .object(["sessionId": .string(session.id)])
  }

  /// Tells if `frame` is the response to the request with `id`.
  ///
  /// - Parameters:
  ///   - frame: A frame of the agent.
  ///   - id: The JSON-RPC id of the request of the client.
  /// - Returns: `true` for the response.
  static func isResponse(_ frame: JSONValue, to id: Double) -> Bool {
    frame["method"] == nil && frame["id"] == .number(id)
  }

  /// Tells if `frame` is an `elicitation/create` request of the agent.
  ///
  /// - Parameter frame: A frame of the agent.
  /// - Returns: `true` for the request.
  static func isElicitation(_ frame: JSONValue) -> Bool {
    frame["method"]?.stringValue == "elicitation/create" && frame["id"] != nil
  }

  /// Tells if `frame` is a `$/cancel_request` notification of the agent.
  ///
  /// - Parameter frame: A frame of the agent.
  /// - Returns: `true` for the notification.
  static func isCancelRequest(_ frame: JSONValue) -> Bool {
    frame["method"]?.stringValue == "$/cancel_request"
  }

  /// Tells if `frame` is the `session/update` of the session that reports
  /// `idle` with the `cancelled` stop reason.
  ///
  /// - Parameter frame: A frame of the agent.
  /// - Returns: `true` for the update.
  static func isCancelledIdle(_ frame: JSONValue) -> Bool {
    let params = frame["params"]
    return frame["method"]?.stringValue == "session/update" && params?["sessionId"] == .string(session.id)
      && params?["update"]?["sessionUpdate"] == .string("state_update")
      && params?["update"]?["state"] == .string("idle")
      && params?["update"]?["stopReason"] == .string("cancelled")
  }

  @Test func aCancelEndsTheOpenRequestWithACancelRequestAndSendsTheCancelledIdle() async throws {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let connection = await AgentSideConnection(stream: agentEnd) { connection in
      InMemoryDemoACPAgent(connection: connection, script: .gallery)
    }
    let client = RawWireClient(transport: clientEnd)

    try await client.request(method: "session/resume", id: Self.resumeRequestID, params: Self.resumeParams)
    let opened = try await client.frames(through: Self.isElicitation)
    let elicitationID = try #require(opened.last?["id"])
    try await client.notify(method: "session/cancel", params: Self.cancelParams)
    try await client.request(method: "session/list", id: Self.markerRequestID, params: .object([:]))
    let throughMarker = try await client.frames { Self.isResponse($0, to: Self.markerRequestID) }

    try #require(throughMarker.contains(where: Self.isCancelledIdle))
    var cancelRequests = throughMarker.filter(Self.isCancelRequest)
    if cancelRequests.isEmpty {
      cancelRequests = try await client.frames(through: Self.isCancelRequest).filter(Self.isCancelRequest)
    }
    #expect(cancelRequests.map { $0["params"]?["requestId"] } == [elicitationID])
    await connection.close()
  }
}
