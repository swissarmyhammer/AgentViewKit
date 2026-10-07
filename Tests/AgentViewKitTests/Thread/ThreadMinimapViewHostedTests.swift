#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The minimap rail over the transcript of a `SessionModel`: one tick for
  /// each entry, in transcript order, tinted by the entry case and the status
  /// of a tool call.
  @Suite(.serialized, .hostedSerially) @MainActor struct ThreadMinimapViewHostedTests {
    /// The number of tool call entries, and of agent message entries, in the
    /// transcripts of the kind tests.
    static let pairCount = 3

    /// The number of entry kinds in the transcripts of the kind tests: agent
    /// messages and tool calls.
    static let kindCount = 2

    /// The number of tool call entries in the transcripts of the rail tests.
    static let entryCount = 20

    /// The number of tool call entries in the transcript of the click test.
    /// Together, the rows of these entries are much taller than the window,
    /// so the first row is not in view at the bottom.
    static let clickEntryCount = 60

    /// The smallest number of entries that shows the rail in these tests.
    static let minimumEntryCount = 1

    /// The position of the first visible entry in the value test.
    static let firstVisiblePosition = 4

    /// The number of entries that the value test shows.
    static let visibleEntryCount = 6

    /// The distance from the trailing edge of the window to the point that
    /// the click test clicks, in points. The rail is at the trailing edge.
    static let railInset: CGFloat = 4

    /// A width that is less than the smallest width of the test modifier.
    static let narrowWidth: CGFloat = 300

    /// The smallest width of the conversation in the width tests.
    static let minimumWidth: CGFloat = 400

    /// The longest time that a test waits for a view change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// The `messageId` start of the agent messages of the kind test.
    static let messagePrefix = "minimap-message-"

    /// The title start, and thus the `toolCallId` start, of the tool calls.
    static let callPrefix = "minimap-call-"

    /// The accessibility identifiers of the tick elements, in order.
    ///
    /// - Parameter harness: The harness that shows the rail.
    /// - Returns: The identifiers that start with the tick prefix.
    static func tickIdentifiers<Content: View>(in harness: HostedViewHarness<Content>) -> [String] {
      harness.accessibilityElements().compactMap(\.identifier).filter {
        $0.hasPrefix(ThreadMinimapView.tickIdentifierPrefix)
      }
    }

    /// Sends a mouse-down and a mouse-up event at `point` to the window of
    /// `harness`, then pumps the run loop.
    ///
    /// - Parameters:
    ///   - point: The point in the coordinates of the window.
    ///   - harness: The harness that gets the click.
    static func click<Content: View>(at point: NSPoint, in harness: HostedViewHarness<Content>) {
      for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
        let event = NSEvent.mouseEvent(
          with: type,
          location: point,
          modifierFlags: [],
          timestamp: ProcessInfo.processInfo.systemUptime,
          windowNumber: harness.window.windowNumber,
          context: nil,
          eventNumber: 0,
          clickCount: 1,
          pressure: 1
        )
        if let event {
          harness.window.sendEvent(event)
        }
      }
      harness.pump()
    }

    /// Sends `count` tool calls of the session from the agent, in progress,
    /// and waits until the model holds `total` entries.
    ///
    /// - Parameters:
    ///   - count: The number of tool calls to send.
    ///   - total: The number of transcript entries to wait for.
    ///   - session: The scripted session.
    /// - Throws: The error of the transport.
    static func sendCalls(_ count: Int, untilTotal total: Int, in session: ScriptedSession) async throws {
      for index in 0..<count {
        try await session.sendToolCallUpdate(title: "\(callPrefix)\(index)", status: .inProgress)
      }
      _ = await waitUntil { session.model.transcript.count == total }
    }

    /// Opens a session whose transcript holds `count` tool calls.
    ///
    /// - Parameter count: The number of tool calls.
    /// - Returns: The scripted session.
    /// - Throws: The error of the transport.
    static func openSessionWithCalls(count: Int = entryCount) async throws -> ScriptedSession {
      let session = try await ScriptedSession.open()
      try await sendCalls(count, untilTotal: count, in: session)
      return session
    }

    /// Makes a harness that shows the rail of `session`.
    ///
    /// - Parameters:
    ///   - session: The scripted session.
    ///   - anchors: The manager of the rail.
    /// - Returns: The harness, after one pump.
    static func mountRail(_ session: ScriptedSession, anchors: ScrollAnchorManager) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(
        ThreadMinimapView(session: session.model, anchors: anchors, minimumItemCount: minimumEntryCount))
      harness.pump()
      return harness
    }

    // MARK: - Ticks

    @Test func eachEntryHasOneTickOfItsKind() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      for index in 0..<Self.pairCount {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "agent_message_chunk", messageID: "\(Self.messagePrefix)\(index)", text: "Done."))
      }
      try await Self.sendCalls(Self.pairCount, untilTotal: Self.pairCount * Self.kindCount, in: session)
      let harness = Self.mountRail(session, anchors: ScrollAnchorManager())
      defer { harness.close() }
      let total = session.model.transcript.count
      await harness.pump(until: Self.waitTimeout) { Self.tickIdentifiers(in: harness).count == total }

      let ticks = Self.tickIdentifiers(in: harness)
      #expect(ticks.count == Self.pairCount * Self.kindCount)
      let expected = Dictionary(
        session.model.transcript.map { (ThreadMinimapView.tickIdentifier(for: $0), 1) }, uniquingKeysWith: +)
      let actual = Dictionary(ticks.map { ($0, 1) }, uniquingKeysWith: +)
      #expect(actual == expected)
      #expect(actual[ThreadMinimapView.tickIdentifierPrefix + "agent-message"] == Self.pairCount)
      #expect(actual[ThreadMinimapView.tickIdentifierPrefix + "tool-call"] == Self.pairCount)
    }

    @Test func aToolCallThatTheAgentAddsAddsATick() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      try await Self.sendCalls(Self.minimumEntryCount, untilTotal: Self.minimumEntryCount, in: session)
      let harness = Self.mountRail(session, anchors: ScrollAnchorManager())
      defer { harness.close() }
      await harness.pump(until: Self.waitTimeout) {
        Self.tickIdentifiers(in: harness).count == Self.minimumEntryCount
      }

      try await session.sendToolCallUpdate(title: ActivityTimelineHostedTests.laterCall, status: .inProgress)
      let total = Self.minimumEntryCount + 1
      await harness.pump(until: Self.waitTimeout) { Self.tickIdentifiers(in: harness).count == total }

      #expect(Self.tickIdentifiers(in: harness).count == total)
    }

    @Test func aStatusUpdateChangesTheTintOfTheTick() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let title = ActivityTimelineHostedTests.firstCall
      try await session.sendToolCallUpdate(title: title, status: .inProgress)
      _ = await waitUntil { !session.model.transcript.isEmpty }
      let entry = try #require(session.model.transcript.first)
      let tickID = ThreadMinimapView.tickIdentifier(for: entry)
      let harness = Self.mountRail(session, anchors: ScrollAnchorManager())
      defer { harness.close() }
      let running = FoundationModelsACP.ToolCallStatus.inProgress.wireValue
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: tickID)?.value == running }
      #expect(harness.element(identifier: tickID)?.value == running)

      try await session.sendToolCallUpdate(title: title, status: .completed)
      let completed = FoundationModelsACP.ToolCallStatus.completed.wireValue
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: tickID)?.value == completed }

      #expect(harness.element(identifier: tickID)?.value == completed)
    }

    // MARK: - Scroll

    @Test func aClickOnATickScrollsTheConversationToTheRowOfTheEntry() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      for index in 0..<Self.clickEntryCount {
        try await session.sendUpdate(
          SessionTranscriptViewHostedTests.chunk(
            "agent_message_chunk", messageID: "\(Self.messagePrefix)\(index)", text: "Done."))
      }
      _ = await waitUntil { session.model.transcript.count == Self.clickEntryCount }
      let anchors = ScrollAnchorManager()
      let harness = HostedViewHarness(
        ConversationView(session: session.model, anchors: anchors)
          .threadMinimap(
            session: session.model, anchors: anchors, minimumItemCount: Self.minimumEntryCount,
            minimumWidth: Self.minimumWidth))
      defer { harness.close() }
      harness.pump()
      let keys = session.model.transcript.map(\.rowKey)
      let firstKey = try #require(keys.first)
      await harness.pump(until: Self.waitTimeout) {
        anchors.visibleIDs.last == keys.last
      }
      #expect(!anchors.visibleIDs.contains(firstKey))

      // The top tick is the tick of the first entry.
      let bounds = harness.hostingView.bounds
      let top = harness.hostingView.isFlipped ? bounds.minY + Self.railInset : bounds.maxY - Self.railInset
      let point = NSPoint(x: bounds.maxX - Self.railInset, y: top)
      Self.click(at: harness.hostingView.convert(point, to: nil), in: harness)
      await harness.pump(until: Self.waitTimeout) { anchors.visibleIDs.contains(firstKey) }

      #expect(anchors.anchorID == firstKey)
      #expect(anchors.visibleIDs.contains(firstKey))
    }

    @Test func theValueTellsTheFirstVisibleEntry() async throws {
      let session = try await Self.openSessionWithCalls()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let keys = session.model.transcript.map(\.rowKey)
      anchors.noteVisible(
        ids: Array(keys[Self.firstVisiblePosition..<(Self.firstVisiblePosition + Self.visibleEntryCount)]))
      let harness = Self.mountRail(session, anchors: anchors)
      defer { harness.close() }

      let expected = "Item \(Self.firstVisiblePosition + 1) of \(Self.entryCount)"
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ThreadMinimapView.railIdentifier)?.value == expected
      }
      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier)?.value == expected)
    }

    @Test func theIncrementActionAnchorsTheNextEntry() async throws {
      let session = try await Self.openSessionWithCalls()
      defer { session.close() }
      let anchors = ScrollAnchorManager()
      let keys = session.model.transcript.map(\.rowKey)
      anchors.noteVisible(ids: [keys[Self.firstVisiblePosition]])
      let harness = Self.mountRail(session, anchors: anchors)
      defer { harness.close() }

      try harness.increment(identifier: ThreadMinimapView.railIdentifier)
      await harness.pump(until: Self.waitTimeout) { anchors.anchorID != nil }

      #expect(anchors.anchorID == keys[Self.firstVisiblePosition + 1])
    }

    // MARK: - Visibility

    @Test func aTranscriptBelowTheEntryCountShowsNoRail() async throws {
      let session = try await Self.openSessionWithCalls()
      defer { session.close() }
      let view = ThreadMinimapView(
        session: session.model, anchors: ScrollAnchorManager(), minimumItemCount: Self.entryCount + 1)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) == nil)
      #expect(Self.tickIdentifiers(in: harness).isEmpty)
    }

    @Test func aNarrowConversationShowsNoRail() async throws {
      let session = try await Self.openSessionWithCalls()
      defer { session.close() }
      let view = Color.clear
        .threadMinimap(session: session.model, anchors: ScrollAnchorManager(), minimumWidth: Self.minimumWidth)
      let harness = HostedViewHarness(
        view,
        size: CGSize(width: Self.narrowWidth, height: HostedViewHarness<Color>.defaultSize.height))
      defer { harness.close() }
      harness.pump()

      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) == nil)
    }

    @Test func aWideConversationShowsTheRail() async throws {
      let session = try await Self.openSessionWithCalls()
      defer { session.close() }
      let view = Color.clear
        .threadMinimap(session: session.model, anchors: ScrollAnchorManager(), minimumWidth: Self.minimumWidth)
      let harness = HostedViewHarness(view)
      defer { harness.close() }
      harness.pump()

      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ThreadMinimapView.railIdentifier) != nil
      }
      #expect(harness.element(identifier: ThreadMinimapView.railIdentifier) != nil)
    }
  }
#endif
