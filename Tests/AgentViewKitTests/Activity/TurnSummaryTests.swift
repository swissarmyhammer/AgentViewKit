import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import Testing

@Suite @MainActor struct TurnSummaryTests {
  /// The start of the first sample turn.
  static let start = ThreadFixtures.startTime

  /// Makes a tool call that runs from `start` plus `from` seconds to `start`
  /// plus `to` seconds.
  ///
  /// - Parameters:
  ///   - id: The identifier of the call.
  ///   - from: The start, in seconds after ``start``, or `nil` for no start.
  ///   - to: The end, in seconds after ``start``, or `nil` for no end.
  ///   - status: The progress of the call.
  ///   - content: The output of the call.
  /// - Returns: The tool call item.
  static func call(
    _ id: String, from: TimeInterval?, to: TimeInterval?,
    status: ToolCallStatus = .completed, content: [ToolContent] = []
  ) -> ThreadItem {
    .toolCall(
      ToolCallRecord(
        id: id, title: id, status: status, content: content,
        startedAt: from.map { start.addingTimeInterval($0) },
        endedAt: to.map { start.addingTimeInterval($0) }))
  }

  /// Makes a user message item.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The item.
  static func user(_ id: String) -> ThreadItem {
    .userMessage(ThreadFixtures.message(id: id))
  }

  /// Makes an assistant message item.
  ///
  /// - Parameter id: The identifier of the message.
  /// - Returns: The item.
  static func assistant(_ id: String) -> ThreadItem {
    .assistantMessage(ThreadFixtures.message(id: id))
  }

  // MARK: - Grouping

  @Test func aUserMessageStartsATurn() {
    let items = [
      Self.user("u1"), Self.call("c1", from: 0, to: 1), Self.assistant("a1"),
      Self.user("u2"), Self.assistant("a2"),
    ]

    let turns = TurnSummary.compute(items: items)

    #expect(turns.map(\.id) == ["u1", "u2"])
    #expect(turns.map(\.itemIDs) == [["u1", "c1", "a1"], ["u2", "a2"]])
  }

  @Test func itemsBeforeTheFirstUserMessageAreATurn() {
    let items = [Self.assistant("a0"), Self.user("u1"), Self.assistant("a1")]

    let turns = TurnSummary.compute(items: items)

    #expect(turns.map(\.id) == ["a0", "u1"])
  }

  @Test func noItemsGiveNoTurns() {
    #expect(TurnSummary.compute(items: []).isEmpty)
  }

  @Test func theAnchorIsTheFirstAgentItemOfEachTurn() {
    let items = [
      Self.user("u1"), Self.call("c1", from: 0, to: 1), Self.assistant("a1"),
      Self.user("u2"), Self.user("u3"), Self.assistant("a3"),
    ]

    let anchors = TurnSummary.anchors(in: items)

    #expect(anchors == ["c1": "u1", "a3": "u3"])
  }

  // MARK: - Sums

  @Test func twoCallsOfOneAndTwoSecondsReportThreeSecondsAndTwoTools() throws {
    let items = [Self.user("u1"), Self.call("c1", from: 0, to: 1), Self.call("c2", from: 1, to: 3)]

    let turn = try #require(TurnSummary.compute(items: items).first)

    #expect(turn.duration == 3)
    #expect(turn.toolCount == 2)
    #expect(turn.count(of: .completed) == 2)
    #expect(turn.hasWork)
    #expect(turn.text == "Worked 3 s, 2 tools")
  }

  @Test func theDurationRunsFromTheFirstStartToTheLastEnd() throws {
    let reasoning = Reasoning(
      id: "r1", segments: ["Hmm."], startedAt: Self.start,
      endedAt: Self.start.addingTimeInterval(1))
    let items = [
      Self.user("u1"), .reasoning(reasoning), Self.call("c1", from: 2, to: 5),
      Self.call("c2", from: 3, to: 4),
    ]

    let turn = try #require(TurnSummary.compute(items: items).first)

    #expect(turn.startedAt == Self.start)
    #expect(turn.endedAt == Self.start.addingTimeInterval(5))
    #expect(turn.duration == 5)
  }

  @Test func theToolCountsAreByStatus() throws {
    let items = [
      Self.call("c1", from: nil, to: nil, status: .completed),
      Self.call("c2", from: nil, to: nil, status: .failed),
      Self.call("c3", from: nil, to: nil, status: .failed),
      Self.call("c4", from: nil, to: nil, status: .inProgress),
    ]

    let turn = try #require(TurnSummary.compute(items: items).first)

    #expect(turn.toolCount == 4)
    #expect(turn.count(of: .completed) == 1)
    #expect(turn.count(of: .failed) == 2)
    #expect(turn.count(of: .inProgress) == 1)
    #expect(turn.count(of: .cancelled) == 0)
  }

