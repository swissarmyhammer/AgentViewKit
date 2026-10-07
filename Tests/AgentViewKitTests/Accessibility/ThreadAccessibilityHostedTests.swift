import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
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

  /// The text of a message with three paragraphs.
  static let threeParagraphs = "One.\n\nTwo.\n\nThree."

  /// The number of paragraphs of ``threeParagraphs``.
  static let paragraphCount = 3

  /// The text of the second message, with one paragraph.
  static let secondMessageText = "Four."

  /// The number of agent messages that the reading group tests send.
  static let readingMessageCount = 2

  /// The title of the tool call that the session tests send.
  static let toolTitle = "Build"

  /// The JSON-RPC id of the request that the agent of a session test sends.
  static let agentRequestID = 1

  /// The `messageId` of the agent message that the session tests stream.
  static let streamedMessageID = "accessibility-streamed"

  /// Makes an ``AgentThreadView`` of a scripted session and its connection
  /// model, with the recording announcer.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - announcer: The announcer of the environment.
  /// - Returns: The harness, pumped one time.
  static func makeHarness(session: ScriptedSession, announcer: RecordingAnnouncer) -> HostedViewHarness<some View> {
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: hostSize, actions: actions) {
      AgentThreadView(session: session.model, connection: session.connection, actions: actions)
        .environment(\.announcer, announcer)
    }
    harness.pump()
    return harness
  }

  /// Sends two agent messages from the agent of `session`, and pumps
  /// `harness` until the thread shows the row of each message. The first
  /// message has three paragraphs.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the thread of the session.
  /// - Returns: The row key of each message entry, in transcript order.
  /// - Throws: The error of the transport.
  static func sendTwoMessages(
    to session: ScriptedSession, pumping harness: HostedViewHarness<some View>
  ) async throws -> [String] {
    try await session.send(
      update: BackgroundRunScript.makeChunkUpdate(messageID: firstMessageID, text: threeParagraphs))
    try await session.send(
      update: BackgroundRunScript.makeChunkUpdate(messageID: secondMessageID, text: secondMessageText))
    await harness.pump(until: waitTimeout) {
      session.model.transcript.count == readingMessageCount
        && session.model.transcript.allSatisfy { harness.element(identifier: ItemRow.identifier(for: $0.rowKey)) != nil }
    }
    harness.pump()
    return session.model.transcript.map(\.rowKey)
  }

  /// Expects that the shimmer of the activity indicator of a running session
  /// has `value` while the Reduce Motion setting is `reduceMotion`.
  ///
  /// - Parameters:
  ///   - reduceMotion: The Reduce Motion setting of the environment.
  ///   - value: The accessibility value that the shimmer must have.
  static func expectShimmerOfARunningSession(reduceMotion: Bool, value: String) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(size: hostSize) {
      ActivityIndicator(session: session.model)
        .environment(\._accessibilityReduceMotion, reduceMotion)
    }
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)

    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.pump(until: waitTimeout) {
      harness.element(identifier: ShimmerView.identifier) != nil
    }

    #expect(harness.element(identifier: ShimmerView.identifier)?.value == value)
  }

  /// Tells whether `entry` is a tool call entry with the status `completed`.
  ///
  /// - Parameter entry: A transcript entry, or `nil`.
  /// - Returns: `true` for a completed tool call entry.
  static func isCompletedToolCall(_ entry: TranscriptEntry?) -> Bool {
    guard case .toolCall(let call)? = entry else { return false }
    return call.status == .completed
  }

  /// Tells whether `state` is the idle agent state.
  ///
  /// - Parameter state: An `agentState`, or `nil`.
  /// - Returns: `true` for `.idle`.
  static func isIdle(_ state: StateUpdate?) -> Bool {
    guard case .idle? = state else { return false }
    return true
  }

  /// Starts a `session/resume` request that replays the history from the
  /// start, and pumps `harness` until the session model replays. The agent
  /// of `session` must hold its answer to the request.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness to pump while the test waits.
  /// - Returns: The task of the request.
  static func beginReplay(
    of session: ScriptedSession, pumping harness: HostedViewHarness<some View>
  ) async -> Task<SessionModel, any Error> {
    let resume = Task { try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest) }
    await harness.pump(until: waitTimeout) { session.model.isReplaying }
    return resume
  }

  /// Releases the held answer of the `session/resume` request, and pumps
  /// `harness` until the replay ends.
  ///
  /// - Parameters:
  ///   - resume: The task of the request from ``beginReplay(of:pumping:)``.
  ///   - session: The scripted session.
  ///   - harness: The harness to pump while the test waits.
  /// - Throws: The error of the request.
  static func endReplay(
    _ resume: Task<SessionModel, any Error>, of session: ScriptedSession,
    pumping harness: HostedViewHarness<some View>
  ) async throws {
    session.agent.releaseHeldAnswer()
    _ = try await resume.value
    await harness.pump(until: waitTimeout) { !session.model.isReplaying }
    harness.pump()
  }

  // MARK: - Reading groups

  @Test func eachParagraphOfAnAgentMessageEntryLinksTheOtherParagraphs() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.makeHarness(session: session, announcer: RecordingAnnouncer())
    defer { harness.close() }
    _ = try await Self.sendTwoMessages(to: session, pumping: harness)

    let identifiers = (0..<Self.paragraphCount).map(ResponseView.paragraphIdentifier(index:))
    for identifier in identifiers {
      let paragraph = try #require(harness.element(identifier: identifier))
      let linked = Set(paragraph.linkedElements.compactMap(\.identifier))
      let others = Set(identifiers.filter { $0 != identifier })
      #expect(others.isSubset(of: linked), "\(identifier) links \(linked)")
    }
  }

  @Test func eachRowOfTheThreadOfASessionLinksTheOtherRows() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.makeHarness(session: session, announcer: RecordingAnnouncer())
    defer { harness.close() }
    let keys = try await Self.sendTwoMessages(to: session, pumping: harness)
    let firstKey = try #require(keys.first)
    let secondKey = try #require(keys.last)

    let first = try #require(harness.element(identifier: ItemRow.identifier(for: firstKey)))
    let linked = first.linkedElements.compactMap(\.identifier)
    #expect(linked.contains(ItemRow.identifier(for: secondKey)))
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

  // MARK: - Announcements of a session model

  @Test func aSessionThatGoesIdleAfterItRunsAnnouncesThatTheResponseIsCompleteOneTime() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.pump(until: Self.waitTimeout) { session.model.agentState != nil }
    for index in 0..<Self.chunkCount {
      try await session.send(
        update: BackgroundRunScript.makeChunkUpdate(messageID: Self.streamedMessageID, text: "Chunk \(index). "))
      harness.pump()
    }
    await harness.pump(until: Self.waitTimeout) { !session.model.transcript.isEmpty }
    #expect(announcer.announcements.isEmpty)

    try await session.sendUpdate(ScriptedSession.endTurnState)
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }
    harness.pump()

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Response complete", priority: .medium)
      ])
  }

  @Test func aToolCallEntryThatCompletesAnnouncesItsTitleAndItsStatus() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .inProgress)
    await harness.pump(until: Self.waitTimeout) { !session.model.transcript.isEmpty }
    harness.pump()
    #expect(announcer.announcements.isEmpty)

    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .completed)
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(
          message: ToolCallView.accessibilityLabel(title: Self.toolTitle, status: .completed), priority: .medium)
      ])
  }

  @Test func aPendingPermissionOfTheSessionAnnouncesThatAnActionIsRequired() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    _ = try await session.sendPermissionRequest(
      id: Self.agentRequestID, pumping: harness, timeout: Self.waitTimeout)
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }
    harness.pump()

    let request = try #require(session.model.pendingPermissions.first)
    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Action required: \(request.request.title)", priority: .high)
      ])
  }

  @Test func aLoginElicitationOfTheConnectionAnnouncesThatAnActionIsRequired() async throws {
    let session = try await ScriptedSession.openWithLoginElicitation(id: Self.agentRequestID)
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    let login = session.startLogin()
    await harness.pump(until: Self.waitTimeout) { !announcer.announcements.isEmpty }
    harness.pump()
    session.agent.releaseHeldAnswer()
    try await login.value

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(
          message: "Action required: \(ScriptedSession.loginElicitationMessage)", priority: .high)
      ])
  }

  @Test func aReplayOfFinishedToolCallsMakesNoToolResultAnnouncement() async throws {
    let session = try await ScriptedSession.open { $0.heldMethods = [ScriptedSession.resumeMethod] }
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    let resume = await Self.beginReplay(of: session, pumping: harness)
    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .inProgress)
    await harness.pump(until: Self.waitTimeout) { !session.model.transcript.isEmpty }
    harness.pump()
    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .completed)
    await harness.pump(until: Self.waitTimeout) { Self.isCompletedToolCall(session.model.transcript.first) }
    harness.pump()
    #expect(Self.isCompletedToolCall(session.model.transcript.first))
    try await Self.endReplay(resume, of: session, pumping: harness)

    #expect(announcer.announcements.isEmpty)
  }

  @Test func aReplayOfARunThatEndsMakesNoStopAnnouncement() async throws {
    let session = try await ScriptedSession.open { $0.heldMethods = [ScriptedSession.resumeMethod] }
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    let resume = await Self.beginReplay(of: session, pumping: harness)
    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.pump(until: Self.waitTimeout) { session.model.agentState != nil }
    harness.pump()
    try await session.sendUpdate(ScriptedSession.endTurnState)
    await harness.pump(until: Self.waitTimeout) { Self.isIdle(session.model.agentState) }
    harness.pump()
    #expect(Self.isIdle(session.model.agentState))
    try await Self.endReplay(resume, of: session, pumping: harness)

    #expect(announcer.announcements.isEmpty)
  }

  // MARK: - Focus

  @Test func theFocusMovesToTheCardThenBackToThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.hostSize, actions: actions) {
      AgentThreadView(session: session.model, actions: actions)
        .environment(\.focusReporter, reporter)
    }
    defer { harness.close() }
    harness.pump()

    let id = try #require(
      try await session.sendPermissionRequest(id: 1, pumping: harness, timeout: Self.waitTimeout))
    await harness.pump(until: Self.waitTimeout) { reporter.moves.count >= 2 }

    #expect(reporter.moves.contains(PendingRequestsHost.identifier(for: id.uuidString)))
    #expect(reporter.moves.contains(PermissionView.identifier))

    session.model.cancelPermission(id)
    await harness.pump(until: Self.waitTimeout) {
      reporter.moves.last == StockPromptEditor.identifier
    }

    #expect(reporter.moves.last == StockPromptEditor.identifier)
  }

  @Test func theThreadViewMovesTheFocusOfTheMoverOfTheHost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let mover = AccessibilityFocusMover()
    let actions = NoopThreadActions()
    let harness = threadViewHarness(size: Self.hostSize, actions: actions) {
      AgentThreadView(session: session.model, actions: actions)
        .environment(\.accessibilityFocusMover, mover)
    }
    defer { harness.close() }
    harness.pump()
    #expect(mover.lastMove == nil)

    let id = try #require(
      try await session.sendPermissionRequest(id: 1, pumping: harness, timeout: Self.waitTimeout))
    await harness.pump(until: Self.waitTimeout) { mover.lastMove != nil }
    #expect(mover.lastMove != nil)

    session.model.cancelPermission(id)
    await harness.pump(until: Self.waitTimeout) {
      mover.lastMove?.identifier == StockPromptEditor.identifier
    }

    #expect(mover.lastMove?.identifier == StockPromptEditor.identifier)
  }

  // MARK: - Reduce Motion

  @Test func reduceMotionStopsTheShimmerOfARunningSession() async throws {
    try await Self.expectShimmerOfARunningSession(reduceMotion: true, value: ShimmerView.staticValue)
  }

  @Test func withNoReduceMotionTheShimmerOfARunningSessionAnimates() async throws {
    try await Self.expectShimmerOfARunningSession(reduceMotion: false, value: ShimmerView.animatingValue)
  }

  @Test func anInProgressReasoningBlockHasItsProgressInItsLabel() throws {
    let reasoning = ThreadFixtures.reasoning(id: "accessibility-reasoning")
    let harness = HostedViewHarness(ReasoningView(record: reasoning, isInProgress: true), size: Self.hostSize)
    defer { harness.close() }
    harness.pump()

    let block = try #require(
      harness.element(identifier: ReasoningView.identifier(for: reasoning.id)))
    #expect(block.label == "Reasoning, in progress")
  }
}
