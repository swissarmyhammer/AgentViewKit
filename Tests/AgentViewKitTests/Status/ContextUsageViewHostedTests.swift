import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct ContextUsageViewHostedTests {
  /// The locale of the text checks, so that the numbers do not change with
  /// the locale of the test machine.
  static let locale = Locale(identifier: "en_US")

  /// The longest time that a test waits for the view to update, in seconds.
  static let updateWaitSeconds: TimeInterval = 1

  /// A usage with half of the window in use and no other parts.
  static let halfUsage = ContextUsage(used: 500, size: 1000)

  /// A usage with three quarters of the window in use and no other parts.
  static let threeQuarterUsage = ContextUsage(used: 750, size: 1000)

  /// A usage with each part.
  static let fullUsage = ContextUsage(
    used: 1200, size: 4000,
    cost: ContextUsage.Cost(amount: 1.25, currency: "USD"),
    input: ContextUsage.Input(total: 900, cached: 300),
    output: ContextUsage.Output(total: 300, reasoning: 100),
    quota: .belowLimit(approaching: true))

  /// A view that shows the usage of a thread, so that a change to the thread
  /// updates the view.
  struct ThreadUsage: View {
    /// The thread to show.
    let thread: AgentThread

    var body: some View {
      ContextUsageView(usage: thread.usage)
    }
  }

  @Test func halfAWindowShowsFiftyPercentAndNoCost() {
    #expect(ContextUsageView.percentText(for: Self.halfUsage, locale: Self.locale) == "50%")

    let harness = HostedViewHarness(ContextUsageView(usage: Self.halfUsage))
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: ContextUsageView.percentIdentifier)
    #expect(element?.value == ContextUsageView.percentText(for: Self.halfUsage))
    #expect(harness.element(identifier: ContextUsageView.costIdentifier) == nil)
    #expect(harness.element(identifier: ContextUsageView.quotaIdentifier) == nil)
  }

  @Test func aUsageWithEachPartShowsTheCostAndTheQuota() throws {
    let cost = try #require(Self.fullUsage.cost)
    let harness = HostedViewHarness(ContextUsageView(usage: Self.fullUsage))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ContextUsageView.percentIdentifier)?.value
      == ContextUsageView.percentText(for: Self.fullUsage))
    #expect(harness.element(identifier: ContextUsageView.costIdentifier)?.label
      == ContextUsageView.costText(for: cost))
    #expect(harness.element(identifier: ContextUsageView.quotaIdentifier)?.label
      == ContextUsageView.quotaText(for: .belowLimit(approaching: true)))
  }

  @Test func theTextsUseTheLocale() throws {
    let cost = try #require(Self.fullUsage.cost)
    #expect(ContextUsageView.percentText(for: Self.fullUsage, locale: Self.locale) == "30%")
    #expect(ContextUsageView.costText(for: cost, locale: Self.locale) == "$1.25")
    #expect(
      ContextUsageView.detailLines(for: Self.fullUsage, locale: Self.locale) == [
        "1,200 of 4,000 tokens",
        "Input: 900 tokens, 300 cached",
        "Output: 300 tokens, 100 reasoning",
      ])
  }

  @Test func theDetailsOmitTheCountsThatTheSourceDoesNotGive() {
    #expect(
      ContextUsageView.detailLines(for: Self.halfUsage, locale: Self.locale) == [
        "500 of 1,000 tokens"
      ])
  }

  @Test func eachQuotaStateHasADistinctText() {
    let states: [ContextUsage.Quota] = [
      .belowLimit(approaching: false), .belowLimit(approaching: true), .limitReached,
    ]
    #expect(Set(states.map(ContextUsageView.quotaText)).count == states.count)
  }

  @Test func aNilUsageShowsNothing() {
    let harness = HostedViewHarness(ContextUsageView(usage: nil))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ContextUsageView.percentIdentifier) == nil)
  }

  @Test func aUsageChangeOnTheThreadUpdatesTheView() async {
    let thread = AgentThread()
    thread.apply(.setUsage(Self.halfUsage))
    let harness = HostedViewHarness(ThreadUsage(thread: thread))
    defer { harness.close() }
    harness.pump()

    let next = Self.threeQuarterUsage
    thread.apply(.setUsage(next))
    let expected = ContextUsageView.percentText(for: next)
    await harness.pump(until: Self.updateWaitSeconds) {
      harness.element(identifier: ContextUsageView.percentIdentifier)?.value == expected
    }

    #expect(harness.element(identifier: ContextUsageView.percentIdentifier)?.value == expected)
  }
}
