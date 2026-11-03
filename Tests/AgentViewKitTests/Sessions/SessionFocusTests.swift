import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The focus rules of the view, with no window: the root shows after a
/// resume, a removed child gives way to its parent, a child that needs the
/// user does not take the focus, and a reopened root with the same id works
/// with the new tree.
@Suite @MainActor struct SessionFocusTests {
  static let child = SessionId(rawValue: "child")
  static let grandchild = SessionId(rawValue: "grandchild")

  /// A root with a child and a grandchild.
  static func openChain() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.announceChild(child, title: "Child")
    try await session.announceChild(grandchild, title: "Grandchild", in: child)
    return session
  }

  @Test func theRootShowsAtFirst() async throws {
    let session = try await Self.openChain()
    defer { session.close() }

    #expect(SessionFocus().resolve(in: session.model) === session.model)
  }

  @Test func aChosenSessionShowsAtAnyLevel() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    var focus = SessionFocus()

    focus.choose(try #require(session.session(Self.grandchild)))

    #expect(focus.resolve(in: session.model).sessionId == Self.grandchild)
  }

  @Test func theRootShowsAgainAfterAResume() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    var focus = SessionFocus()
    focus.choose(try #require(session.session(Self.grandchild)))

    focus.resumeEnded()

    #expect(focus.resolve(in: session.model) === session.model)
  }

  @Test func aChildThatNeedsTheUserDoesNotTakeTheFocus() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    let focus = SessionFocus()
    let grandchild = try #require(session.session(Self.grandchild))

    try await session.sendInOrder([.permission(id: 1, sessionId: Self.grandchild)], to: grandchild)

    #expect(grandchild.needsAttention)
    #expect(focus.resolve(in: session.model) === session.model)
  }

  @Test func aRemovedChildGivesWayToItsParentAndThenToTheRoot() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")
    try await session.sendAgentToolCall(call, child: Self.child)
    let child = try await session.announceChild(Self.child, startedBy: call)
    let grandchild = try await session.announceChild(Self.grandchild, in: Self.child)
    var focus = SessionFocus()
    focus.choose(grandchild)

    try await session.sendAgentToolCallResult(call, child: Self.child)
    await ObservationWait.until { child.isClosed }

    #expect(focus.resolve(in: session.model) === session.model)
  }

  @Test func theFocusLooksTheIdUpInTheLiveTreeAndNotInTheOldOne() async throws {
    let first = try await Self.openChain()
    var focus = SessionFocus()
    focus.choose(try #require(first.session(Self.grandchild)))
    first.close()

    let second = try await Self.openChain()
    defer { second.close() }
    let resolved = focus.resolve(in: second.model)

    #expect(resolved === second.session(Self.grandchild))
    #expect(resolved !== first.session(Self.grandchild))
  }
}
