import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import SwiftUI
import Testing

/// Hosted tests of the thread accessibility (plan.md §6): reading groups,
/// announcements, focus moves, and Reduce Motion.
@Suite(.serialized, .hostedSerially) @MainActor struct ThreadAccessibilityHostedTests {
  /// The longest time that a test waits for a change, in seconds.
  static let waitTimeout: TimeInterval = 2

  /// The size of the host window. It is tall enough for each row.
  static let hostSize = CGSize(width: 640, height: 720)

  /// The number of streaming chunks that the silent stream test sends.
  static let chunkCount = 10

  /// The identifier of the first message.
  static let firstMessageID = "reading-message-1"

  /// The identifier of the second message.
  static let secondMessageID = "reading-message-2"

  /// The identifier of the permission request of the fixtures.
  static let requestID = "accessibility-permission-1"

  /// The text of a message with three paragraphs.
  static let threeParagraphs = "One.\n\nTwo.\n\nThree."

  /// Mounts an ``AgentThreadView`` of `thread` with the recording fakes.
  ///
  /// - Parameters:
  ///   - thread: The thread to show.
  ///   - announcer: The announcer of the environment.
  ///   - reporter: The focus reporter of the environment.
  /// - Returns: The harness, pumped one time.
  static func mount(
    _ thread: AgentThread,
    announcer: RecordingAnnouncer = RecordingAnnouncer(),
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) -> HostedViewHarness<some View> {
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: hostSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .environment(\.announcer, announcer)
        .environment(\.focusReporter, reporter)
    }
    harness.pump()
    return harness
  }

  /// A thread with two assistant messages. The first message has three
  /// paragraphs.
  static func twoMessageThread() -> AgentThread {
    let thread = AgentThread()
    thread.apply(
      .insert(
        .assistantMessage(ThreadFixtures.message(id: firstMessageID, text: threeParagraphs)),
        after: nil))
    thread.apply(
      .insert(
        .assistantMessage(ThreadFixtures.message(id: secondMessageID, text: "Four.")),
        after: firstMessageID))
    return thread
  }

  // MARK: - Reading groups

  @Test func eachParagraphOfAMessageLinksTheOtherParagraphs() throws {
    let harness = Self.mount(Self.twoMessageThread())
    defer { harness.close() }

    let identifiers = (0..<3).map(ResponseView.paragraphIdentifier(index:))
    for identifier in identifiers {
      let paragraph = try #require(harness.element(identifier: identifier))
      let linked = Set(paragraph.linkedElements.compactMap(\.identifier))
      let others = Set(identifiers.filter { $0 != identifier })
      #expect(others.isSubset(of: linked), "\(identifier) links \(linked)")
    }
  }

  @Test func eachRowOfTheThreadLinksTheOtherRows() throws {
    let harness = Self.mount(Self.twoMessageThread())
    defer { harness.close() }

    let first = try #require(harness.element(identifier: ItemRow.identifier(for: Self.firstMessageID)))
    let linked = first.linkedElements.compactMap(\.identifier)
    #expect(linked.contains(ItemRow.identifier(for: Self.secondMessageID)))
  }

  @Test func aStandaloneResponseLinksItsParagraphs() throws {
    let message = ThreadFixtures.message(id: "standalone", text: Self.threeParagraphs)
    let harness = HostedViewHarness(ResponseView(message: message, streaming: nil), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let first = try #require(harness.element(identifier: ResponseView.paragraphIdentifier(index: 0)))
    let linked = first.linkedElements.compactMap(\.identifier)
    #expect(linked.contains(ResponseView.paragraphIdentifier(index: 2)))
  }

  @Test func aParagraphReadsItsMathAtItsPlaceAndKeepsTheMathElement() {
    let message = ThreadFixtures.message(id: "math", text: "Let $x^2$ be big.")
    let harness = HostedViewHarness(ResponseView(message: message, streaming: nil), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains("Let x^2 be big."))
    #expect(harness.element(identifier: MathView.identifier(display: false))?.label == "x^2")
  }

  // MARK: - Announcements

  @Test func streamingChunksAreSilentAndATurnCompletionAnnouncesOneTime() async {
    let thread = AgentThread()
    let announcer = RecordingAnnouncer()
    let harness = Self.mount(thread, announcer: announcer)
    defer { harness.close() }

    thread.apply(.setState(.running))
    thread.apply(.insert(.assistantMessage(Message(id: Self.firstMessageID, blocks: [])), after: nil))
    for index in 0..<Self.chunkCount {
      thread.apply(.appendStreaming(id: Self.firstMessageID, text: "Chunk \(index). "))
      harness.pump()
    }
    #expect(announcer.announcements.isEmpty)

    thread.apply(.closeStreaming(id: Self.firstMessageID))
    thread.apply(.setState(.idle(.endTurn)))
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }
    harness.pump()

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Response complete", priority: .medium)
      ])
  }

  @Test func anActionRequiredAnnouncesOneTimeWithHighPriority() async {
    let thread = AgentThread()
    let announcer = RecordingAnnouncer()
    let harness = Self.mount(thread, announcer: announcer)
    defer { harness.close() }
    let request = ThreadFixtures.permissionRequest(id: Self.requestID)

    thread.apply(.addPermission(request))
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }
    harness.pump()

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(
          message: "Action required: \(request.title)", priority: .high)
      ])
  }

  @Test func aToolResultAnnouncesTheTitleAndTheStatus() async {
    let thread = AgentThread()
    let call = ThreadFixtures.toolCall(status: .inProgress)
    thread.apply(.insert(.toolCall(call), after: nil))
    let announcer = RecordingAnnouncer()
    let harness = Self.mount(thread, announcer: announcer)
    defer { harness.close() }
    #expect(announcer.announcements.isEmpty)

    thread.apply(.patch(id: call.id, .toolCall(status: .value(.completed))))
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }

    #expect(
      announcer.announcements.map(\.message) == [
        ToolCallView.accessibilityLabel(title: call.title, status: .completed)
      ])
  }

  // MARK: - Focus

  @Test func theFocusMovesToTheCardThenBackToThePromptEditor() async {
    let thread = AgentThread()
    let reporter = RecordingFocusReporter()
    let harness = Self.mount(thread, reporter: reporter)
    defer { harness.close() }
    let cardIdentifier = PendingRequestsHost.identifier(for: Self.requestID)

    thread.apply(.addPermission(ThreadFixtures.permissionRequest(id: Self.requestID)))
    await harness.pump(until: Self.waitTimeout) { reporter.moves.count >= 2 }

    #expect(reporter.moves.contains(cardIdentifier))
    #expect(reporter.moves.contains(PermissionView.identifier))

    thread.apply(.resolvePermission(PermissionRequestID(Self.requestID)))
    await harness.pump(until: Self.waitTimeout) {
      reporter.moves.last == StockPromptEditor.identifier
    }

    #expect(reporter.moves.last == StockPromptEditor.identifier)
  }

  @Test func theThreadViewMovesTheFocusOfTheMoverOfTheHost() async {
    let thread = AgentThread()
    let mover = AccessibilityFocusMover()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.hostSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .environment(\.accessibilityFocusMover, mover)
    }
    defer { harness.close() }
    harness.pump()
    #expect(mover.lastMove == nil)

    thread.apply(.addPermission(ThreadFixtures.permissionRequest(id: Self.requestID)))
    await harness.pump(until: Self.waitTimeout) { mover.lastMove != nil }
    #expect(mover.lastMove != nil)

    thread.apply(.resolvePermission(PermissionRequestID(Self.requestID)))
    await harness.pump(until: Self.waitTimeout) {
      mover.lastMove?.identifier == StockPromptEditor.identifier
    }

    #expect(mover.lastMove?.identifier == StockPromptEditor.identifier)
  }

  // MARK: - Reduce Motion

  @Test func reduceMotionStopsTheShimmerInAThread() async {
    let (thread, _) = Self.runningReasoningThread()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.hostSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .environment(\._accessibilityReduceMotion, true)
    }
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: ShimmerView.identifier) != nil
    }

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == ShimmerView.staticValue)
  }

  @Test func withNoReduceMotionTheShimmerAnimatesInAThread() async {
    let (thread, _) = Self.runningReasoningThread()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.hostSize, actions: actions) {
      AgentThreadView(thread: thread, actions: actions)
        .environment(\._accessibilityReduceMotion, false)
    }
    defer { harness.close() }
    await harness.pump(until: Self.waitTimeout) {
      harness.element(identifier: ShimmerView.identifier) != nil
    }

    #expect(
      harness.element(identifier: ShimmerView.identifier)?.value == ShimmerView.animatingValue)
  }

  @Test func aReasoningBlockHasItsProgressInItsLabel() throws {
    let (thread, reasoning) = Self.runningReasoningThread()
    let harness = Self.mount(thread)
    defer { harness.close() }

    let block = try #require(
      harness.element(identifier: ReasoningView.identifier(for: reasoning.id)))
    #expect(block.label == "Reasoning, in progress")
  }

  /// A running thread whose last item is a reasoning record.
  ///
  /// - Returns: The thread and the record.
  static func runningReasoningThread() -> (AgentThread, Reasoning) {
    let thread = AgentThread()
    let reasoning = ThreadFixtures.reasoning(id: "accessibility-reasoning")
    thread.apply(.insert(.reasoning(reasoning), after: nil))
    thread.apply(.setState(.running))
    return (thread, reasoning)
  }
}
