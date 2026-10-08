import FoundationModelsACP
import Testing

@testable import AgentViewKit

/// Tests of `ResumeSessionRequest.makeAgentViewKitRequest(sessionId:cwd:additionalDirectories:replayFrom:)`:
/// the one `session/resume` request that the Reload button and the session
/// picker send (plan.md §3.8 "Resume").
@Suite struct ResumeSessionRequestTests {
  /// The session that the requests resume.
  static let sessionId = SessionId(rawValue: "session-1")

  /// The working directory of the session.
  static let cwd = AbsolutePath(rawValue: "/tmp/project")

  /// The two additional workspace roots of the session.
  static let additionalDirectories = [AbsolutePath(rawValue: "/tmp/shared-lib"), AbsolutePath(rawValue: "/tmp/docs")]

  @Test func theRequestHasTheWorkingDirectoryAndTheFullListOfAdditionalDirectories() {
    let request = ResumeSessionRequest.makeAgentViewKitRequest(
      sessionId: Self.sessionId, cwd: Self.cwd, additionalDirectories: Self.additionalDirectories,
      replayFrom: .start(ReplayFromStart()))

    #expect(
      request
        == ResumeSessionRequest(
          cwd: Self.cwd, sessionId: Self.sessionId, additionalDirectories: Self.additionalDirectories,
          replayFrom: .start(ReplayFromStart())))
  }

  @Test func anEmptyListGivesARequestWithNoAdditionalDirectories() {
    let request = ResumeSessionRequest.makeAgentViewKitRequest(
      sessionId: Self.sessionId, cwd: Self.cwd, additionalDirectories: [], replayFrom: .start(ReplayFromStart()))

    #expect(request.additionalDirectories == nil)
  }

  @Test func theRequestHasTheReplayCursorOfTheCaller() {
    let request = ResumeSessionRequest.makeAgentViewKitRequest(
      sessionId: Self.sessionId, cwd: Self.cwd, additionalDirectories: [], replayFrom: nil)

    #expect(request.replayFrom == nil)
  }
}
