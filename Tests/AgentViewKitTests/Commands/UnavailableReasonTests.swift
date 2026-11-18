import AgentViewKitTestSupport
import EditorCommands
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests that the reason of an unavailable agent command agrees with the
/// condition that stops it.
///
/// A verb that needs a part of the view, such as the thread list or the
/// composer, tells that the part is not shown when the part is missing. It
/// tells the reason of its own rule only when the part is there.
///
/// A test that waits for the agent waits with `ObservationWait.until` on a
/// value of the session model that the frame is certain to change, with no
/// clock.
@MainActor struct UnavailableReasonTests {
  /// The reason when the thread list is not shown.
  static let listNotShown = "The thread list is not shown."

  /// The reason when the composer is not shown.
  static let composerNotShown = "The composer is not shown."

  /// The id of the child session of the closed-session test.
  static let child = SessionId(rawValue: "reason-child")

  /// The tool call that starts the child session.
  static let childCall = ToolCallId(rawValue: "reason-call")

  /// The reason of `verb` in `fixture`, or `nil` when the verb is available.
  ///
  /// - Parameters:
  ///   - verb: The verb.
  ///   - fixture: The fixture.
  /// - Returns: The reason.
  static func reason(of verb: AgentCommandVerb, in fixture: AgentCommandsTests.Fixture) -> String? {
    let availability = AgentCommand(verb: verb, target: fixture.target, payload: nil)
      .availability(in: fixture.system.context())
    guard case .unavailable(let reason) = availability else { return nil }
    return reason
  }

  /// A composer hook that does nothing.
  ///
  /// - Parameter target: The target that owns the hook.
  /// - Returns: The hook.
  static func idleComposer(of target: AgentCommandTarget) -> AgentComposerHook {
    AgentComposerHook(
      owner: ObjectIdentifier(target), canSubmit: { false }, submit: {}, load: { _ in },
      focus: { false })
  }

  @Test func jumpWithNoListTellsThatTheListIsNotShown() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(Self.reason(of: .jumpToNext, in: fixture) == Self.listNotShown)
  }

  @Test func expandAllWithNoStoreTellsThatTheListIsNotShown() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(Self.reason(of: .toggleExpandAll, in: fixture) == Self.listNotShown)
  }

  @Test func scrollToBottomInAnEmptyListTellsThatTheThreadHasNoItems() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model) {
      $0.anchors = ScrollAnchorManager()
    }

    #expect(Self.reason(of: .scrollToBottom, in: fixture) == "The thread has no items.")
  }

  @Test func mentionInAClosedSessionTellsThatTheSessionIsClosed() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.sendAgentToolCall(Self.childCall, child: Self.child)
    let child = try await session.announceChild(Self.child, startedBy: Self.childCall)
    try await session.sendAgentToolCallResult(Self.childCall, child: Self.child)
    await ObservationWait.until { child.isClosed }
    let fixture = AgentCommandsTests.makeFixture(session: child) {
      $0.composer = Self.idleComposer(of: $0)
    }

    #expect(Self.reason(of: .insertMention, in: fixture) == "The session is closed.")
  }

  @Test func sendWithNoComposerTellsThatTheComposerIsNotShown() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(Self.reason(of: .send, in: fixture) == Self.composerNotShown)
  }

  @Test func aSessionVerbWithNoNavigationTellsThatTheViewCannotShowSessions() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(
      Self.reason(of: .goToParent, in: fixture) == "The thread view cannot show other sessions.")
  }
}
