import AgentViewKitDemoSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The nested demo agent gives the tree of a root, a child and a grandchild
/// through the client model. The chain of three sessions is only a test size.
@Suite @MainActor struct NestedDemoAgentTests {
  static let root = SessionId(rawValue: DemoNestedSession.rootId)
  static let child = SessionId(rawValue: DemoNestedSession.childId)
  static let grandchild = SessionId(rawValue: DemoNestedSession.grandchildId)

  /// Resumes the nested session from the start, and waits until the agent
  /// sent its request after the result.
  static func resumeNested(
    script: InMemoryDemoScript = .nested, waitsForTheRequest: Bool = true
  ) async throws -> (DemoAgent, SessionModel) {
    let agent = try await DemoAgent.makeInProcess(script: script)
    let request = ResumeSessionRequest(
      cwd: agent.workingDirectory, sessionId: root, replayFrom: .start(ReplayFromStart()))
    let session = try await agent.connection.resumeSession(request)
    // A script with no request has nothing to wait for.
    guard waitsForTheRequest else { return (agent, session) }
    await ObservationWait.until {
      session.children.first?.children.first?.pendingRequestCount == 1
    }
    return (agent, session)
  }

  @Test func theNestedSessionIsListed() async throws {
    let agent = try await DemoAgent.makeInProcess(script: .nested)

    try await agent.connection.refreshSessions(cwd: agent.workingDirectory)

    #expect(agent.connection.sessions.map(\.sessionId).contains(Self.root))
    await agent.stop()
  }

  @Test func aResumeFromTheStartMakesTheChildAndTheGrandchild() async throws {
    let (agent, session) = try await Self.resumeNested()

    let child = try #require(session.children.first)
    let grandchild = try #require(child.children.first)

    #expect(child.sessionId == Self.child)
    #expect(child.displayTitle == DemoNestedSession.childTitle)
    #expect(grandchild.sessionId == Self.grandchild)
    #expect(grandchild.displayTitle == DemoNestedSession.grandchildTitle)
    #expect(grandchild.pathEntry.path.suffix(2) == [DemoNestedSession.childTitle, DemoNestedSession.grandchildTitle])
    await agent.stop()
  }

  @Test func eachChildIsLinkedToItsToolCall() async throws {
    let (agent, session) = try await Self.resumeNested()

    let child = try #require(session.children.first)
    let grandchild = try #require(child.children.first)

    #expect(child.startedByToolCallId == ToolCallId(rawValue: DemoNestedSession.childToolCallId))
    #expect(grandchild.startedByToolCallId == ToolCallId(rawValue: DemoNestedSession.grandchildToolCallId))
    await agent.stop()
  }

  @Test func theRequestOfTheGrandchildMarksItsAncestors() async throws {
    let (agent, session) = try await Self.resumeNested()

    let child = try #require(session.children.first)

    #expect(child.needsAttention)
    #expect(session.needsAttention)
    #expect(try #require(child.children.first).pendingRequestCount == 1)
    await agent.stop()
  }

  @Test func theSnapshotAfterTheResultConfirmsEachChild() async throws {
    let (agent, session) = try await Self.resumeNested()

    let child = try #require(session.children.first)
    let grandchild = try #require(child.children.first)

    #expect(child.isWorkStateConfirmed)
    #expect(grandchild.isWorkStateConfirmed)
    await agent.stop()
  }

  // MARK: - Wire order

  @Test func theNestedScriptFollowsTheWireRulesOfSubagentSessions() throws {
    let trace = try DemoNestedSession.session.wireTrace()

    #expect(SubagentWireTraceValidator().validate(trace).isEmpty)
  }

  @Test func theUnconfirmedScriptFollowsTheWireRulesToo() throws {
    let trace = try DemoNestedSession.unconfirmedSession.wireTrace()

    #expect(SubagentWireTraceValidator().validate(trace).isEmpty)
  }

  @Test func theSnapshotAfterTheResponseKeepsTheTitleAndGivesTheCapabilities() async throws {
    let (agent, session) = try await Self.resumeNested()

    let child = try #require(session.children.first)

    #expect(child.displayTitle == DemoNestedSession.childTitle)
    #expect(child.capabilities?.cancel != nil)
    await agent.stop()
  }

  // MARK: - A child that failed to restore, and an unconfirmed child

  @Test func aChildThatFailedToRestoreIsUnknownWithItsReasonAndSoIsItsChild() async throws {
    let (agent, session) = try await Self.resumeNested()

    let failed = try #require(session.children.last)
    let failedChild = try #require(failed.children.first)

    #expect(failed.displayTitle == DemoNestedSession.failedChildTitle)
    #expect(failed.workState == .unknown)
    #expect(failed.restoreFailure == DemoNestedSession.failedChildReason)
    #expect(failedChild.workState == .unknown)
    #expect(failedChild.restoreFailure == DemoNestedSession.ancestorReason)
    await agent.stop()
  }

  @Test func aChildWithNoCurrentSnapshotStaysUnconfirmedAfterTheResponse() async throws {
    let (agent, session) = try await Self.resumeNested(script: .nestedUnconfirmed, waitsForTheRequest: false)
    let child = try #require(session.children.first)

    #expect(!child.isWorkStateConfirmed)
    #expect(child.workState == .unknown)
    await agent.stop()
  }
}
