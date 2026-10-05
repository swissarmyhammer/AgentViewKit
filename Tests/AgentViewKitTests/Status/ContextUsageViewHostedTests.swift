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

  /// A usage with half of the window in use and no cost.
  static let halfUsage = ContextUsage(used: 500, size: 1000)

  /// A usage with three quarters of the window in use and no cost.
  static let threeQuarterUsage = ContextUsage(used: 750, size: 1000)

  /// A usage with a cost.
  static let costUsage = ContextUsage(
    used: 1200, size: 4000, cost: ContextUsage.Cost(amount: 1.25, currency: "USD"))

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
  }

  @Test func aUsageWithACostShowsTheCost() throws {
    let cost = try #require(Self.costUsage.cost)
    let harness = HostedViewHarness(ContextUsageView(usage: Self.costUsage))
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ContextUsageView.percentIdentifier)?.value
      == ContextUsageView.percentText(for: Self.costUsage))
    #expect(harness.element(identifier: ContextUsageView.costIdentifier)?.label
      == ContextUsageView.costText(for: cost))
  }

  @Test func theTextsUseTheLocale() throws {
    let cost = try #require(Self.costUsage.cost)
    #expect(ContextUsageView.percentText(for: Self.costUsage, locale: Self.locale) == "30%")
    #expect(ContextUsageView.costText(for: cost, locale: Self.locale) == "$1.25")
    #expect(
      ContextUsageView.detailText(for: Self.costUsage, locale: Self.locale) == "1,200 of 4,000 tokens")
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
