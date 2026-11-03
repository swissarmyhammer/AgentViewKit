import AgentViewKitTestSupport
import EditorCommands
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The session commands: go to parent, open child, next and previous sibling,
/// and jump. The commands ask the view to show a session, so each test reads
/// the ids that the view would get. The chain of three sessions is only a test
/// size.
@Suite @MainActor struct SessionCommandsTests {
  static let first = SessionId(rawValue: "first")
  static let second = SessionId(rawValue: "second")
  static let grandchild = SessionId(rawValue: "grandchild")

  /// The ids that the commands asked the view to show, and the number of
  /// times that they asked it to open the jump list.
  @MainActor final class Shown {
    var ids: [SessionId] = []
    var jumpPresentations = 0
  }

  /// A tree of a root, two children and a grandchild of the first child, and
  /// a fixture with the commands acting on `shown`.
  static func open(shown id: SessionId?) async throws -> (ScriptedSession, AgentCommandsTests.Fixture, Shown) {
    let session = try await ScriptedSession.open()
    try await session.announceChild(first, title: "First")
    try await session.announceChild(second, title: "Second")
    try await session.announceChild(grandchild, title: "Grandchild", in: first)
    let record = Shown()
    let target = try #require(id.map { session.session($0) } ?? session.model)
    let fixture = AgentCommandsTests.makeFixture(session: target) {
      $0.navigation = AgentSessionNavigation(
        show: { record.ids.append($0) }, presentJump: { record.jumpPresentations += 1 })
    }
    return (session, fixture, record)
  }

  @Test func goToParentShowsTheParentAndIsOffAtTheRoot() async throws {
    let (session, fixture, record) = try await Self.open(shown: Self.grandchild)
    defer { session.close() }

    try #require(fixture.system.perform(AgentCommandVerb.goToParent.id))

    #expect(record.ids == [Self.first])
    let (rootSession, rootFixture, _) = try await Self.open(shown: nil)
    defer { rootSession.close() }
    #expect(try AgentCommandsTests.isAvailable(.goToParent, in: rootFixture) == false)
  }

  @Test func openChildShowsTheFirstChildAndIsOffWithNoChild() async throws {
    let (session, fixture, record) = try await Self.open(shown: nil)
    defer { session.close() }

    try #require(fixture.system.perform(AgentCommandVerb.openChild.id))

    #expect(record.ids == [Self.first])
    let (leafSession, leafFixture, _) = try await Self.open(shown: Self.grandchild)
    defer { leafSession.close() }
    #expect(try AgentCommandsTests.isAvailable(.openChild, in: leafFixture) == false)
  }

  @Test func openChildWithAPayloadShowsThatChild() async throws {
    let (session, fixture, record) = try await Self.open(shown: nil)
    defer { session.close() }

    try #require(fixture.system.perform(AgentCommandVerb.openChild.id, payload: AgentCommandPayload.session(Self.second)))

    #expect(record.ids == [Self.second])
  }

  @Test func nextAndPreviousSiblingMoveAndStopAtTheEnds() async throws {
    let (session, fixture, record) = try await Self.open(shown: Self.first)
    defer { session.close() }

    #expect(try AgentCommandsTests.isAvailable(.previousSibling, in: fixture) == false)
    try #require(fixture.system.perform(AgentCommandVerb.nextSibling.id))

    #expect(record.ids == [Self.second])
    let (lastSession, lastFixture, lastRecord) = try await Self.open(shown: Self.second)
    defer { lastSession.close() }
    #expect(try AgentCommandsTests.isAvailable(.nextSibling, in: lastFixture) == false)
    try #require(lastFixture.system.perform(AgentCommandVerb.previousSibling.id))
    #expect(lastRecord.ids == [Self.first])
  }

  @Test func jumpWithNoPayloadOpensTheListAndWithAPayloadShowsTheSession() async throws {
    let (session, fixture, record) = try await Self.open(shown: nil)
    defer { session.close() }

    try #require(fixture.system.perform(AgentCommandVerb.jumpToSession.id))
    try #require(
      fixture.system.perform(AgentCommandVerb.jumpToSession.id, payload: AgentCommandPayload.session(Self.grandchild)))

    #expect(record.jumpPresentations == 1)
    #expect(record.ids == [Self.grandchild])
  }

  @Test func theSessionCommandsAreOffWhenNoViewGaveTheNavigation() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    try await session.announceChild(Self.first, title: "First")
    let fixture = AgentCommandsTests.makeFixture(session: session.model)

    #expect(try AgentCommandsTests.isAvailable(.openChild, in: fixture) == false)
  }

  // MARK: - The jump list

  @Test func theJumpListHoldsTheAncestorsAndEachDescendantWithItsPath() async throws {
    let (session, _, _) = try await Self.open(shown: Self.first)
    defer { session.close() }
    let shown = try #require(session.session(Self.first))

    let paths = shown.jumpEntries.map { SessionJumpList.pathText(of: $0, agent: "Agent") }

    #expect(paths.count == 2)
    #expect(paths.last == "Agent › \(shown.ancestors.last?.title ?? "") › First › Grandchild")
  }

  @Test func theFilterKeepsTheEntriesWhoseNamesHoldEachWord() async throws {
    let (session, _, _) = try await Self.open(shown: nil)
    defer { session.close() }
    let entries = session.model.jumpEntries

    #expect(SessionJumpList.filter(entries, query: "").count == 3)
    #expect(SessionJumpList.filter(entries, query: "GRAND").map(\.title) == ["Grandchild"])
    #expect(SessionJumpList.filter(entries, query: "first grand").map(\.title) == ["Grandchild"])
    #expect(SessionJumpList.filter(entries, query: "nothing").isEmpty)
    #expect(SessionJumpList.filter(entries, query: "agent", agent: "Agent").count == 3)
  }

  // MARK: - Keys, titles and menus

  @Test func eachSessionVerbHasATitleAKeyAndAMenuPlace() {
    let verbs: [AgentCommandVerb] = [.goToParent, .openChild, .nextSibling, .previousSibling, .jumpToSession]

    for verb in verbs {
      #expect(!verb.title.isEmpty, "\(verb)")
      #expect(AgentKeymap.defaultChords[verb]?.count == 1, "\(verb)")
      #expect(verb.menu != nil, "\(verb)")
      #expect(verb.group == .navigate, "\(verb)")
    }
  }

  @Test func noTwoVerbsOfTheKitShareAChord() {
    let chords = AgentKeymap.defaultChords.values.flatMap { $0 }

    #expect(Set(chords).count == chords.count)
  }
}
