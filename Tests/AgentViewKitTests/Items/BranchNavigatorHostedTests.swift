@testable import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

/// Tests for the regenerate and branch paging control in a window: presence,
/// position label, paging, and regenerate through ``NoopThreadActions``.
@Suite(.serialized, .hostedSerially) @MainActor struct BranchNavigatorHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The text of the first user message.
  static let question = "Read the README."

  /// The first user message of ``twoTurnThread()``.
  static let firstUser = "u1"

  /// The first assistant message of ``twoTurnThread()``.
  static let firstAnswer = "a1"

  /// The last assistant message of ``twoTurnThread()``.
  static let lastAnswer = "a2"

  /// The identifiers of the pager parts.
  static let pagerIdentifiers = [
    BranchNavigator.Control.previous, .position, .next,
  ].map(\.identifier)

  /// Makes a thread with two turns: `u1`, `a1`, `u2`, `a2`.
  ///
  /// - Returns: The thread.
  static func twoTurnThread() -> AgentThread {
    let thread = AgentThread()
    let items: [ThreadItem] = [
      .userMessage(ThreadFixtures.message(id: firstUser, text: question)),
      .assistantMessage(ThreadFixtures.message(id: firstAnswer, text: "One.")),
      .userMessage(ThreadFixtures.message(id: "u2", text: "Next.")),
      .assistantMessage(ThreadFixtures.message(id: lastAnswer, text: "Two.")),
    ]
    for item in items {
      thread.apply(.insert(item, after: nil))
    }
    return thread
  }

  /// The identifiers of the control parts that the harness shows, in order.
  ///
  /// - Parameter harness: The harness.
  /// - Returns: The identifiers.
  static func shownControls<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
    let identifiers = Set(BranchNavigator.Control.allCases.map(\.identifier))
    return harness.accessibilityElements().compactMap(\.identifier).filter(identifiers.contains)
  }

  /// Makes a harness that shows the control of the message in the thread.
  ///
  /// - Parameters:
  ///   - messageID: The identifier of the assistant message.
  ///   - thread: The thread.
  ///   - actions: The thread actions.
  /// - Returns: The harness, pumped one time.
  static func harness(
    for messageID: String, in thread: AgentThread?,
    actions: NoopThreadActions = NoopThreadActions()
  ) -> HostedViewHarness<some View> {
    let harness = threadViewHarness(actions: actions, thread: thread) {
      BranchNavigator(messageID: messageID)
    }
    harness.pump()
    return harness
  }

  // MARK: - Presence

  @Test func withNoBranchSetAnEarlierMessageShowsNothing() {
    let harness = Self.harness(for: Self.firstAnswer, in: Self.twoTurnThread())
    defer { harness.close() }

    #expect(Self.shownControls(in: harness).isEmpty)
  }

  @Test func withNoBranchSetTheLastMessageShowsOnlyRegenerate() {
    let harness = Self.harness(for: Self.lastAnswer, in: Self.twoTurnThread())
    defer { harness.close() }

    #expect(Self.shownControls(in: harness) == [BranchNavigator.Control.regenerate.identifier])
    #expect(
      harness.element(identifier: BranchNavigator.Control.regenerate.identifier)?.label
        == "Regenerate")
  }

  @Test func withNoThreadTheControlShowsNothing() {
    let harness = Self.harness(for: Self.lastAnswer, in: nil)
    defer { harness.close() }

    #expect(Self.shownControls(in: harness).isEmpty)
  }

  // MARK: - Pager

  @Test func withOneAlternativeThePagerShowsOneOfTwo() throws {
    let thread = Self.twoTurnThread()
    thread.apply(.addBranch(afterUserMessage: Self.firstUser, items: []))
    let harness = Self.harness(for: Self.firstAnswer, in: thread)
    defer { harness.close() }

    #expect(Self.shownControls(in: harness) == Self.pagerIdentifiers)
    let set = try #require(thread.branches[Self.firstUser])
    #expect(BranchNavigator.positionText(of: set) == "1 / 2")
    #expect(
      harness.element(identifier: BranchNavigator.Control.position.identifier)?.label
        == "Branch 1 of 2")
    let previous = harness.element(identifier: BranchNavigator.Control.previous.identifier)
    let next = harness.element(identifier: BranchNavigator.Control.next.identifier)
    #expect(previous?.isEnabled == false)
    #expect(next?.isEnabled == true)
  }

  @Test func nextShowsTheNextBranch() throws {
    let thread = Self.twoTurnThread()
    let other = ThreadFixtures.message(id: "b1", text: "Other.")
    thread.apply(.addBranch(afterUserMessage: Self.firstUser, items: [.assistantMessage(other)]))
    let harness = Self.harness(for: Self.firstAnswer, in: thread)
    defer { harness.close() }

    try harness.press(identifier: BranchNavigator.Control.next.identifier)
    harness.pump()

    #expect(thread.items.map(\.id) == [Self.firstUser, "b1"])
    #expect(thread.branches[Self.firstUser]?.selectedIndex == 1)
  }

  @Test func previousShowsThePreviousBranch() throws {
    let thread = Self.twoTurnThread()
    let other = ThreadFixtures.message(id: "b1", text: "Other.")
    thread.apply(.addBranch(afterUserMessage: Self.firstUser, items: [.assistantMessage(other)]))
    thread.apply(.selectBranch(afterUserMessage: Self.firstUser, index: 1))
    let harness = Self.harness(for: "b1", in: thread)
    defer { harness.close() }

    #expect(
      harness.element(identifier: BranchNavigator.Control.position.identifier)?.label
        == "Branch 2 of 2")
    try harness.press(identifier: BranchNavigator.Control.previous.identifier)
    harness.pump()

    #expect(thread.items.map(\.id) == [Self.firstUser, Self.firstAnswer, "u2", Self.lastAnswer])
  }

  // MARK: - Regenerate

  @Test func regenerateSendsThePriorUserInputAndRecordsABranch() async throws {
    let thread = AgentThread()
    let request = ThreadFixtures.message(id: Self.firstUser, text: Self.question)
    let answer = ThreadFixtures.message(id: Self.firstAnswer)
    thread.apply(.insert(.userMessage(request), after: nil))
    thread.apply(.insert(.assistantMessage(answer), after: nil))
    let actions = NoopThreadActions()
    let harness = Self.harness(for: Self.firstAnswer, in: thread, actions: actions)
    defer { harness.close() }

    try harness.press(identifier: BranchNavigator.Control.regenerate.identifier)
    await harness.pump(until: Self.waitTimeout) { !actions.calls.isEmpty }

    #expect(actions.calls == [.send(UserInput(text: Self.question))])
    #expect(thread.items.map(\.id) == [Self.firstUser])
    let set = try #require(thread.branches[Self.firstUser])
    #expect(set.alternatives.map { $0.map(\.id) } == [[Self.firstAnswer], []])
    #expect(set.selectedIndex == 1)
  }

  @Test func whileTheThreadRunsTheButtonsAreDisabled() {
    let thread = Self.twoTurnThread()
    thread.apply(.setState(.running))
    let harness = Self.harness(for: Self.lastAnswer, in: thread)
    defer { harness.close() }

    #expect(
      harness.element(identifier: BranchNavigator.Control.regenerate.identifier)?.isEnabled
        == false)
  }

  @Test func startBranchWithNoUserMessageChangesNothing() {
    let thread = AgentThread()
    let answer = ThreadFixtures.message(id: Self.firstAnswer)
    thread.apply(.insert(.assistantMessage(answer), after: nil))

    #expect(BranchNavigator.startBranch(after: Self.firstAnswer, in: thread) == nil)
    #expect(thread.branches.isEmpty)
    #expect(thread.items.map(\.id) == [Self.firstAnswer])
  }
}
