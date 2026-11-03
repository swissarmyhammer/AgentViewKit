import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

/// The fixtures of a scripted session with child sessions build the expected
/// tree through the client model. The chain of three sessions is only a test
/// size: the helpers take the stream of any parent.
@Suite @MainActor struct ScriptedChildSessionTests {
  static let child = SessionId(rawValue: "child-1")
  static let grandchild = SessionId(rawValue: "grandchild-1")

  /// A scripted session with a child and a grandchild.
  static func openChain() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.announceChild(child, title: "Reviewer")
    try await session.announceChild(grandchild, title: "Linter", in: child)
    return session
  }

  @Test func aChainOfThreeSessionsHasTheExpectedPath() async throws {
    let session = try await Self.openChain()
    defer { session.close() }

    let grandchild = try #require(session.session(Self.grandchild))

    #expect(grandchild.parent?.sessionId == Self.child)
    #expect(grandchild.pathEntry.path.suffix(2) == ["Reviewer", "Linter"])
    #expect(grandchild.ancestors.count == 2)
  }

  @Test func aChildWithALinkHasTheToolCallThatStartedIt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")

    let made = try await session.announceChild(Self.child, startedBy: call)

    #expect(made.startedByToolCallId == call)
  }

  @Test func aChildWithNoLinkHasNoToolCall() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    let made = try await session.announceChild(Self.child)

    #expect(made.startedByToolCallId == nil)
  }

  @Test func aPermissionRequestOfAGrandchildMarksItsAncestors() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    let child = try #require(session.session(Self.child))

    try await session.sendChildPermissionRequest(child: Self.grandchild, id: 1)
    await ObservationWait.until { child.needsAttention }

    #expect(session.model.needsAttention)
    #expect(try #require(session.session(Self.grandchild)).pendingRequestCount == 1)
  }

  @Test func theFinalAgentToolCallUpdateRemovesTheLinkedChild() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")
    try await session.sendAgentToolCall(call, child: Self.child)
    let made = try await session.announceChild(Self.child, startedBy: call)

    try await session.sendAgentToolCallResult(call, child: Self.child)
    await ObservationWait.until { made.isClosed }

    #expect(made.isClosed)
  }

  @Test func aChildWithNoLinkStaysAfterAToolCallEnds() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")
    let made = try await session.announceChild(Self.child)

    try await session.sendAgentToolCallResult(call, child: nil)
    try await session.sendChildMessage("Done.", messageID: "m1", child: Self.child)
    await ObservationWait.until { !made.transcript.isEmpty }

    #expect(!made.isClosed)
  }
}
