import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

@Suite(.serialized, .hostedSerially) @MainActor struct ReasoningViewHostedTests {
  /// The longest time that a test waits for the view to change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The name of the tool that the indicator test shows.
  static let toolName = "Read README.md"

  // MARK: - Shimmer

  @Test func reduceMotionMakesTheShimmerStatic() {
    let harness = HostedViewHarness {
      ShimmerView(text: "Thinking")
        .environment(\._accessibilityReduceMotion, true)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == "static")
    #expect(harness.element(identifier: ShimmerView.identifier)?.label == "Thinking")
  }

  @Test func noReduceMotionMakesTheShimmerAnimate() {
    let harness = HostedViewHarness {
      ShimmerView(text: "Thinking")
        .environment(\._accessibilityReduceMotion, false)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == "animating")
  }

  // MARK: - Activity indicator

  @Test func theThinkingIndicatorShowsTheShimmer() {
    let harness = HostedViewHarness { ActivityIndicator(state: .thinking) }
    defer { harness.close() }
    harness.pump()

    #expect(ActivityIndicator.identifier == "activity-indicator")
    #expect(harness.element(identifier: ShimmerView.identifier) != nil)
  }

  @Test func theToolIndicatorShowsTheToolName() {
    let harness = HostedViewHarness { ActivityIndicator(state: .runningTool(Self.toolName)) }
    defer { harness.close() }
    harness.pump()

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
    harness.pump()

    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
    let labels = harness.accessibilityElements().compactMap(\.label)
    let showsText = labels.contains { !$0.isEmpty }
    #expect(!showsText)
  }

  @Test func theIndicatorOfASessionShowsTheRunningToolCallAndGoesAwayAtIdle() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness { ActivityIndicator(session: session.model) }
    defer { harness.close() }

    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: ShimmerView.identifier) != nil }
    #expect(harness.element(identifier: ShimmerView.identifier) != nil)

    try await session.sendToolCallUpdate(title: Self.toolName, status: .inProgress)
    await harness.pump(until: Self.waitTimeout) { Self.showsText(Self.toolName, in: harness) }
    #expect(Self.showsText(Self.toolName, in: harness))
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)

    try await session.sendUpdate(ScriptedSession.idleState)
    await harness.pump(until: Self.waitTimeout) { !Self.showsText(Self.toolName, in: harness) }
    #expect(!Self.showsText(Self.toolName, in: harness))
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
  }
}
