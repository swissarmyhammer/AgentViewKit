import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct StateBannerHostedTests {
  /// The longest time that a test waits for a host closure, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// Each state, with `true` when the bar shows for it.
  nonisolated static let cases: [(ThreadState, Bool)] = [
    (.running, false),
    (.idle(nil), false),
    (.idle(.endTurn), false),
    (.idle(.cancelled), false),
    (.idle(.unknown("paused")), false),
    (.requiresAction, true),
    (.idle(.maxTokens), true),
    (.idle(.maxTurnRequests), true),
    (.idle(.refusal), true),
  ]

  @Test(arguments: cases)
  func theBarShowsOnlyForAStateThatNeedsAttention(state: ThreadState, shows: Bool) {
    let harness = HostedViewHarness(StateBanner(state: state))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: StateBanner.bannerIdentifier)
    #expect((element != nil) == shows, "The bar has the wrong presence for \(state).")
    #expect((StateBanner.message(for: state) != nil) == shows)
    if shows {
      #expect(element?.label == StateBanner.message(for: state)?.title)
    }
  }

  @Test func theRequiresActionBarAsksForInput() {
    #expect(StateBanner.message(for: .requiresAction)?.title == "The agent needs your input")
  }

  @Test func eachShownStateHasADistinctTitle() {
    let titles = Self.cases.compactMap { StateBanner.message(for: $0.0)?.title }
    #expect(Set(titles).count == Self.cases.count { $0.1 })
  }

  @Test func theShowErrorButtonGivesTheErrorIdentifierToTheHost() async throws {
    var shown: [String] = []
    let harness = HostedViewHarness(
      StateBanner(state: .idle(.refusal), errorID: "error-1", onShowError: { shown.append($0) }))
    defer { harness.close() }
    harness.pump()

    try harness.press(identifier: StateBanner.showErrorIdentifier)
    await harness.pump(until: Self.callWaitSeconds) { !shown.isEmpty }

    #expect(shown == ["error-1"])
  }

  @Test func aBarWithNoErrorShowsNoButton() {
    let harness = HostedViewHarness(
      StateBanner(state: .requiresAction, onShowError: { _ in }))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: StateBanner.bannerIdentifier) != nil)
    #expect(harness.element(identifier: StateBanner.showErrorIdentifier) == nil)
  }
}
