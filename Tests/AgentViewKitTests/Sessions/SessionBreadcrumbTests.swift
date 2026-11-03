import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The path, the dropdowns, the marks, the fallback and the jump of the
/// breadcrumb, over the scripted session with children. The chain of three
/// sessions is only a test size: no check here knows a number of levels.
@Suite @MainActor struct SessionBreadcrumbTests {
  static let reviewer = SessionId(rawValue: "reviewer")
  static let second = SessionId(rawValue: "second")
  static let linter = SessionId(rawValue: "linter")

  /// A root, a child with a title, a second child, and a grandchild.
  static func openTree() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.announceChild(reviewer, title: "Reviewer")
    try await session.announceChild(second, title: "Second")
    try await session.announceChild(linter, title: "Linter", in: reviewer)
    return session
  }

  // MARK: - Path and collapse

  @Test func thePathOfTheGrandchildHasTheRootTheChildAndTheGrandchild() async throws {
    let session = try await Self.openTree()
    defer { session.close() }

    let path = try #require(session.session(Self.linter)).pathModels

    #expect(path.map(\.sessionId) == [session.model.sessionId, Self.reviewer, Self.linter])
  }

  @Test func theFullPathHasOneCrumbForEachSession() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let path = try #require(session.session(Self.linter)).pathModels

    let segments = BreadcrumbSegment.segments(of: path, collapsed: false)

    #expect(segments.count == 3)
  }

  @Test func theCollapsedPathHoldsTheMiddleCrumbsInOneDropdown() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let path = try #require(session.session(Self.linter)).pathModels

    let segments = BreadcrumbSegment.segments(of: path, collapsed: true)

    guard segments.count == 3, case .crumb(let first) = segments[0], case .overflow(let middle) = segments[1],
      case .crumb(let last) = segments[2]
    else {
      Issue.record("The collapsed path is a crumb, a dropdown and a crumb.")
      return
    }
    #expect(first.sessionId == session.model.sessionId)
    #expect(middle.map(\.sessionId) == [Self.reviewer])
    #expect(last.sessionId == Self.linter)
  }

  @Test func aPathWithNoMiddleCrumbHasNothingToCollapse() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let path = try #require(session.session(Self.reviewer)).pathModels

    #expect(BreadcrumbSegment.segments(of: path, collapsed: true).count == 2)
  }

  @Test func theHeaderLabelNamesTheAgentAndThePath() {
    #expect(AgentInfoHeader.label(agent: "Agent", path: []) == "Agent")
    #expect(AgentInfoHeader.label(agent: "Agent", path: ["Reviewer", "Linter"]).contains("Reviewer"))
    #expect(AgentInfoHeader.label(agent: "Agent", path: ["Reviewer", "Linter"]).hasSuffix("Linter"))
  }

  // MARK: - Dropdowns

  @Test func theDropdownOfAChildListsItsSiblingsWithTheirState() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let child = try #require(session.session(Self.reviewer))

    let labels = child.siblings.map(SessionStateText.choiceLabel(for:))

    #expect(labels == ["Reviewer, In progress", "Second, In progress"])
  }

  @Test func aSiblingWithAnOpenQuestionShowsTheCount() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let other = try #require(session.session(Self.second))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.second)], to: other)

    let labels = try #require(session.session(Self.reviewer)).siblings.map(SessionStateText.choiceLabel(for:))

    #expect(labels.last == "Second, In progress, 1 open question")
  }

  // MARK: - Marks

  @Test func aQuestionOfTheGrandchildMarksTheCrumbsAboveItAndAnswerClearsThem() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let grandchild = try #require(session.session(Self.linter))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.linter)], to: grandchild)

    #expect(SessionBreadcrumb.accessibilityLabel(for: try #require(session.session(Self.reviewer))).hasSuffix("needs your attention"))
    #expect(session.model.needsAttention)

    let pending = try #require(grandchild.pendingPermissions.first)
    let option = try #require(pending.request.options.first)
    await grandchild.selectPermission(pending.id, option: option.optionId)
    await ObservationWait.until { !session.model.needsAttention }

    #expect(!SessionBreadcrumb.accessibilityLabel(for: try #require(session.session(Self.reviewer))).contains("needs your attention"))
  }

  // MARK: - Fallback

  @Test func aShownChildThatTheClientRemovedFallsBackToItsParent() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")
    try await session.sendAgentToolCall(call, child: Self.reviewer)
    let child = try await session.announceChild(Self.reviewer, startedBy: call)
    #expect(child.nearestOpenSession === child)

    try await session.sendAgentToolCallResult(call, child: Self.reviewer)
    await ObservationWait.until { child.isClosed }

    #expect(child.nearestOpenSession === session.model)
  }

  // MARK: - Banner jump

  @Test func theBannerNamesTheDescendantThatWaitsAndNotItsAncestor() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let grandchild = try #require(session.session(Self.linter))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.linter)], to: grandchild)

    let entry = try #require(session.model.waitingDescendant)

    #expect(entry.sessionId == Self.linter)
    #expect(WaitingDescendantBanner.message(for: entry).explanation.contains("Linter"))
  }

  @Test func aTreeWithNoQuestionHasNoWaitingDescendant() async throws {
    let session = try await Self.openTree()
    defer { session.close() }

    #expect(session.model.waitingDescendant == nil)
  }

  @Test func aChildThatFailedToRestoreShowsItsReason() {
    let message = UnconfirmedSessionBanner.message(failure: "The log is gone.")

    #expect(message.explanation == "The log is gone.")
  }

  // MARK: - Tool row link

  @Test func theAgentsToolCallHoldsTheChildSession() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let call = ToolCallId(rawValue: "call-1")
    try await session.sendAgentToolCall(call, child: Self.reviewer)
    let child = try await session.announceChild(Self.reviewer, startedBy: call)

    let entry = session.model.transcript.compactMap { entry -> ToolCallEntry? in
      if case .toolCall(let call) = entry { call } else { nil }
    }.first

    #expect(entry?.childSession === child)
  }
}
