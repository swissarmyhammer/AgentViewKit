import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Fixed-order tests of the requests that ``InMemoryDemoACPAgent`` sends at
/// once after the `session/new` result.
///
/// The agent sends the requests of ``InMemoryDemoScript/newSessionRequests``
/// from `afterRespondingToCurrentRequest`. Thus a request can come to the
/// client before the client opens the session model of the new session. The
/// client keeps such a request until the session model is open
/// (FoundationModelsACPClient 9cedcb9), so each request is pending on the
/// session model. Before that fix, the client answered `cancel`, and no
/// request was pending.
///
/// The test waits on the observable session model, for an event that is
/// certain to come. No test reads a clock, polls, or has a time limit.
@Suite struct NewSessionRequestTests {
  /// The id of the session that `session/new` gives.
  static let sessionId = SessionId(rawValue: InMemoryDemoAgent.sessionID)

  /// A form elicitation of the new session.
  static let elicitation = DemoAgentRequest.elicitation(
    #"""
    {"sessionId": "\#(InMemoryDemoAgent.sessionID)", "mode": "form", "message": "Name the new session.",
     "requestedSchema": {"type": "object", "properties": {"name": {"type": "string"}}}}
    """#)

  /// A permission request of the new session.
  static let permission = DemoAgentRequest.permission(
    #"""
    {"sessionId": "\#(InMemoryDemoAgent.sessionID)", "title": "Read the workspace",
     "options": [{"optionId": "allow-once", "name": "Allow", "kind": "allow_once"},
                 {"optionId": "reject-once", "name": "Reject", "kind": "reject_once"}]}
    """#)

  /// The script: no sign-in, no scripted session, and the two requests after
  /// the `session/new` result.
  static let script = InMemoryDemoScript(
    signIn: .notAdvertised, sessions: [], newSessionRequests: [elicitation, permission])

  @Test func eachRequestThatComesAtOnceAfterTheNewSessionResultIsPendingOnTheSessionModel() async throws {
    let agent = try await DemoAgent.makeInProcess(script: Self.script)
    let connection = agent.connection

    _ = try await connection.newSession(NewSessionRequest(cwd: agent.workingDirectory))
    await ObservationWait.until {
      connection.pendingRequestCount(of: Self.sessionId) == Self.script.newSessionRequests.count
    }

    let session = try #require(connection.session(for: Self.sessionId))
    #expect(session.pendingElicitations.count == 1)
    #expect(session.pendingPermissions.count == 1)
    await agent.stop()
  }
}
