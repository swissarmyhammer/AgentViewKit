import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct ReasoningViewHostedTests {
  /// The longest time that a test waits for the view to change, in seconds.
  static let waitTimeout: TimeInterval = 5

  /// The identifier of the reasoning record.
  static let reasoningID = "reasoning-under-test"

  /// The identifier of the message that follows the reasoning.
  static let answerID = "answer-under-test"

  /// The time when the reasoning started.
  static let startTime = Date(timeIntervalSinceReferenceDate: 800_000_000)

  /// The number of seconds that the reasoning takes.
  static let thinkingSeconds = 3

  /// The time when the reasoning ended.
  static let endTime = startTime.addingTimeInterval(TimeInterval(thinkingSeconds))

  /// The title that the completed reasoning shows.
  static let completedTitle = "Thought for \(thinkingSeconds) s"

  /// The name of the tool that the indicator test shows.
  static let toolName = "Read README.md"

  // MARK: - Fixtures

  /// Makes a running thread whose last item is a reasoning record.
  ///
  /// - Returns: The thread and the reasoning record.
  static func thinkingThread() -> (AgentThread, Reasoning) {
    let thread = AgentThread()
    let reasoning = Reasoning(
      id: reasoningID, segments: ["I must read the file first."], startedAt: startTime)
    thread.apply(.insert(.userMessage(ThreadFixtures.message(id: "question")), after: nil))
    thread.apply(.insert(.reasoning(reasoning), after: nil))
    thread.apply(.setState(.running))
    return (thread, reasoning)
  }

  /// Completes the reasoning: a message follows it, and the turn stops.
  ///
  /// - Parameters:
  ///   - thread: The thread.
  ///   - reasoning: The reasoning record.
  static func complete(_ thread: AgentThread, reasoning: Reasoning) {
    reasoning.endedAt = endTime
    thread.apply(
      .insert(.assistantMessage(ThreadFixtures.message(id: answerID, text: "Done.")), after: nil))
    thread.apply(.setState(.idle(.endTurn)))
  }

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

  // MARK: - Reasoning

  @Test func theLastReasoningShimmersWhileRunningAndThenShowsItsDuration() async {
    let (thread, reasoning) = Self.thinkingThread()
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: ShimmerView.identifier) != nil
    }

    #expect(harness.element(identifier: ReasoningView.identifier(for: Self.reasoningID)) != nil)
    #expect(harness.element(identifier: ShimmerView.identifier) != nil)
    #expect(harness.element(identifier: ReasoningView.bodyIdentifier(for: Self.reasoningID)) != nil)
    #expect(harness.element(identifier: ItemRow.placeholderIdentifier(for: Self.reasoningID)) == nil)

    Self.complete(thread, reasoning: reasoning)
    let titleID = ReasoningView.titleIdentifier(for: Self.reasoningID)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: titleID)?.label == Self.completedTitle
    }

    #expect(harness.element(identifier: titleID)?.label == Self.completedTitle)
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
    #expect(harness.element(identifier: ReasoningView.bodyIdentifier(for: Self.reasoningID)) == nil)
  }

  @Test func aUserExpansionSurvivesTheCollapseOnCompletion() async throws {
    let (thread, reasoning) = Self.thinkingThread()
    let harness = HostedViewHarness(AgentThreadView(thread: thread))
    defer { harness.close() }
    let toggleID = ReasoningView.toggleIdentifier(for: Self.reasoningID)
    let bodyID = ReasoningView.bodyIdentifier(for: Self.reasoningID)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: toggleID) != nil }

    try harness.press(identifier: toggleID)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) == nil }
    #expect(harness.element(identifier: bodyID) == nil)

    try harness.press(identifier: toggleID)
    await harness.pump(until: Self.waitTimeout) { harness.element(identifier: bodyID) != nil }
    #expect(harness.element(identifier: bodyID) != nil)

    Self.complete(thread, reasoning: reasoning)
    let titleID = ReasoningView.titleIdentifier(for: Self.reasoningID)
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: titleID)?.label == Self.completedTitle
    }

    #expect(harness.element(identifier: titleID)?.label == Self.completedTitle)
    #expect(harness.element(identifier: bodyID) != nil)
  }

  @Test func aReasoningWithNoTimesShowsATitleWithNoDuration() {
    let harness = HostedViewHarness {
      ReasoningView(record: ThreadFixtures.reasoning(id: Self.reasoningID), isInProgress: false)
    }
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: ReasoningView.titleIdentifier(for: Self.reasoningID))?.label == "Thought")
    #expect(harness.element(identifier: ReasoningView.bodyIdentifier(for: Self.reasoningID)) == nil)
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

    let labels = harness.accessibilityElements().compactMap(\.label)
    let showsName = labels.contains { $0.contains(Self.toolName) }
    #expect(showsName)
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)
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

  @Test func theActivityStateComesFromTheThread() {
    let thread = AgentThread()
    #expect(ActivityState(thread: thread) == .idle)

    thread.apply(.setState(.running))
    #expect(ActivityState(thread: thread) == .thinking)

    let call = ThreadFixtures.toolCall(id: "call", status: .inProgress)
    call.title = Self.toolName
    thread.apply(.insert(.toolCall(call), after: nil))
    #expect(ActivityState(thread: thread) == .runningTool(Self.toolName))

    thread.apply(.patch(id: "call", .toolCall(status: .value(.completed))))
    #expect(ActivityState(thread: thread) == .thinking)

    thread.apply(.setState(.idle(.endTurn)))
    #expect(ActivityState(thread: thread) == .idle)
  }

  @Test func theThreadTellsWhichItemIsLastWhileRunning() {
    let (thread, reasoning) = Self.thinkingThread()
    #expect(thread.lastItemID == Self.reasoningID)
    #expect(thread.isLastWhileRunning(Self.reasoningID))
    #expect(!thread.isLastWhileRunning("question"))

    Self.complete(thread, reasoning: reasoning)
    #expect(thread.lastItemID == Self.answerID)
    #expect(!thread.isLastWhileRunning(Self.reasoningID))

    thread.apply(.remove(id: Self.answerID))
    #expect(thread.lastItemID == Self.reasoningID)
    thread.apply(.clear)
    #expect(thread.lastItemID == nil)
  }
}
