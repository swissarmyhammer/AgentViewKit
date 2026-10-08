import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The context usage view over a `SessionModel` (plan.md §3.2 "Last-value
/// state"; `Docs/decisions/acp-client-kit.md`, section "ACP values in the
/// views").
///
/// Each test shows a ``ContextUsageView`` over the model of a
/// ``ScriptedSession``. The scripted agent sends `usage_update` values, and
/// the test reads the text that the view shows.
@Suite(.serialized, .hostedSerially) @MainActor struct ContextUsageSessionModelHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The size of the hosted view.
  static let size = CGSize(width: 320, height: 80)

  /// The caption of the token counts.
  static let tokensCaption = "tokens"

  /// The first usage: 1,200 of 4,000 tokens, with no cost.
  static let firstUsage = #"{"sessionUpdate":"usage_update","used":1200,"size":4000}"#

  /// The second usage: 3,000 of 4,000 tokens, with a cost of 1.25 USD.
  static let secondUsage =
    #"{"sessionUpdate":"usage_update","used":3000,"size":4000,"cost":{"amount":1.25,"currency":"USD"}}"#

  /// The `messageId` of the agent message that marks the end of the frames
  /// that a test sent.
  static let markerMessageID = "usage-marker"

  /// An `agent_message_chunk` value. The agent sends it after the frames of
  /// a test, so that the test knows that the client read those frames.
  static let markerUpdate =
    #"{"sessionUpdate":"agent_message_chunk","messageId":"\#(markerMessageID)","content":{"type":"text","text":"Done."}}"#

  /// Shows the usage view of a session model.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - style: The text style of the ring.
  /// - Returns: The harness.
  static func mount(
    session: ScriptedSession, style: UsageRingView.TextStyle = .short
  ) -> HostedViewHarness<some View> {
    HostedViewHarness(size: size) {
      ContextUsageView(session: session.model, style: style)
    }
  }

  /// The text of the usage element, or `nil` when the view shows no usage.
  ///
  /// - Parameter harness: The harness of the view.
  /// - Returns: The value of the usage element.
  static func usageText(in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: ContextUsageView.usageIdentifier)?.value
  }

  /// The text of the cost label, or `nil` when the view shows no cost.
  ///
  /// - Parameter harness: The harness of the view.
  /// - Returns: The label of the cost element.
  static func costText(in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: ContextUsageView.costIdentifier)?.label
  }

  @Test func aUsageUpdateShowsUsedOfSizeWithNoCost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session, style: .full)
    defer { harness.close() }
    let expected = UsageRingView.detailText(
      numerator: 1200, denominator: 4000, caption: Self.tokensCaption)

    try await session.sendUpdate(Self.firstUsage)
    await harness.pump(until: Self.waitTimeout) { Self.usageText(in: harness) == expected }

    #expect(Self.usageText(in: harness) == expected)
    #expect(Self.costText(in: harness) == nil)
  }

  @Test func aSecondUsageUpdateReplacesTheShownValuesAndShowsTheCost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session, style: .full)
    defer { harness.close() }
    let first = UsageRingView.detailText(
      numerator: 1200, denominator: 4000, caption: Self.tokensCaption)
    let second = UsageRingView.detailText(
      numerator: 3000, denominator: 4000, caption: Self.tokensCaption)
    let cost = ContextUsageView.costText(for: Cost(amount: 1.25, currency: "USD"))

    try await session.sendUpdate(Self.firstUsage)
    await harness.pump(until: Self.waitTimeout) { Self.usageText(in: harness) == first }
    try await session.sendUpdate(Self.secondUsage)
    await harness.pump(until: Self.waitTimeout) { Self.usageText(in: harness) == second }

    #expect(Self.usageText(in: harness) == second)
    #expect(Self.costText(in: harness) == cost)
  }

  @Test func theShortStyleShowsThePercentage() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let expected = UsageRingView.percentText(numerator: 1200, denominator: 4000)

    try await session.sendUpdate(Self.firstUsage)
    await harness.pump(until: Self.waitTimeout) { Self.usageText(in: harness) == expected }

    #expect(Self.usageText(in: harness) == expected)
  }

  @Test func withNoUsageUpdateTheViewIsHidden() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    let model = session.model

    try await session.sendUpdate(Self.markerUpdate)
    await harness.pump(until: Self.waitTimeout) { !model.transcript.isEmpty }

    #expect(!model.transcript.isEmpty)
    #expect(model.usage == nil)
    #expect(Self.usageText(in: harness) == nil)
    #expect(Self.costText(in: harness) == nil)
  }
}
