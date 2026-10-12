import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import DemoSupport

/// Tests of the scripted part of the Gallery tab of the demo app: the
/// sessions of ``DemoGallery`` and the connection states of
/// ``DemoConnectionState``.
///
/// ``InMemoryDemoACPAgent`` serves each scripted session. The tests check
/// only that each session opens and shows a transcript. They do not read the
/// content of a session, because the sessions are fixtures that change.
@Suite struct DemoGalleryTests {
  /// Starts the in-memory agent with the gallery script.
  ///
  /// - Returns: The connected agent.
  /// - Throws: The error of `initialize`.
  private static func makeGalleryAgent() async throws -> DemoAgent {
    try await DemoAgent.makeInProcess(script: .gallery, workingDirectory: AbsolutePath(rawValue: InMemoryDemoAgent.sessionCwd))
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
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: SessionId(rawValue: scripted.id), replayFrom: .start(ReplayFromStart()))

    let session = try await agent.connection.resumeSession(request)

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
