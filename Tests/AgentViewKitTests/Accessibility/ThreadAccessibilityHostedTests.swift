@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The questions that the tests ask of the steps that the reader of the turn
/// announcements of a hosted thread reports through
/// ``SwiftUI/EnvironmentValues/turnAnnouncementReport``.
extension ReportRecorder<TurnAnnouncementStep> {
  /// Whether the reader started to read the update tap of the session model.
  var hasStarted: Bool {
    values.contains { if case .started = $0 { true } else { false } }
  }

  /// The announcement of each idle state update that the reader handled, in
  /// report order. `nil` is an idle with no announcement.
  var idleAnnouncements: [String?] {
    values.compactMap { step -> String?? in
      guard case .handled(.stateUpdate(.idle), let announcement) = step else { return nil }
      return .some(announcement)
    }
  }
}

/// Hosted tests of the thread accessibility (plan.md §6): reading groups,
/// announcements, focus moves, and Reduce Motion.
///
/// Each test waits for a model value that the update is certain to change,
/// and then makes one render pass before it reads the view. The tool result
/// and action required announcements, and the focus moves, come from the
/// change actions and the appear actions of the views, which the render pass
/// runs. The turn announcements come from a reader task; the tests wait for
/// the steps that the reader reports (a ``ReportRecorder``) or for
/// the announcement in the observable ``RecordingAnnouncer``.
@Suite(.serialized, .hostedSerially) @MainActor struct ThreadAccessibilityHostedTests {
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
  /// model, with the recording announcer and a recorder of the steps of the
  /// turn announcement reader. A ``RequestDeck`` of the session and a deck of
  /// the connection are next to the thread view, as an app arranges them,
  /// because each deck announces the new requests of its model.
  ///
  /// The helper makes one ``HostedViewHarness/render()`` pass, and then waits
  /// for the event that the reader started to read the update tap. Thus the
  /// reader sees each update that the test sends after this call.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - announcer: The announcer of the environment.
  ///   - steps: The recorder of the steps of the turn announcement reader.
  /// - Returns: The harness.
  static func makeHarness(
    session: ScriptedSession, announcer: RecordingAnnouncer,
    steps: ReportRecorder<TurnAnnouncementStep> = ReportRecorder()
  ) async -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: hostSize) {
      VStack {
        AgentThreadView(session: session.model, connection: session.connection)
        RequestDeck(session: session.model)
        RequestDeck(connection: session.connection)
      }
      .accessibilityFocusScope()
      .environment(\.announcer, announcer)
      .environment(\.turnAnnouncementReport, steps.report)
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    await ObservationWait.until { steps.hasStarted }
    return harness
  }

  /// Sends two agent messages from the agent of `session`, waits for the
  /// event that the model holds each message, and makes one
  /// ``HostedViewHarness/render()`` pass of `harness`. The first message has
  /// three paragraphs.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the thread of the session.
  /// - Returns: The row key of each message entry, in transcript order.
  /// - Throws: The error of the transport.
  static func sendTwoMessages(
    to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws -> [String] {
    try await session.send(
      update: BackgroundRunScript.makeChunkUpdate(messageID: firstMessageID, text: threeParagraphs))
    try await session.send(
      update: BackgroundRunScript.makeChunkUpdate(messageID: secondMessageID, text: secondMessageText))
    let model = session.model
    await harness.render { model.transcript.count == readingMessageCount }
    return model.transcript.map(\.rowKey)
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
    harness.render()
    #expect(harness.element(identifier: ShimmerView.identifier) == nil)

    try await session.sendUpdate(ScriptedSession.runningState)
    let model = session.model
    await harness.render { ComposerSessionModelHostedTests.isRunning(model) }

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
  /// start, and waits for the event that the session model replays. The
  /// agent of `session` must hold its answer to the request.
  ///
  /// - Parameter session: The scripted session.
  /// - Returns: The task of the request.
  static func beginReplay(of session: ScriptedSession) async -> Task<SessionModel, any Error> {
    let resume = Task { try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest) }
    let model = session.model
    await ObservationWait.until { model.isReplaying }
    return resume
  }

  /// Releases the held answer of the `session/resume` request, waits for the
  /// event that the replay ends, and makes one ``HostedViewHarness/render()``
  /// pass of `harness`.
  ///
  /// - Parameters:
  ///   - resume: The task of the request from ``beginReplay(of:)``.
  ///   - session: The scripted session.
  ///   - harness: The harness that shows the thread of the session.
  /// - Throws: The error of the request.
  static func endReplay(
    _ resume: Task<SessionModel, any Error>, of session: ScriptedSession,
    rendering harness: HostedViewHarness<some View>
  ) async throws {
    session.agent.releaseHeldAnswer()
    _ = try await resume.value
    let model = session.model
    await harness.render { !model.isReplaying }
  }

  // MARK: - Reading groups

  @Test func eachParagraphOfAnAgentMessageEntryLinksTheOtherParagraphs() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = await Self.makeHarness(session: session, announcer: RecordingAnnouncer())
    defer { harness.close() }
    _ = try await Self.sendTwoMessages(to: session, rendering: harness)

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
    let harness = await Self.makeHarness(session: session, announcer: RecordingAnnouncer())
    defer { harness.close() }
    let keys = try await Self.sendTwoMessages(to: session, rendering: harness)
    let firstKey = try #require(keys.first)
    let secondKey = try #require(keys.last)

    let first = try #require(harness.element(identifier: ItemRow.identifier(for: firstKey)))
    let linked = first.linkedElements.compactMap(\.identifier)
    #expect(linked.contains(ItemRow.identifier(for: secondKey)))
  }

  @Test func aStandaloneResponseLinksItsParagraphs() throws {
    let harness = HostedViewHarness(ResponseView(id: "standalone", markdown: Self.threeParagraphs), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    let first = try #require(harness.element(identifier: ResponseView.paragraphIdentifier(index: 0)))
    let linked = first.linkedElements.compactMap(\.identifier)
    #expect(linked.contains(ResponseView.paragraphIdentifier(index: 2)))
  }

  @Test func aParagraphReadsItsMathAtItsPlaceAndKeepsTheMathElement() {
    let harness = HostedViewHarness(ResponseView(id: "math", markdown: "Let $x^2$ be big."), size: Self.hostSize)
    defer { harness.close() }
    harness.render()

    let labels = harness.accessibilityElements().compactMap(\.label)
    #expect(labels.contains("Let x^2 be big."))
    #expect(harness.element(identifier: MathView.identifier(display: false))?.label == "x^2")
  }

  // MARK: - Announcements of a session model

  /// The idle that ends the work of the prompt announces "Response
  /// complete" one time, and the streamed chunks before it announce
  /// nothing.
  ///
  /// The announcement comes from a reader task
  /// (``ThreadAccessibility/makeTurnAnnouncements(of:report:)``). The test
  /// waits for the event that the observable ``RecordingAnnouncer`` holds an
  /// announcement: the idle after the echo of the prompt is certain to give
  /// one.
  @Test func aPromptThatGoesIdleAfterItRunsAnnouncesThatTheResponseIsCompleteOneTime() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = await Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }
    let model = session.model

    _ = try await model.prompt([.text(TextContent(text: "Hello."))])
    try await session.sendUpdate(ScriptedSession.runningState)
    await ObservationWait.until { model.agentState != nil }
    for index in 0..<Self.chunkCount {
      try await session.send(
        update: BackgroundRunScript.makeChunkUpdate(
          messageID: Self.streamedMessageID, text: SessionModelRedrawScopeTests.streamedChunk(at: index)))
      let sent = (0...index).map(SessionModelRedrawScopeTests.streamedChunk(at:)).joined()
      await harness.render {
        BackgroundRunsHostedTests.agentMessage(messageID: Self.streamedMessageID, in: model)
          .map { SessionTranscriptViewHostedTests.text(of: $0.content) } == sent
      }
    }
    #expect(announcer.announcements.isEmpty)

    try await session.sendUpdate(ScriptedSession.endTurnState)
    await ObservationWait.until { !announcer.announcements.isEmpty }

    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Response complete", priority: .medium)
      ])
  }

  @Test func aToolCallEntryThatCompletesAnnouncesItsTitleAndItsStatus() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = await Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }
    let model = session.model

    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .inProgress)
    await harness.render { !model.transcript.isEmpty }
    #expect(announcer.announcements.isEmpty)

    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .completed)
    await harness.render { Self.isCompletedToolCall(model.transcript.first) }

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
    let harness = await Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }

    _ = try await session.sendPermissionRequest(id: Self.agentRequestID, rendering: harness)
    harness.render()

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
    let harness = await Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }
    let connection = session.connection

    let login = session.startLogin()
    await harness.render { !connection.pendingElicitations.isEmpty }
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
    let harness = await Self.makeHarness(session: session, announcer: announcer)
    defer { harness.close() }
    let model = session.model

    let resume = await Self.beginReplay(of: session)
    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .inProgress)
    await harness.render { !model.transcript.isEmpty }
    try await session.sendToolCallUpdate(title: Self.toolTitle, status: .completed)
    await harness.render { Self.isCompletedToolCall(model.transcript.first) }
    #expect(Self.isCompletedToolCall(model.transcript.first))
    try await Self.endReplay(resume, of: session, rendering: harness)

    #expect(announcer.announcements.isEmpty)
  }

  /// A replay of a run that ends announces no stop.
  ///
  /// The stop announcement comes from a reader task
  /// (``ThreadAccessibility/makeTurnAnnouncements(of:report:)``). The reader
  /// reports each update that it handled (a ``ReportRecorder``).
  /// The test waits for the event that the reader handled the idle of the
  /// replay, and then checks that the reader gave no announcement for it and
  /// that the announcer holds none.
  @Test func aReplayOfARunThatEndsMakesNoStopAnnouncement() async throws {
    let session = try await ScriptedSession.open { $0.heldMethods = [ScriptedSession.resumeMethod] }
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let steps = ReportRecorder<TurnAnnouncementStep>()
    let harness = await Self.makeHarness(session: session, announcer: announcer, steps: steps)
    defer { harness.close() }
    let model = session.model

    let resume = await Self.beginReplay(of: session)
    try await session.sendUpdate(ScriptedSession.runningState)
    await harness.render { model.agentState != nil }
    try await session.sendUpdate(ScriptedSession.endTurnState)
    await harness.render { Self.isIdle(model.agentState) }
    await ObservationWait.until { !steps.idleAnnouncements.isEmpty }
    #expect(steps.idleAnnouncements == [nil])
    try await Self.endReplay(resume, of: session, rendering: harness)

    #expect(announcer.announcements.isEmpty)
  }

  // MARK: - Focus

  /// Shows the thread view and the deck of a session in one focus scope, as
  /// an app arranges them.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The thread view and the deck.
  static func threadAndDeck(of model: SessionModel) -> some View {
    VStack {
      AgentThreadView(session: model)
      RequestDeck(session: model)
    }
    .accessibilityFocusScope()
  }

  @Test func aNewCardTakesNoFocusAndTheLastAnswerMovesTheFocusToThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let harness = HostedViewHarness(size: Self.hostSize) {
      Self.threadAndDeck(of: session.model)
        .environment(\.focusReporter, reporter)
        .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    harness.render()
    let model = session.model

    let id = try await session.sendPermissionRequest(id: 1, rendering: harness)
    harness.render()

    #expect(reporter.moves.isEmpty)

    await session.model.cancelPermission(id)
    await harness.render { model.pendingPermissions.isEmpty }

    #expect(reporter.moves == [StockPromptEditor.identifier])
  }

  @Test func theThreadAndTheDeckMoveTheFocusOfTheMoverOfTheHost() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let mover = AccessibilityFocusMover()
    let harness = HostedViewHarness(size: Self.hostSize) {
      Self.threadAndDeck(of: session.model)
        .environment(\.accessibilityFocusMover, mover)
        .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    harness.render()
    #expect(mover.lastMove == nil)
    let model = session.model

    let id = try await session.sendPermissionRequest(id: 1, rendering: harness)
    harness.render()
    #expect(mover.lastMove == nil)

    await session.model.cancelPermission(id)
    await harness.render { model.pendingPermissions.isEmpty }

    #expect(mover.lastMove?.identifier == StockPromptEditor.identifier)
  }

  // MARK: - Reduce Motion

  @Test func reduceMotionStopsTheShimmerOfARunningSession() async throws {
    try await Self.expectShimmerOfARunningSession(reduceMotion: true, value: ShimmerView.staticValue)
  }

  @Test func withNoReduceMotionTheShimmerOfARunningSessionAnimates() async throws {
    try await Self.expectShimmerOfARunningSession(reduceMotion: false, value: ShimmerView.animatingValue)
  }
}
