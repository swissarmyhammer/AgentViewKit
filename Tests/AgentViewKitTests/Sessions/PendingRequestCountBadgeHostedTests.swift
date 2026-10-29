import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The open question counts of the session picker (elicitation-plan.md §4,
/// task 40).
///
/// Each test opens three sessions on one connection: the scripted session,
/// which is the current session, and two other sessions. The agent lists the
/// three open sessions and one session that is not open. Each open session
/// gets requests of the agent. The tests send each request only after the
/// request before it is in its model (``ScriptedSession/sendInOrder(_:to:)``),
/// with no clock.
@Suite(.serialized, .hostedSerially) @MainActor struct PendingRequestCountBadgeHostedTests {
  /// The id of the second open session.
  static let secondSessionID = SessionId(rawValue: "second-session")

  /// The id of the third open session.
  static let thirdSessionID = SessionId(rawValue: "third-session")

  /// The id of the listed session that is not open.
  static let closedSessionID = SessionId(rawValue: "closed-session")

  /// The `session/new` result of a session.
  ///
  /// - Parameter id: The id of the session.
  /// - Returns: The JSON text of the result.
  static func newSessionResult(_ id: SessionId) -> String {
    #"{"sessionId": "\#(id.rawValue)"}"#
  }

  /// The `session/list` result: the three open sessions and the session that
  /// is not open.
  static let listPage = #"""
    {"sessions": [
       {"sessionId": "\#(ScriptedSession.sessionID)", "cwd": "\#(ScriptedSession.workingDirectory)", "title": "Current"},
       {"sessionId": "\#(secondSessionID.rawValue)", "cwd": "\#(ScriptedSession.workingDirectory)", "title": "Second"},
       {"sessionId": "\#(thirdSessionID.rawValue)", "cwd": "\#(ScriptedSession.workingDirectory)", "title": "Third"},
       {"sessionId": "\#(closedSessionID.rawValue)", "cwd": "\#(ScriptedSession.workingDirectory)", "title": "Closed"}]}
    """#

  /// The three open sessions of one connection.
  struct Fixture {
    /// The scripted session. It is the current session of the picker.
    let session: ScriptedSession

    /// The model of the second open session.
    let second: SessionModel

    /// The model of the third open session.
    let third: SessionModel
  }

  /// Opens the three sessions, mounts the picker, and sends the requests of
  /// the agent: one permission request to the current session, one permission
  /// request and one form elicitation to the second session, and one
  /// permission request to the third session. Then the harness renders when
  /// both other sessions have their requests.
  ///
  /// - Returns: The fixture and the harness that shows the picker.
  /// - Throws: The error of `initialize`, of `session/new` or of the
  ///   transport.
  static func openSessionsWithRequests() async throws -> (Fixture, HostedViewHarness<some View>) {
    let session = try await ScriptedSession.open { agent in
      agent.resultQueues["session/new"] = [
        newSessionResult(SessionId(rawValue: ScriptedSession.sessionID)), newSessionResult(secondSessionID),
        newSessionResult(thirdSessionID),
      ]
      agent.resultQueues["session/list"] = [listPage]
    }
    let directory = AbsolutePath(rawValue: ScriptedSession.workingDirectory)
    let second = try await session.connection.newSession(NewSessionRequest(cwd: directory))
    let third = try await session.connection.newSession(NewSessionRequest(cwd: directory))
    let harness = await SessionPickerConnectionModelHostedTests.mountPicker(
      session, currentSession: session.model.sessionId)
    try await session.sendInOrder([.permission(id: 1)])
    try await session.sendInOrder(
      [
        .permission(id: 2, sessionId: secondSessionID),
        .formElicitation(id: 3, sessionId: secondSessionID),
      ], to: second)
    try await session.sendInOrder([.permission(id: 4, sessionId: thirdSessionID)], to: third)
    await harness.render { !second.pendingRequests.isEmpty && !third.pendingRequests.isEmpty }
    return (Fixture(session: session, second: second, third: third), harness)
  }

  /// The label of the row of a session.
  ///
  /// - Parameters:
  ///   - id: The id of the session.
  ///   - harness: The harness that shows the picker.
  /// - Returns: The accessibility label of the row, or `nil`.
  static func rowLabel(of id: SessionId, in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: SessionListView.rowIdentifier(for: id))?.label
  }

  /// The badge is visual only, so the row label is the one reading of the
  /// count. The current session has a request, but its row label has no
  /// count text. The session that is not open has no model and no count.
  @Test func twoOtherOpenSessionsShowTheirCountsAndTheCurrentSessionShowsNoCount() async throws {
    let (fixture, harness) = try await Self.openSessionsWithRequests()
    defer { fixture.session.close() }
    defer { harness.close() }
    let current = fixture.session.model.sessionId

    #expect(fixture.session.model.pendingRequests.count == 1)
    #expect(Self.rowLabel(of: Self.secondSessionID, in: harness) == "Second, 2 open questions")
    #expect(Self.rowLabel(of: Self.thirdSessionID, in: harness) == "Third, 1 open question")
    #expect(Self.rowLabel(of: current, in: harness) == "Current")
    #expect(Self.rowLabel(of: Self.closedSessionID, in: harness) == "Closed")
    #expect(!harness.hasElement(label: "2"))
    #expect(!harness.hasElement(label: "1"))
  }

  /// The answer removes the elicitation from the model of the second
  /// session in the same main-actor step. The wait is
  /// ``ObservationWait/until(_:)`` on that change, which is certain to come.
  @Test func anAnswerChangesTheCountOfItsSession() async throws {
    let (fixture, harness) = try await Self.openSessionsWithRequests()
    defer { fixture.session.close() }
    defer { harness.close() }
    let second = fixture.second
    let elicitation = try #require(second.pendingElicitations.first)

    second.acceptElicitation(elicitation.id)
    await ObservationWait.until { second.pendingRequests.count == 1 }
    harness.render()

    #expect(Self.rowLabel(of: Self.secondSessionID, in: harness) == "Second, 1 open question")
    #expect(!harness.hasElement(label: "1"))
  }

  /// The answer removes the permission request from the model of the third
  /// session before the call returns, so the test requires the empty list
  /// at once and then renders. A row with 0 requests has no count text.
  @Test func theAnswerOfTheLastRequestRemovesTheCountText() async throws {
    let (fixture, harness) = try await Self.openSessionsWithRequests()
    defer { fixture.session.close() }
    defer { harness.close() }
    let third = fixture.third
    let permission = try #require(third.pendingPermissions.first)

    await third.selectPermission(permission.id, option: PermissionOptionId(rawValue: "yes"))
    try #require(third.pendingRequests.isEmpty)
    harness.render()

    #expect(Self.rowLabel(of: Self.thirdSessionID, in: harness) == "Third")
  }
}
