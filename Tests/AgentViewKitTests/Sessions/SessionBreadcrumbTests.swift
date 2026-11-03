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

  @Test func theHeaderLabelReadsThePathOneNameAfterTheOther() {
    #expect(AgentInfoHeader.label(agent: "Agent", path: []) == "Path: Agent")
    #expect(
      AgentInfoHeader.label(agent: "Agent", path: ["Reviewer", "Linter"])
        == "Path: Agent, then Reviewer, then Linter")
  }

  // MARK: - Dropdowns

  @Test func theDropdownOfAChildListsItsSiblingsWithTheirState() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let child = try #require(session.session(Self.reviewer))

    let labels = child.siblings.map { SessionStateText.choiceLabel(for: $0) }

    #expect(labels == ["Reviewer, In progress", "Second, In progress"])
  }

  @Test func aSiblingWithAnOpenQuestionShowsTheCount() async throws {
    let session = try await Self.openTree()
    defer { session.close() }
    let other = try #require(session.session(Self.second))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.second)], to: other)

    let labels = try #require(session.session(Self.reviewer)).siblings.map { SessionStateText.choiceLabel(for: $0) }

    #expect(labels.last == "Second, In progress, 1 open question, needs your attention")
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
    let message = UnconfirmedSessionBanner.message(for: .failedToRestore(reason: "The log is gone."))

    #expect(message?.explanation == "The log is gone.")
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

/// The status texts, the controls and the menus of the tree.
@Suite @MainActor struct SessionStatusTests {
  @Test func aRootSessionHasAKnownStatus() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    #expect(SessionStatus.of(session.model).isUnknown == false)
    #expect(SessionControls.composerEnabled(for: session.model))
  }

  @Test func aConfirmedChildHasAKnownStateAndNoComposer() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(SessionId(rawValue: "c"))

    #expect(SessionStatus.of(child) == .known(.running))
    #expect(!SessionControls.composerEnabled(for: child))
  }

  @Test func theFourStatusesReadDifferently() {
    let texts = [
      SessionStatus.unconfirmed.text, SessionStatus.failedToRestore(reason: "gone").text,
      SessionStatus.stateOmitted.text, SessionStatus.known(.idle(stopReason: nil, error: nil)).text,
    ]

    #expect(Set(texts).count == 4)
    #expect(texts[1].contains("gone"))
  }

  @Test func theBannerSaysEachStatusInItsOwnWords() {
    let unconfirmed = UnconfirmedSessionBanner.message(for: .unconfirmed)
    let omitted = UnconfirmedSessionBanner.message(for: .stateOmitted)

    #expect(unconfirmed?.title != omitted?.title)
    #expect(UnconfirmedSessionBanner.message(for: .known(.running)) == nil)
  }

  @Test func theChildrenMenuListsTheFirstOnesAndCountsTheRest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    for index in 0..<5 { try await session.announceChild(SessionId(rawValue: "c\(index)")) }
    let entries = session.model.children.map(\.pathEntry)

    let split = ChildrenMenu.split(entries, limit: 3)

    #expect(split.listed.count == 3)
    #expect(split.more == 2)
    #expect(ChildrenMenu.split(entries).more == 0)
  }

  @Test func aMarkShowsTheShownSessionAndTheSessionsThatNeedTheUser() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(SessionId(rawValue: "c"))
    try await session.sendInOrder([.permission(id: 1, sessionId: child.sessionId)], to: child)

    #expect(SessionBreadcrumb.mark(of: child.pathEntry, isCurrent: true) == "checkmark")
    #expect(SessionBreadcrumb.mark(of: child.pathEntry, isCurrent: false) == SharedSymbol.warning)
  }

  @Test func theBannerFindsAWaitingSiblingAndAWaitingAncestor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let first = try await session.announceChild(SessionId(rawValue: "first"))
    let second = try await session.announceChild(SessionId(rawValue: "second"))
    try await session.sendInOrder([.permission(id: 1, sessionId: second.sessionId)], to: second)

    #expect(first.waitingElsewhere?.sessionId == second.sessionId)
    #expect(second.waitingElsewhere == nil)
  }

  @Test func theBannerFindsAWaitingAncestor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let child = try await session.announceChild(SessionId(rawValue: "child"))
    try await session.sendInOrder([.permission(id: 1)], to: session.model)

    #expect(child.waitingElsewhere?.sessionId == session.model.sessionId)
  }

  @Test func anAgentsCallThatEndedShowsTheFinishedLabel() {
    #expect(ToolCallChildLink.isFinishedAgentCall(name: "agents", status: .completed))
    #expect(!ToolCallChildLink.isFinishedAgentCall(name: "agents", status: .inProgress))
    #expect(!ToolCallChildLink.isFinishedAgentCall(name: "shell", status: .completed))
  }
}
