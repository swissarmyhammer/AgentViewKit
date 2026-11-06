import AgentViewKitTestSupport
import EditorSwiftUI
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// What VoiceOver reads for the path of a chain of three sessions, with no
/// window: the label of the header, the title of each crumb, and the notes of
/// the marks. The chain of three sessions is only a test size.
@Suite @MainActor struct SessionPathAccessibilityTests {
  static let child = SessionId(rawValue: "child")
  static let grandchild = SessionId(rawValue: "grandchild")

  static func openChain() async throws -> ScriptedSession {
    let session = try await ScriptedSession.open()
    try await session.announceChild(child, title: "Reviewer")
    try await session.announceChild(grandchild, title: "Linter", in: child)
    return session
  }

  @Test func theHeaderLabelReadsTheWholePath() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    let titles = try #require(session.session(Self.grandchild)).path.map(\.displayTitle)

    let label = AgentInfoHeader.label(agent: "Agent", path: titles)

    #expect(label == "Path: Agent, then \(titles[0]), then Reviewer, then Linter")
  }

  @Test func aCrumbWhoseSessionNeedsNothingHasNoMark() async throws {
    let session = try await Self.openChain()
    defer { session.close() }

    #expect(SessionBreadcrumb.attentionMark(of: try #require(session.session(Self.grandchild))) == nil)
  }

  @Test func aCrumbThatNeedsTheUserSaysSoInItsMarkLabelAndNotOnlyInItsIcon() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    let grandchild = try #require(session.session(Self.grandchild))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.grandchild)], to: grandchild)

    let mark = SessionBreadcrumb.attentionMark(of: try #require(session.session(Self.child)))

    #expect(mark == .symbol(.severity(.warning), label: "needs your attention"))
  }

  @Test func eachSessionCommandHasATitleForTheMenusAndThePalette() {
    let titles = [AgentCommandVerb.goToParent, .openChild, .nextSibling, .previousSibling, .jumpToSession].map(\.title)

    #expect(titles.allSatisfy { !$0.isEmpty })
    #expect(Set(titles).count == 5)
  }

  @Test func theBannerButtonAndTheCrumbsHaveIdentifiers() async throws {
    #expect(WaitingDescendantBanner.jumpIdentifier == "session-waiting-descendant-jump")
    #expect(SessionBreadcrumb.crumbIdentifier(for: Self.child) == "breadcrumb-child")
  }
}

/// The titles and the menus for a long path and for many children, with no
/// window.
@Suite @MainActor struct LargeSessionTreeAccessibilityTests {
  /// A chain of five sessions below the root.
  static func openChainOfFive() async throws -> (ScriptedSession, [SessionId]) {
    let session = try await ScriptedSession.open()
    var ids: [SessionId] = []
    var parent = session.model.sessionId
    for index in 1...5 {
      let id = SessionId(rawValue: "level-\(index)")
      try await session.announceChild(id, title: "Level \(index)", in: parent)
      ids.append(id)
      parent = id
    }
    return (session, ids)
  }

  @Test func theLabelOfAPathOfFiveCrumbsReadsEachNameInOrder() async throws {
    let (session, ids) = try await Self.openChainOfFive()
    defer { session.close() }
    let last = try #require(session.session(ids[4]))
    let titles = last.path.map(\.displayTitle)

    let label = AgentInfoHeader.label(agent: "Agent", path: titles)

    #expect(titles.count == 6)
    #expect(label.hasPrefix("Path: Agent, then "))
    #expect(label.hasSuffix(", then Level 1, then Level 2, then Level 3, then Level 4, then Level 5"))
  }

  @Test func eachCrumbOfALongPathHasItsOwnTitle() async throws {
    let (session, ids) = try await Self.openChainOfFive()
    defer { session.close() }
    let path = try #require(session.session(ids[4])).path

    let titles = AgentInfoHeader.titles(of: path, sessionTitle: nil).dropFirst()

    #expect(Array(titles) == ["Level 1", "Level 2", "Level 3", "Level 4", "Level 5"])
  }

  @Test func aMenuOfFortyChildrenListsTheFirstOnesAndNamesTheRest() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    for index in 1...40 {
      try await session.announceChild(SessionId(rawValue: "child-\(index)"), title: "Child \(index)")
    }
    let entries = session.model.children.map(\.pathEntry)

    let split = ChildrenMenu.split(entries)
    let labels = split.listed.map { SessionStateText.choiceLabel(for: $0) }

    #expect(entries.count == 40)
    #expect(split.listed.count == ChildrenMenu.limit)
    #expect(split.more == 40 - ChildrenMenu.limit)
    #expect(labels.first == "Child 1, In progress")
    #expect(Set(labels).count == ChildrenMenu.limit)
  }

  @Test func theJumpListFindsAChildThatTheMenuDoesNotList() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    for index in 1...40 { try await session.announceChild(SessionId(rawValue: "c\(index)"), title: "Child \(index)") }

    let found = SessionJumpList.filter(session.model.jumpEntries, query: "child 40")

    #expect(found.map(\.title) == ["Child 40"])
  }
}
