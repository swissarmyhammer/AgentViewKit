#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import Foundation
  import SwiftUI
  import Testing

  @Suite(.serialized, .hostedSerially) @MainActor struct ActivityTimelineHostedTests {
    /// The longest time that a test waits for the view to change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// A size that shows each row and an expanded view.
    static let tallSize = CGSize(width: 560, height: 1_400)

    /// The start of the sample turn.
    static let start = ThreadFixtures.startTime

    /// The id of the terminal of the terminal test.
    static let terminalID = "timeline-terminal"

    /// Makes a tool call record that runs from `start` plus `from` seconds to
    /// `start` plus `to` seconds.
    ///
    /// - Parameters:
    ///   - id: The identifier of the call.
    ///   - from: The start, in seconds after ``start``, or `nil` for no start.
    ///   - to: The end, in seconds after ``start``, or `nil` for no end.
    ///   - content: The output of the call.
    /// - Returns: The record.
    static func call(
      _ id: String, from: TimeInterval?, to: TimeInterval?, content: [ToolContent] = []
    ) -> ToolCallRecord {
      ToolCallRecord(
        id: id, title: "Run \(id)", kind: .execute, status: .completed, content: content,
        startedAt: from.map { start.addingTimeInterval($0) },
        endedAt: to.map { start.addingTimeInterval($0) })
    }

    /// Makes a thread from `items`, in order.
    ///
    /// - Parameter items: The items of the thread.
    /// - Returns: The thread.
    static func makeThread(_ items: [ThreadItem]) -> AgentThread {
      let thread = AgentThread()
      for item in items {
        thread.apply(.insert(item, after: nil))
      }
      return thread
    }

    /// Makes a harness that shows the timeline of `thread` with no
    /// animations.
    ///
    /// - Parameter thread: The thread to show.
    /// - Returns: The harness, after one pump.
    static func mountTimeline(_ thread: AgentThread) -> HostedViewHarness<some View> {
      let harness = HostedViewHarness(size: tallSize) {
        ActivityTimeline(thread: thread)
          .transaction { $0.disablesAnimations = true }
      }
      harness.pump()
      return harness
    }

    /// The ids of the entry rows that the harness shows, in view order.
    ///
    /// - Parameters:
    ///   - harness: The harness.
    ///   - ids: The entry ids to find.
    /// - Returns: The ids of `ids` that have a row, in the order of the rows.
    static func shownEntries<Content: View>(
      in harness: HostedViewHarness<Content>, of ids: [String]
    ) -> [String] {
      let identifiers = harness.accessibilityElements().compactMap(\.identifier)
      return identifiers.compactMap { identifier in
        ids.first { ActivityEntry.identifier(for: $0) == identifier }
      }
    }

    // MARK: - Rows

    @Test func timedRowsShowInTimeOrderWithTheirDurations() {
      let harness = Self.mountTimeline(
        Self.makeThread([
          .userMessage(ThreadFixtures.message(id: "u1")),
          .toolCall(Self.call("late", from: 1, to: 3)),
          .toolCall(Self.call("early", from: 0, to: 1)),
        ]))
      defer { harness.close() }

      #expect(harness.element(identifier: ActivityTimeline.identifier) != nil)
      let summary = harness.element(identifier: TurnSummaryRow.identifier(for: "u1"))
      #expect(summary?.label == "Worked 3 s, 2 tools")
      #expect(Self.shownEntries(in: harness, of: ["late", "early"]) == ["early", "late"])
      let late = harness.element(identifier: ActivityEntry.identifier(for: "late"))
      #expect(late?.label == "Run late")
      #expect(late?.value == "2.0 s")
    }

    @Test func rowsWithoutTimesShowInOrderWithNoDuration() {
      let harness = Self.mountTimeline(
        Self.makeThread([
          .toolCall(Self.call("first", from: nil, to: nil)),
          .error(ThreadError(id: "oops", kind: .timeout)),
          .toolCall(Self.call("second", from: 0, to: 1)),
        ]))
      defer { harness.close() }

      let order = ["first", "oops", "second"]
      #expect(Self.shownEntries(in: harness, of: order) == order)
      let first = harness.element(identifier: ActivityEntry.identifier(for: "first"))
      #expect(first != nil)
      #expect(first?.value == nil || first?.value == "")
      // Only the second call has times, so the turn lasts one second.
      let summary = harness.element(identifier: TurnSummaryRow.identifier(for: "first"))
      #expect(summary?.label == "Worked 1 s, 2 tools")
    }

    @Test func anEmptyThreadShowsTheEmptyState() {
      let harness = Self.mountTimeline(AgentThread())
      defer { harness.close() }

      #expect(harness.element(identifier: ActivityTimeline.emptyStateIdentifier) != nil)
    }

    // MARK: - Expand

    @Test func aClickOnABarExpandsTheToolCallView() async throws {
      let harness = Self.mountTimeline(
        Self.makeThread([.toolCall(Self.call("tool", from: 0, to: 2))]))
      defer { harness.close() }
      let rowID = ActivityEntry.identifier(for: "tool")
      let detailID = ActivityEntry.detailIdentifier(for: "tool")
      #expect(harness.element(identifier: ToolCallView.identifier(for: "tool")) == nil)

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: detailID) != nil }

      #expect(harness.element(identifier: detailID) != nil)
      #expect(harness.element(identifier: ToolCallView.identifier(for: "tool")) != nil)

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: detailID) == nil }

      #expect(harness.element(identifier: detailID) == nil)
    }

    @Test func aClickOnAReasoningRowExpandsTheReasoningView() async throws {
      let reasoning = Reasoning(
        id: "think", segments: ["Plan the work."], startedAt: Self.start,
        endedAt: Self.start.addingTimeInterval(4))
      let harness = Self.mountTimeline(Self.makeThread([.reasoning(reasoning)]))
      defer { harness.close() }
      let reasoningID = ReasoningView.identifier(for: "think")

      try harness.press(identifier: ActivityEntry.identifier(for: "think"))
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: reasoningID) != nil }

      #expect(harness.element(identifier: reasoningID) != nil)
      let title = harness.element(identifier: ReasoningView.titleIdentifier(for: "think"))
      #expect(title?.label == "Thought for 4 s")
    }

    @Test func aClickOnATerminalRowExpandsTheTerminalView() async throws {
      let thread = AgentThread()
      thread.apply(
        .upsertTerminal(TerminalPatch(id: TerminalID(Self.terminalID), command: .value("make"))))
      thread.apply(
        .insert(
          .toolCall(Self.call("build", from: 0, to: 1, content: [.terminal(id: Self.terminalID)])),
          after: nil))
      let harness = Self.mountTimeline(thread)
      defer { harness.close() }
      let entryID = ActivityEntry.terminalEntryID(callID: "build", terminalID: Self.terminalID)
      let rowID = ActivityEntry.identifier(for: entryID)
      #expect(harness.element(identifier: rowID)?.label == "make")

      try harness.press(identifier: rowID)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: TerminalView.identifier) != nil
      }

      #expect(harness.element(identifier: TerminalView.identifier) != nil)
    }

    @Test func onlyTheLastTurnIsOpenAndAPressOpensAnother() async throws {
      let harness = Self.mountTimeline(
        Self.makeThread([
          .userMessage(ThreadFixtures.message(id: "u1")),
          .toolCall(Self.call("old", from: 0, to: 1)),
          .userMessage(ThreadFixtures.message(id: "u2")),
          .toolCall(Self.call("new", from: 2, to: 3)),
        ]))
      defer { harness.close() }
      let oldRow = ActivityEntry.identifier(for: "old")
      let toggleID = ActivityTimeline.turnToggleIdentifier(for: "u1")
      #expect(harness.element(identifier: oldRow) == nil)
      #expect(harness.element(identifier: ActivityEntry.identifier(for: "new")) != nil)
      #expect(harness.element(identifier: toggleID)?.value == "Collapsed")

      try harness.press(identifier: toggleID)
      await harness.pump(until: Self.waitTimeout) { harness.element(identifier: oldRow) != nil }

      #expect(harness.element(identifier: oldRow) != nil)
      #expect(harness.element(identifier: toggleID)?.value == "Expanded")
      #expect(harness.element(identifier: ActivityTimeline.turnIdentifier(for: "u1")) != nil)
    }

    @Test func aStatusPatchUpdatesTheSummary() async {
      let call = ToolCallRecord(id: "live", title: "Live", status: .inProgress, startedAt: Self.start)
      let thread = Self.makeThread([.userMessage(ThreadFixtures.message(id: "u1")), .toolCall(call)])
      let harness = Self.mountTimeline(thread)
      defer { harness.close() }
      let summaryID = TurnSummaryRow.identifier(for: "u1")
      #expect(harness.element(identifier: summaryID)?.label == "Worked, 1 tool")

      // A source stamps the host time on the record, then patches the status.
      call.endedAt = Self.start.addingTimeInterval(5)
      thread.apply(.patch(id: "live", .toolCall(status: .value(.completed))))
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: summaryID)?.label == "Worked 5 s, 1 tool"
      }

      #expect(harness.element(identifier: summaryID)?.label == "Worked 5 s, 1 tool")
    }

    // MARK: - Thread

    @Test func theThreadShowsTheSummaryAboveATurnWithWork() {
      let thread = Self.makeThread([
        .userMessage(ThreadFixtures.message(id: "u1")),
        .toolCall(Self.call("work", from: 0, to: 2)),
        .assistantMessage(ThreadFixtures.message(id: "a1")),
        .userMessage(ThreadFixtures.message(id: "u2")),
        .assistantMessage(ThreadFixtures.message(id: "a2")),
      ])
      let harness = HostedViewHarness(size: Self.tallSize) {
        AgentThreadView(thread: thread, actions: NoopThreadActions())
      }
      defer { harness.close() }
      harness.pump()

      let summaryID = TurnSummaryRow.identifier(for: "u1")
      let identifiers = harness.accessibilityElements().compactMap(\.identifier)
      let summary = identifiers.firstIndex(of: summaryID)
      let work = identifiers.firstIndex(of: ItemRow.identifier(for: "work"))
      #expect(summary != nil)
      #expect(work != nil)
      if let summary, let work {
        #expect(summary < work)
      }
      #expect(harness.element(identifier: summaryID)?.label == "Worked 2 s, 1 tool")
      #expect(harness.element(identifier: TurnSummaryRow.identifier(for: "u2")) == nil)
      #expect(harness.element(identifier: ItemRow.identifier(for: "a2")) != nil)
    }
  }
#endif
