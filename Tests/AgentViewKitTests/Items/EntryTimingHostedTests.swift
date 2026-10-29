#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The time decorator of the transcript rows: ``EntryTimingView``,
  /// `.entryTiming(_:)` and `.transcriptTiming(_:)`.
  ///
  /// Each test gives the connection model a ``SettableClock``, so that each
  /// entry gets a known start time and a known end time from the client
  /// model. The kit reads the times. It records no time itself.
  ///
  /// A test waits for the model value that an update is certain to change:
  /// the entry count, the idle state, or the status of the tool call. The
  /// model writes the times in the same step. Then the test makes one render
  /// pass before it reads a label.
  @Suite(.serialized, .hostedSerially) @MainActor struct EntryTimingHostedTests {
    /// A size that shows each row of the tests.
    static let tallSize = CGSize(width: 480, height: 1_200)

    /// The locale of the views of the tests.
    static let locale = Locale(identifier: "en_US")

    /// The first time of the clock of each test.
    static let start = Date(timeIntervalSinceReferenceDate: 800_000_000)

    /// The time from the start of the agent message to the start of the
    /// thought, in seconds.
    static let messageSeconds: TimeInterval = 7

    /// The time from the start of the thought to the idle state, in seconds.
    static let thoughtSeconds: TimeInterval = 3

    /// The time from the start of the tool call to its completion, in
    /// seconds.
    static let toolCallSeconds: TimeInterval = 4

    /// The `messageId` of the agent message of the tests.
    static let messageID = "timing-m"

    /// The `messageId` of the thought of the tests.
    static let thoughtID = "timing-t"

    /// The `messageId` of the user message of the tests.
    static let userMessageID = "timing-u"

    /// The title, and thus the `toolCallId`, of the tool call of the tests.
    static let callTitle = "Read README.md"

    /// The text of the host view that the one-row test wraps.
    static let hostText = "Host row"

    /// A chunk update of the tests.
    ///
    /// - Parameters:
    ///   - kind: The `sessionUpdate` tag, such as `agent_message_chunk`.
    ///   - messageID: The `messageId` of the chunk.
    /// - Returns: The JSON text of the update.
    static func chunk(_ kind: String, messageID: String) -> String {
      WireBlockJSON.makeChunk(kind, messageID: messageID, block: WireBlockJSON.makeText("Text of \(messageID)."))
    }

    /// Opens a scripted session whose connection model reads `clock`.
    ///
    /// - Parameter clock: The clock of the test.
    /// - Returns: The open session.
    /// - Throws: The error of `initialize` or of `session/new`.
    static func openSession(clock: SettableClock) async throws -> ScriptedSession {
      try await ScriptedSession.open(now: clock.now)
    }

    /// Mounts the thread of `model`, with the time decorator on each row
    /// when `showsTiming` is `true`.
    ///
    /// - Parameters:
    ///   - model: The session model.
    ///   - showsTiming: Whether the host attaches the decorator.
    /// - Returns: The harness.
    static func mountThread(_ model: SessionModel, showsTiming: Bool) -> HostedViewHarness<some View> {
      HostedViewHarness(size: tallSize) {
        AgentThreadView(session: model)
          .transcriptTiming(showsTiming)
          .environment(\.locale, locale)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// Sends one update, and waits until the transcript of the session has
    /// `count` entries.
    ///
    /// - Parameters:
    ///   - update: The JSON text of the update.
    ///   - count: The number of entries that the transcript must have.
    ///   - session: The scripted session.
    /// - Returns: The row key of the last entry.
    /// - Throws: The error of the transport, or an issue when the transcript
    ///   has no entry.
    static func send(_ update: String, expecting count: Int, to session: ScriptedSession) async throws -> String {
      try await session.sendUpdate(update)
      let model = session.model
      await ObservationWait.until { model.transcript.count == count }
      return try #require(model.transcript.last?.rowKey)
    }

    /// Sends the idle state, and waits until the session model is idle. The
    /// model ends the open entry in the same step.
    ///
    /// - Parameter session: The scripted session.
    /// - Throws: The error of the transport.
    static func sendIdleState(to session: ScriptedSession) async throws {
      try await session.sendUpdate(ScriptedSession.idleState)
      let model = session.model
      await ObservationWait.until { CancelAvailabilityTests.isIdle(model.agentState) }
    }

    /// The label of the time view of the row of `key`.
    ///
    /// - Parameters:
    ///   - key: The row key of the entry.
    ///   - harness: The harness that shows the thread.
    /// - Returns: The label, or `nil` when the row shows no time view.
    static func timingLabel(of key: String, in harness: HostedViewHarness<some View>) -> String? {
      harness.element(identifier: EntryTimingView.identifier(for: key))?.label
    }

    // MARK: - The decorator on each row

    @Test func eachRowShowsTheStartAndTheDurationOfItsEntry() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = Self.mountThread(session.model, showsTiming: true)
      defer { harness.close() }

      let messageKey = try await Self.send(
        Self.chunk("agent_message_chunk", messageID: Self.messageID), expecting: 1, to: session)
      clock.advance(by: Self.messageSeconds)
      let thoughtStart = clock.date
      let thoughtKey = try await Self.send(
        Self.chunk("agent_thought_chunk", messageID: Self.thoughtID), expecting: 2, to: session)
      clock.advance(by: Self.thoughtSeconds)
      try await Self.sendIdleState(to: session)
      harness.render()

      let message = EntryTimingView.accessibilityLabel(
        startedAt: Self.start, duration: Self.messageSeconds, locale: Self.locale)
      let thought = EntryTimingView.accessibilityLabel(
        startedAt: thoughtStart, duration: Self.thoughtSeconds, locale: Self.locale)
      #expect(Self.timingLabel(of: messageKey, in: harness) == message)
      #expect(Self.timingLabel(of: thoughtKey, in: harness) == thought)
    }

    @Test func theTimeDrawsInTheUIRole() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }

      _ = try await Self.send(Self.chunk("agent_message_chunk", messageID: Self.messageID), expecting: 1, to: session)
      let entry = try #require(session.model.transcript.last)

      try FontRoleExpectations.expectText(
        of: EntryTimingView(entry: entry), identifier: EntryTimingView.identifier(for: entry.rowKey), drawsIn: .ui)
    }

    @Test func aToolCallShowsTheTimeFromItsStartToItsCompletion() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = Self.mountThread(session.model, showsTiming: true)
      defer { harness.close() }
      let model = session.model

      try await session.sendToolCallUpdate(title: Self.callTitle, status: .inProgress)
      await ObservationWait.until { !model.transcript.isEmpty }
      let key = try #require(model.transcript.last?.rowKey)
      clock.advance(by: Self.toolCallSeconds)
      try await session.sendToolCallUpdate(title: Self.callTitle, status: .completed)
      await harness.render {
        ToolCallEntryViewHostedTests.toolCallEntry(Self.callTitle, in: model)?.status == .completed
      }

      let expected = EntryTimingView.accessibilityLabel(
        startedAt: Self.start, duration: Self.toolCallSeconds, locale: Self.locale)
      #expect(Self.timingLabel(of: key, in: harness) == expected)
    }

    @Test func aUserMessageShowsOnlyItsStart() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = Self.mountThread(session.model, showsTiming: true)
      defer { harness.close() }

      let key = try await Self.send(
        Self.chunk("user_message_chunk", messageID: Self.userMessageID), expecting: 1, to: session)
      harness.render()

      let expected = EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: nil, locale: Self.locale)
      #expect(Self.timingLabel(of: key, in: harness) == expected)
    }

    @Test func theThoughtTitleTellsTheDurationOfTheThought() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = Self.mountThread(session.model, showsTiming: false)
      defer { harness.close() }

      let key = try await Self.send(
        Self.chunk("agent_thought_chunk", messageID: Self.thoughtID), expecting: 1, to: session)
      clock.advance(by: Self.thoughtSeconds)
      try await Self.sendIdleState(to: session)
      harness.render()

      let title = ReasoningView.completedTitle(duration: Self.thoughtSeconds)
      let identifier = ReasoningView.titleIdentifier(for: key)
      #expect(harness.element(identifier: identifier)?.label == title)
      #expect(
        harness.element(identifier: ReasoningView.identifier(for: key))?.label
          == ReasoningView.accessibilityLabel(isInProgress: false, duration: Self.thoughtSeconds))
    }

    @Test func theTimelineRowOfAThoughtTellsTheDurationOfTheThought() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = HostedViewHarness(size: Self.tallSize) {
        ActivityTimeline(session: session.model)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }

      let key = try await Self.send(
        Self.chunk("agent_thought_chunk", messageID: Self.thoughtID), expecting: 1, to: session)
      clock.advance(by: Self.thoughtSeconds)
      try await Self.sendIdleState(to: session)
      harness.render()

      let title = ReasoningView.completedTitle(duration: Self.thoughtSeconds)
      let identifier = ActivityTimeline.rowIdentifier(for: key)
      #expect(harness.element(identifier: identifier)?.label == title)
    }

    // MARK: - No time

    @Test func withNoDecoratorNoRowShowsATime() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let harness = Self.mountThread(session.model, showsTiming: false)
      defer { harness.close() }

      let key = try await Self.send(
        Self.chunk("agent_message_chunk", messageID: Self.messageID), expecting: 1, to: session)
      harness.render()

      #expect(session.model.transcript.last?.timing.startedAt == Self.start)
      #expect(harness.element(identifier: ItemRow.identifier(for: key)) != nil)
      #expect(harness.element(identifier: EntryTimingView.identifier(for: key)) == nil)
    }

    @Test func aReplayedEntryShowsNoTime() async throws {
      let clock = SettableClock(start: Self.start)
      let replayedChunk = try JSONValue(json: Self.chunk("agent_message_chunk", messageID: Self.messageID))
      let session = try await ScriptedSession.open(
        configure: { agent in
          agent.leadIns[ScriptedSession.resumeMethod] = { _, _ in
            [ScriptedSession.sessionUpdateFrame(update: replayedChunk)]
          }
        },
        now: clock.now)
      defer { session.close() }

      let model = try await session.connection.resumeSession(ScriptedSession.replayFromStartRequest)
      let harness = Self.mountThread(model, showsTiming: true)
      defer { harness.close() }
      await harness.render { !model.transcript.isEmpty }
      let key = try #require(model.transcript.last?.rowKey)

      #expect(model.transcript.last?.timing.startedAt == nil)
      #expect(harness.element(identifier: ItemRow.identifier(for: key)) != nil)
      #expect(harness.element(identifier: EntryTimingView.identifier(for: key)) == nil)
    }

    // MARK: - One view of the host

    @Test func theDecoratorWrapsOneViewOfTheHost() async throws {
      let clock = SettableClock(start: Self.start)
      let session = try await Self.openSession(clock: clock)
      defer { session.close() }
      let model = session.model
      try await session.sendUpdate(Self.chunk("agent_message_chunk", messageID: Self.messageID))
      await ObservationWait.until { !model.transcript.isEmpty }
      let entry = try #require(model.transcript.last)

      let harness = HostedViewHarness(size: Self.tallSize) {
        Text(Self.hostText)
          .entryTiming(entry)
          .environment(\.locale, Self.locale)
      }
      defer { harness.close() }
      harness.render()

      let expected = EntryTimingView.accessibilityLabel(startedAt: Self.start, duration: nil, locale: Self.locale)
      #expect(Self.timingLabel(of: entry.rowKey, in: harness) == expected)
      #expect(harness.hasElement(label: Self.hostText))
    }
  }
#endif
