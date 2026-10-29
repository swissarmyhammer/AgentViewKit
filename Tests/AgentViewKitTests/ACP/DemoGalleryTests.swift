import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Tests of the scripted part of the Gallery tab of the demo app: the
/// sessions of ``DemoGallery`` and the connection states of
/// ``DemoConnectionState``.
///
/// ``InMemoryDemoACPAgent`` serves each scripted session. Most tests check
/// only that each session opens and shows a transcript. They do not read the
/// content of a session, because the sessions are fixtures that change. The
/// tests of the waiting sessions read only the last state and the requests:
/// FoundationModelsACPAgent reports idle while its requests wait, and other
/// agents report `requires_action`, so the Gallery shows both.
@Suite struct DemoGalleryTests {
  /// Starts the in-memory agent with the gallery script.
  ///
  /// - Returns: The connected agent.
  /// - Throws: The error of `initialize`.
  private static func makeGalleryAgent() async throws -> DemoAgent {
    try await DemoAgent.makeInProcess(script: .gallery)
  }

  /// Resumes a scripted session from the start of its history.
  ///
  /// - Parameters:
  ///   - scripted: The scripted session.
  ///   - agent: The connected gallery agent.
  /// - Returns: The session model of the resumed session.
  /// - Throws: The error of `session/resume`.
  private static func resume(_ scripted: DemoGallerySession, on agent: DemoAgent) async throws -> SessionModel {
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: scripted.id), replayFrom: .start(ReplayFromStart()))
    return try await agent.connection.resumeSession(request)
  }

  @Test func theInProcessAgentStartsInTheWorkingDirectoryOfTheInMemorySessions() async throws {
    let agent = try await Self.makeGalleryAgent()

    #expect(agent.workingDirectory.rawValue == InMemoryDemoAgent.sessionCwd)
    await agent.stop()
  }

  @Test func aWaitingSessionEndsInTheRequiresActionStateWithItsRequests() {
    let request = DemoAgentRequest.elicitation(#"{"sessionId": "waiting", "mode": "form"}"#)

    let session = DemoGallery.waitingSession(
      id: "waiting", title: "Waiting", prompt: "Start.", reply: "Wait.", requests: [request])

    #expect(session.history.last == DemoGallery.requiresActionState)
    #expect(session.requests.count == 1)
  }

  /// The scripted sessions whose requests wait for the user while the
  /// history ends in `idle`, as FoundationModelsACPAgent reports them.
  static let idleWaitingSessions = DemoGallery.sessions.filter {
    !$0.requests.isEmpty && !$0.history.contains(DemoGallery.requiresActionState)
  }

  @Test func oneWaitingSessionEndsInIdleWithItsRequestsAsACPAgentReportsIt() throws {
    let session = try #require(Self.idleWaitingSessions.first)

    #expect(Self.idleWaitingSessions.count == 1)
    #expect(session.history.last == DemoGallery.idleState(stopReason: "end_turn"))
    #expect(session.requests.count == 1)
  }

  @Test func theOtherWaitingSessionsKeepTheRequiresActionStateForOtherAgents() {
    let requiresAction = DemoGallery.sessions.filter { $0.history.last == DemoGallery.requiresActionState }

    #expect(
      requiresAction.map(\.id)
        == [DemoGallery.permission, DemoGallery.formElicitation, DemoGallery.urlElicitation].map(\.id))
  }

  /// The resume replays the history before its response, so the state of the
  /// session model does not depend on the requests that the agent sends
  /// after the resume.
  @Test func theResumedIdleWaitingSessionReportsIdleAndNotRequiresAction() async throws {
    let scripted = try #require(Self.idleWaitingSessions.first)
    let agent = try await Self.makeGalleryAgent()

    let session = try await Self.resume(scripted, on: agent)

    #expect(session.agentState == .idle(IdleStateUpdate(stopReason: .endTurn)))
    await agent.stop()
  }

  /// The scripted sessions with requests that the agent sends after each
  /// resume. The value is constant data, so it is not isolated to the main
  /// actor, and `@Test(arguments:)` reads it.
  nonisolated static let sessionsWithRequests = DemoGallery.sessions.filter { !$0.requests.isEmpty }

  /// A fixed-order test (task ^4tw540d): the agent sends the requests of the
  /// session at once after the resume result. The client opens the session
  /// model before the resume request goes out (FoundationModelsACPClient
  /// d321543), so each request is pending on the session model. The test
  /// waits on the observable session model, for an event that is certain to
  /// come.
  @Test(arguments: sessionsWithRequests)
  func eachRequestThatComesAtOnceAfterTheResumeResultIsPendingOnTheSessionModel(
    _ scripted: DemoGallerySession
  ) async throws {
    let agent = try await Self.makeGalleryAgent()
    let sessionId = SessionId(rawValue: scripted.id)

    _ = try await Self.resume(scripted, on: agent)
    await ObservationWait.until { agent.connection.pendingRequestCount(of: sessionId) == scripted.requests.count }

    let session = try #require(agent.connection.session(for: sessionId))
    #expect(session.pendingElicitations.count == scripted.requests.count(where: \.isElicitation))
    #expect(session.pendingPermissions.count == scripted.requests.count { !$0.isElicitation })
    await agent.stop()
  }

  /// The pending edit of the permission session names its file, so the
  /// Gallery shows a location chip that selects the file in the inspector.
  @Test func theScriptedToolCallOfThePermissionSessionNamesItsFile() async throws {
    let agent = try await Self.makeGalleryAgent()

    let session = try await Self.resume(DemoGallery.permission, on: agent)

    let paths = session.transcript.flatMap { entry -> [String] in
      if case .toolCall(let call) = entry { call.locations.map(\.path.rawValue) } else { [] }
    }
    #expect(paths == [DemoGallery.greetingPath])
    await agent.stop()
  }

  @Test func theSessionListOfTheGalleryAgentHasEachScriptedSession() async throws {
    let agent = try await Self.makeGalleryAgent()

    try await agent.connection.refreshSessions()

    let listed = Set(agent.connection.sessions.map(\.sessionId))
    #expect(listed.isSuperset(of: DemoGallery.sessions.map { SessionId(rawValue: $0.id) }))
    await agent.stop()
  }

  @Test(arguments: DemoGallery.sessions)
  func eachScriptedSessionOpensWithATranscript(_ scripted: DemoGallerySession) async throws {
    let agent = try await Self.makeGalleryAgent()

    let session = try await Self.resume(scripted, on: agent)

    #expect(!session.transcript.isEmpty)
    await agent.stop()
  }

  @Test(arguments: DemoConnectionState.allCases)
  func eachConnectionStateOpensWithATranscript(_ state: DemoConnectionState) async throws {
    let opened = try await state.open()

    #expect(!opened.session.transcript.isEmpty)
    await opened.agent.stop()
  }
}

extension DemoAgentRequest {
  /// Whether the request is an `elicitation/create` request.
  fileprivate var isElicitation: Bool {
    if case .elicitation = self { true } else { false }
  }
}
