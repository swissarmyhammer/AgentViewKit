#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The activity timeline over the transcript of a `SessionModel`. The
  /// timeline shows one row for each thought, tool call, terminal and error
  /// entry, in transcript order, with no turn section and no duration.
  @Suite(.serialized, .hostedSerially) @MainActor struct ActivityTimelineHostedTests {
    /// The longest time that a test waits for the view to change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row and an expanded view.
    static let tallSize = CGSize(width: 560, height: 1_400)

    /// The `messageId` of the thought of the tests.
    static let thoughtID = "timeline-thought"

    /// The title, and thus the `toolCallId`, of the first tool call.
    static let firstCall = "Read README.md"

    /// The title, and thus the `toolCallId`, of the second tool call.
    static let secondCall = "Run the tests"

    /// The title, and thus the `toolCallId`, of the tool call that the agent
    /// adds after the mount.
    static let laterCall = "Write the summary"

    /// The `messageId` of the agent message of the message test.
    static let messageID = "timeline-message"

    /// Makes a harness that shows the timeline of `session` with no
    /// animations.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness, after one pump.
    static func mountTimeline(_ session: ScriptedSession) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        ActivityTimeline(session: session.model)
          .transaction { $0.disablesAnimations = true }
      }
      harness.pump()
      return harness
    }

    /// The row keys of the entries that have a row in `harness`, in view
    /// order.
    ///
    /// - Parameters:
    ///   - harness: The harness that shows the timeline.
    ///   - model: The session model.
    /// - Returns: The row keys of the transcript entries that have a row, in
    ///   the order of the rows.
    static func shownRows<Content: View>(in harness: HostedViewHarness<Content>, of model: SessionModel)
      -> [String]
    {
      let keys = model.transcript.map(\.rowKey)
      let identifiers = harness.accessibilityElements().compactMap(\.identifier)
      return identifiers.compactMap { identifier in
        keys.first { ActivityTimeline.rowIdentifier(for: $0) == identifier }
      }
    }

    /// Sends one tool call of the session from the agent, in progress, and
    /// waits until the model holds its entry.
    ///
    /// - Parameters:
    ///   - title: The title, and thus the `toolCallId`, of the call.
    ///   - session: The scripted session.
    ///   - harness: The harness to pump while the test waits.
    /// - Returns: The row key of the tool call entry.
    /// - Throws: The error of the transport, or an issue when the model holds
    ///   no entry of the call at the time limit.
    static func sendCall(
      _ title: String, in session: ScriptedSession, pumping harness: HostedViewHarness<some View>
    ) async throws -> String {
      try await session.sendToolCallUpdate(title: title, status: .inProgress)
      await harness.pump(until: waitTimeout) {
        ToolCallEntryViewHostedTests.rowKey(ofCall: title, in: session.model) != nil
      }
      return try #require(ToolCallEntryViewHostedTests.rowKey(ofCall: title, in: session.model))
    }

    /// Pumps `harness` until it shows the rows of `keys`, in order.
    ///
    /// - Parameters:
    ///   - keys: The row keys of the rows to wait for.
    ///   - harness: The harness that shows the timeline.
    ///   - model: The session model.
    static func waitForRows<Content: View>(
      _ keys: [String], in harness: HostedViewHarness<Content>, of model: SessionModel
    ) async {
      await harness.pump(until: waitTimeout) { shownRows(in: harness, of: model) == keys }
    }

    // MARK: - Rows

    @Test func theRowsShowInTranscriptOrderWithNoDuration() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: "Plan."))
      await harness.pump(until: Self.waitTimeout) { !session.model.transcript.isEmpty }
      let thoughtKey = try #require(session.model.transcript.first?.rowKey)
      let firstKey = try await Self.sendCall(Self.firstCall, in: session, pumping: harness)
      let secondKey = try await Self.sendCall(Self.secondCall, in: session, pumping: harness)
      session.model.appendError(code: .internalError, message: "failed", data: nil)
      let errorKey = try #require(session.model.transcript.last?.rowKey)
      let expected = [thoughtKey, firstKey, secondKey, errorKey]
      await Self.waitForRows(expected, in: harness, of: session.model)

      #expect(session.model.transcript.map(\.rowKey) == expected)
      #expect(Self.shownRows(in: harness, of: session.model) == expected)
      let first = harness.element(identifier: ActivityTimeline.rowIdentifier(for: firstKey))
      #expect(first?.label == Self.firstCall)
      #expect(first?.value == nil || first?.value == "")
    }

    @Test func aToolCallThatTheAgentAddsAddsARow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let firstKey = try await Self.sendCall(Self.firstCall, in: session, pumping: harness)
      await Self.waitForRows([firstKey], in: harness, of: session.model)

      let laterKey = try await Self.sendCall(Self.laterCall, in: session, pumping: harness)
      await Self.waitForRows([firstKey, laterKey], in: harness, of: session.model)

      #expect(Self.shownRows(in: harness, of: session.model) == [firstKey, laterKey])
      #expect(harness.element(identifier: ActivityTimeline.rowIdentifier(for: laterKey))?.label == Self.laterCall)
    }

    @Test func aMessageEntryShowsNoRow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_message_chunk", messageID: Self.messageID, text: "Done."))
      let callKey = try await Self.sendCall(Self.firstCall, in: session, pumping: harness)
      let messageKey = try #require(session.model.transcript.first?.rowKey)
      await Self.waitForRows([callKey], in: harness, of: session.model)

      #expect(messageKey != callKey)
      #expect(harness.element(identifier: ActivityTimeline.rowIdentifier(for: messageKey)) == nil)
      #expect(Self.shownRows(in: harness, of: session.model) == [callKey])
    }

    @Test func anEmptyTranscriptShowsTheEmptyState() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }

      #expect(harness.element(identifier: ActivityTimeline.emptyStateIdentifier) != nil)
    }

    // MARK: - Expand

    @Test func aClickOnAToolCallRowExpandsTheToolCallView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let key = try await Self.sendCall(Self.firstCall, in: session, pumping: harness)
      let rowID = ActivityTimeline.rowIdentifier(for: key)
      let detailID = ActivityTimeline.detailIdentifier(for: key)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: rowID) != nil }
      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) == nil)

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: detailID) != nil }

      #expect(harness.element(identifier: detailID) != nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) != nil)

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: detailID) == nil }

      #expect(harness.element(identifier: detailID) == nil)
    }

    @Test func aTerminalEntryShowsARowThatExpandsTheTerminalView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      try await session.sendUpdate(
        SessionEntryRowsHostedTests.terminalUpdate(#""command": "\#(SessionEntryRowsHostedTests.command)""#))
      await harness.pump(until: Self.waitTimeout) { !session.model.transcript.isEmpty }
      let key = try #require(session.model.transcript.first?.rowKey)
      let rowID = ActivityTimeline.rowIdentifier(for: key)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: rowID) != nil }
      #expect(harness.element(identifier: rowID)?.label == SessionEntryRowsHostedTests.command)

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: TerminalView.commandIdentifier) != nil
      }

      #expect(harness.element(identifier: TerminalView.commandIdentifier) != nil)
    }
  }
#endif
