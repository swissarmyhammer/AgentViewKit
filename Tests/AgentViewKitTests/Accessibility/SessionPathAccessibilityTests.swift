import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// What VoiceOver reads for the path of a chain of three sessions, with no
/// window: the label of the header, the label of each crumb, and the notes of
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
    let titles = try #require(session.session(Self.grandchild)).pathModels.map(\.displayTitle)

    let label = AgentInfoHeader.label(agent: "Agent", path: titles)

    #expect(label == "Path: Agent, then \(titles[0]), then Reviewer, then Linter")
  }

  @Test func eachCrumbReadsItsTitleAndItsState() async throws {
    let session = try await Self.openChain()
    defer { session.close() }

    let label = SessionBreadcrumb.accessibilityLabel(for: try #require(session.session(Self.grandchild)))

    #expect(label == "Linter, In progress")
  }

  @Test func aCrumbThatNeedsTheUserSaysSoInItsLabelAndNotOnlyInItsIcon() async throws {
    let session = try await Self.openChain()
    defer { session.close() }
    let grandchild = try #require(session.session(Self.grandchild))
    try await session.sendInOrder([.permission(id: 1, sessionId: Self.grandchild)], to: grandchild)

    let label = SessionBreadcrumb.accessibilityLabel(for: try #require(session.session(Self.child)))

    #expect(label.hasSuffix("needs your attention"))
  }

  @Test func eachSessionCommandHasATitleForTheMenusAndThePalette() {
    let titles = [AgentCommandVerb.goToParent, .openChild, .nextSibling, .previousSibling, .jumpToSession].map(\.title)

    #expect(titles.allSatisfy { !$0.isEmpty })
    #expect(Set(titles).count == 5)
  }

  @Test func theBannerButtonAndTheCrumbsHaveIdentifiers() async throws {
    #expect(WaitingDescendantBanner.jumpIdentifier == "session-waiting-descendant-jump")
    #expect(SessionBreadcrumb.crumbIdentifier(for: Self.child) == "session-crumb-child")
    #expect(SessionBreadcrumb.overflowIdentifier == "session-crumb-overflow")
  }
}
