import AgentViewKit
import AgentViewKitTestSupport
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct ReasoningViewHostedTests {
  /// The name of the tool that the indicator test shows.
  static let toolName = "Read README.md"

  // MARK: - Shimmer

  @Test func reduceMotionMakesTheShimmerStatic() {
    let harness = HostedViewHarness {
      ShimmerView(text: "Thinking")
        .environment(\._accessibilityReduceMotion, true)
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == "static")
    #expect(harness.element(identifier: ShimmerView.identifier)?.label == "Thinking")
  }

  @Test func noReduceMotionMakesTheShimmerAnimate() {
    let harness = HostedViewHarness {
      ShimmerView(text: "Thinking")
        .environment(\._accessibilityReduceMotion, false)
    }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == "animating")
  }

  // MARK: - Activity indicator

  @Test func theThinkingIndicatorShowsTheShimmer() {
    let harness = HostedViewHarness { ActivityIndicator(state: .thinking) }
    defer { harness.close() }
    harness.render()

    #expect(ActivityIndicator.identifier == "activity-indicator")
    #expect(harness.element(identifier: ShimmerView.identifier) != nil)
  }

  @Test func theToolIndicatorShowsTheToolName() {
    let harness = HostedViewHarness { ActivityIndicator(state: .runningTool(Self.toolName)) }
    defer { harness.close() }
    harness.render()

    #expect(Self.showsText(Self.toolName, in: harness))
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
  }

  /// Tells whether an accessibility label of `harness` holds `text`.
  ///
  /// - Parameters:
  ///   - text: The text to find.
  ///   - harness: The harness that shows the indicator.
  /// - Returns: `true` when a label holds the text.
  static func showsText<Content: View>(_ text: String, in harness: HostedViewHarness<Content>) -> Bool {
    harness.accessibilityElements().compactMap(\.label).contains { $0.contains(text) }
  }

  @Test func theIdleIndicatorShowsNothing() {
    let harness = HostedViewHarness { ActivityIndicator(state: .idle) }
    defer { harness.close() }
    harness.render()

    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
    let labels = harness.accessibilityElements().compactMap(\.label)
    let showsText = labels.contains { !$0.isEmpty }
    #expect(!showsText)
  }

  /// Each update of the agent changes a value of the session model that the
  /// indicator reads: the agent state, then the status of the tool call,
  /// then the agent state again. The test waits for that model value, makes
  /// one render pass, and then reads the indicator.
  @Test func theIndicatorOfASessionShowsTheRunningToolCallAndGoesAwayAtIdle() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness { ActivityIndicator(session: session.model) }
    defer { harness.close() }
    let model = session.model

    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.render { ComposerSessionModelHostedTests.isRunning(model) }
    #expect(harness.element(identifier: ShimmerView.identifier) != nil)

    try await session.sendToolCallUpdate(title: Self.toolName, status: .inProgress)
    await harness.render { BackgroundRunsHostedTests.toolCall(id: Self.toolName, in: model)?.status == .inProgress }
    #expect(Self.showsText(Self.toolName, in: harness))
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)

    try await session.sendUpdate(ScriptedSession.idleState)
    await harness.render { CancelFixtures.isIdle(model.agentState) }
    #expect(!Self.showsText(Self.toolName, in: harness))
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
  }
}