  @Test func theDiffStatIsTheSumOfTheDiffs() throws {
    let first = """
      --- a/one.swift
      +++ b/one.swift
      @@ -1,2 +1,3 @@
       let a = 1
      -let b = 2
      +let b = 3
      +let c = 4
      """
    let second = """
      @@ -1 +1 @@
      ---removed dashes
      +++added pluses
      """
    let items = [
      Self.user("u1"),
      Self.call("c1", from: nil, to: nil, content: [.diff(patch: first)]),
      Self.call("c2", from: nil, to: nil, content: [.diff(patch: second), .terminal(id: "t1")]),
    ]

    let turn = try #require(TurnSummary.compute(items: items).first)

    #expect(turn.diffStat == DiffStat(added: 3, removed: 2))
    #expect(turn.text == "Worked, 2 tools, +3 \u{2212}2")
  }

  @Test func aPatchWithNoHunkHeaderCountsEachChangedLine() {
    let patch = "--- a/x\n+++ b/x\n+one\n+two\n-three\n context"

    #expect(DiffStat.count(patch: patch) == DiffStat(added: 2, removed: 1))
  }

  @Test func missingTimesGiveNoDuration() throws {
    let items = [Self.user("u1"), Self.call("c1", from: 0, to: nil, status: .inProgress)]

    let turn = try #require(TurnSummary.compute(items: items).first)

    #expect(turn.duration == nil)
    #expect(turn.text == "Worked, 1 tool")
  }

  @Test func aTurnWithNoToolsAndNoTimesHasNoWork() throws {
    let turn = try #require(
      TurnSummary.compute(items: [Self.user("u1"), Self.assistant("a1")]).first)

    #expect(!turn.hasWork)
    #expect(turn.diffStat.isEmpty)
    #expect(turn.text == "Worked")
  }

  @Test func theDurationTextRoundsToWholeSeconds() {
    #expect(TurnSummary.text(duration: 2.6, toolCount: 0, diffStat: DiffStat()) == "Worked 3 s")
    #expect(
      TurnSummary.text(duration: nil, toolCount: 1, diffStat: DiffStat(added: 1, removed: 0))
        == "Worked, 1 tool, +1 \u{2212}0")
  }

  // MARK: - Timeline entries

  @Test func entriesWithTimesAreInTimeOrder() {
    let reasoning = Reasoning(
      id: "r1", segments: ["Hmm."], startedAt: Self.start.addingTimeInterval(2),
      endedAt: Self.start.addingTimeInterval(3))
    let items = [
      Self.user("u1"), Self.call("c1", from: 4, to: 5), .reasoning(reasoning),
      Self.call("c2", from: 0, to: 1, content: [.terminal(id: "t1")]), Self.assistant("a1"),
    ]

    let entries = ActivityEntry.entries(in: items)

    let terminalEntryID = ActivityEntry.terminalEntryID(callID: "c2", terminalID: "t1")
    #expect(entries.map(\.id) == ["c2", terminalEntryID, "r1", "c1"])
    #expect(entries[1].kind == .terminal(id: "t1"))
    #expect(entries[1].itemID == "c2")
  }

  @Test func entriesWithMissingTimesKeepTheThreadOrder() {
    let error = ThreadError(id: "e1", kind: .timeout)
    let items = [
      Self.call("c1", from: 4, to: 5), .error(error), Self.call("c2", from: 0, to: 1),
    ]

    let entries = ActivityEntry.entries(in: items)

    #expect(entries.map(\.id) == ["c1", "e1", "c2"])
    #expect(entries[1].kind == .error)
    #expect(entries[1].startedAt == nil)
  }

  @Test func theBarIsThePartOfTheSpan() throws {
    let span = Self.start...Self.start.addingTimeInterval(4)

    let bar = try #require(
      ActivityEntry.barRange(
        start: Self.start.addingTimeInterval(1), end: Self.start.addingTimeInterval(3), span: span))

    #expect(bar == 0.25...0.75)
    #expect(ActivityEntry.barRange(start: nil, end: Self.start, span: span) == nil)
    #expect(ActivityEntry.barRange(start: Self.start, end: nil, span: span) == nil)
  }

  @Test func aBarInAnEmptySpanStartsAtZero() {
    let span = Self.start...Self.start

    #expect(ActivityEntry.barRange(start: Self.start, end: Self.start, span: span) == 0...0)
  }
}
