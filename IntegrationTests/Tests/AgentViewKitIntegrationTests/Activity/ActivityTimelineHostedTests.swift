#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import EditorTestSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The activity timeline over the transcript of a `SessionModel`. The
  /// timeline shows one row for each thought, tool call, terminal and error
  /// entry, in transcript order, with no turn section. A thought that did not
  /// end shows no duration.
  ///
  /// A test waits for the session model to hold the entry of each update
  /// that the agent sends, and then makes one render pass before it reads the
  /// timeline. A press of a row renders the view itself.
  @Suite(.serialized, .hostedSerially) @MainActor struct ActivityTimelineHostedTests {
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
    /// - Returns: The harness, after one render pass.
    static func mountTimeline(_ session: ScriptedSession) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        ActivityTimeline(session: session.model)
          .transaction { $0.disablesAnimations = true }
      }
      harness.render()
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

    /// Sends one tool call of the session from the agent, in progress, waits
    /// until the model holds its entry, and then renders `harness`.
    ///
    /// - Parameters:
    ///   - title: The title, and thus the `toolCallId`, of the call.
    ///   - session: The scripted session.
    ///   - harness: The harness that renders the timeline after the wait.
    /// - Returns: The row key of the tool call entry.
    /// - Throws: The error of the transport.
    static func sendCall(
      _ title: String, in session: ScriptedSession, rendering harness: HostedViewHarness<some View>
    ) async throws -> String {
      try await session.sendToolCallUpdate(title: title, status: .inProgress)
      let model = session.model
      await harness.render { ToolCallEntryViewHostedTests.rowKey(ofCall: title, in: model) != nil }
      return try #require(ToolCallEntryViewHostedTests.rowKey(ofCall: title, in: model))
    }

    // MARK: - Rows

    @Test func theRowsShowInTranscriptOrderWithNoDuration() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let model = session.model

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_thought_chunk", messageID: Self.thoughtID, text: "Plan."))
      await ObservationWait.until { !model.transcript.isEmpty }
      let thoughtKey = try #require(model.transcript.first?.rowKey)
      let firstKey = try await Self.sendCall(Self.firstCall, in: session, rendering: harness)
      let secondKey = try await Self.sendCall(Self.secondCall, in: session, rendering: harness)
      model.appendError(code: .internalError, message: "failed", data: nil)
      let errorKey = try #require(model.transcript.last?.rowKey)
      let expected = [thoughtKey, firstKey, secondKey, errorKey]
      harness.render()

      #expect(model.transcript.map(\.rowKey) == expected)
      #expect(Self.shownRows(in: harness, of: model) == expected)
      let first = harness.element(identifier: ActivityTimeline.rowIdentifier(for: firstKey))
      #expect(first?.label == ToolCallView.accessibilityLabel(title: Self.firstCall, status: .inProgress))
      #expect(first?.value == nil || first?.value == "")
    }

    @Test func theLabelOfAToolCallRowTellsTheStatus() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let model = session.model
      let key = try await Self.sendCall(Self.firstCall, in: session, rendering: harness)
      let rowID = ActivityTimeline.rowIdentifier(for: key)
      #expect(harness.element(identifier: rowID)?.label == "\(Self.firstCall), In progress")

      try await session.sendToolCallUpdate(title: Self.firstCall, status: .failed)
      await harness.render { BackgroundRunsHostedTests.toolCall(id: Self.firstCall, in: model)?.status == .failed }

      #expect(harness.element(identifier: rowID)?.label == "\(Self.firstCall), Failed")
    }

    @Test func aToolCallThatTheAgentAddsAddsARow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let firstKey = try await Self.sendCall(Self.firstCall, in: session, rendering: harness)
      #expect(Self.shownRows(in: harness, of: session.model) == [firstKey])

      let laterKey = try await Self.sendCall(Self.laterCall, in: session, rendering: harness)

      #expect(Self.shownRows(in: harness, of: session.model) == [firstKey, laterKey])
      #expect(
        harness.element(identifier: ActivityTimeline.rowIdentifier(for: laterKey))?.label
          == ToolCallView.accessibilityLabel(title: Self.laterCall, status: .inProgress))
    }

    /// The agent sends the message before the tool call, and the frames go
    /// over the transport in order. Thus the model holds the message entry
    /// when it holds the entry of the call.
    @Test func aMessageEntryShowsNoRow() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }

      try await session.sendUpdate(
        SessionTranscriptViewHostedTests.chunk("agent_message_chunk", messageID: Self.messageID, text: "Done."))
      let callKey = try await Self.sendCall(Self.firstCall, in: session, rendering: harness)
      let messageKey = try #require(session.model.transcript.first?.rowKey)

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
      let key = try await Self.sendCall(Self.firstCall, in: session, rendering: harness)
      let rowID = ActivityTimeline.rowIdentifier(for: key)
      let detailID = ActivityTimeline.detailIdentifier(for: key)
      #expect(harness.element(identifier: rowID) != nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) == nil)

      try harness.press(identifier: rowID)

      #expect(harness.element(identifier: detailID) != nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: key)) != nil)

      try harness.press(identifier: rowID)

      #expect(harness.element(identifier: detailID) == nil)
    }

    @Test func aTerminalEntryShowsARowThatExpandsTheTerminalView() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mountTimeline(session)
      defer { harness.close() }
      let model = session.model
      try await session.sendUpdate(
        SessionEntryRowsHostedTests.terminalUpdate(#""command": "\#(SessionEntryRowsHostedTests.command)""#))
      await harness.render { !model.transcript.isEmpty }
      let key = try #require(model.transcript.first?.rowKey)
      let rowID = ActivityTimeline.rowIdentifier(for: key)
      #expect(harness.element(identifier: rowID)?.label == SessionEntryRowsHostedTests.command)

      try harness.press(identifier: rowID)

      #expect(harness.element(identifier: TerminalView.commandIdentifier) != nil)
    }
  }
#endif
