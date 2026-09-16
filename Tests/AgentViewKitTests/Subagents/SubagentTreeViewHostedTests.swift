import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct SubagentTreeViewHostedTests {
  /// The size of a tree that shows each row.
  static let treeSize = CGSize(width: 480, height: 640)

  /// The time that a test waits for a host closure, in seconds.
  static let callWaitSeconds: TimeInterval = 1

  /// A tree with three levels and a second root, in the order that a source
  /// sends them: the grandchild comes before its parent.
  ///
  /// - Parameter prefix: The start of each run id, so that the counter keys of
  ///   the tests are different.
  /// - Returns: The runs.
  static func threeLevelRuns(prefix: String) -> [SubagentRun] {
    let root = SubagentRun(id: SubagentRunID(prefix + "root"), title: "Plan the change")
    let grandchild = SubagentRun(
      id: SubagentRunID(prefix + "grandchild"), parentID: SubagentRunID(prefix + "child"),
      title: "Read one file", state: .needsInput, threadID: "session-3")
    let child = SubagentRun(
      id: SubagentRunID(prefix + "child"), parentID: root.id, title: "Find the call sites",
      state: .done, threadID: "session-2")
    let second = SubagentRun(
      id: SubagentRunID(prefix + "second"), title: "Run the tests", state: .failed)
    return [root, grandchild, child, second]
  }

  @Test func aThreeLevelTreeMountsRowsWithTheirLevel() {
    let runs = Self.threeLevelRuns(prefix: "levels-")
    let harness = HostedViewHarness(SubagentTreeView(runs: runs), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let expected: [(String, Int)] = [
      ("levels-root", 1), ("levels-child", 2), ("levels-grandchild", 3), ("levels-second", 1),
    ]
    for (id, level) in expected {
      let element = harness.element(identifier: SubagentTreeView.rowIdentifier(for: SubagentRunID(id)))
      #expect(element != nil, "No row for \(id).")
      #expect(element?.value == SubagentTreeView.levelValue(level), "The row \(id) has the wrong level.")
    }
  }

  @Test func theRowsFollowTheOutlineOrder() {
    let runs = Self.threeLevelRuns(prefix: "order-")
    let harness = HostedViewHarness(SubagentTreeView(runs: runs), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let rows = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(SubagentTreeView.rowIdentifierPrefix)
    }
    #expect(rows == ["order-root", "order-child", "order-grandchild", "order-second"].map {
      SubagentTreeView.rowIdentifier(for: SubagentRunID($0))
    })
  }

  @Test func aRunWithAMissingParentIsARoot() {
    let orphan = SubagentRun(id: SubagentRunID("orphan"), parentID: SubagentRunID("gone"))
    let harness = HostedViewHarness(SubagentTreeView(runs: [orphan]), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let element = harness.element(identifier: SubagentTreeView.rowIdentifier(for: orphan.id))
    #expect(element?.value == SubagentTreeView.levelValue(1))
  }

  @Test func aParentCycleShowsEachRunOneTime() {
    let first = SubagentRun(id: SubagentRunID("cycle-a"), parentID: SubagentRunID("cycle-b"))
    let second = SubagentRun(id: SubagentRunID("cycle-b"), parentID: SubagentRunID("cycle-a"))
    let outline = SubagentTreeView.outline(of: [first, second])
    #expect(outline.map(\.run.id) == [first.id, second.id])
    #expect(outline.map(\.level) == [1, 2])
  }

  @Test func aStatePatchEvaluatesOnlyThatRow() {
    let prefix = "patch-"
    let thread = AgentThread()
    for run in Self.threeLevelRuns(prefix: prefix) {
      thread.apply(
        .upsertSubagent(
          SubagentPatch(
            id: run.id, parentID: run.parentID.map { .value($0) } ?? .unchanged,
            title: .value(run.title), state: .value(run.state))))
    }
    let harness = HostedViewHarness(SubagentTreeView(runs: thread.subagents), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()
    let ids = thread.subagents.map(\.id)
    for id in ids {
      #expect(BodyEvaluationCounter.count(SubagentTreeView.counterKey(for: id)) >= 1)
    }
    BodyEvaluationCounter.reset(prefix: SubagentTreeView.counterKey(for: SubagentRunID(prefix)))

    let target = SubagentRunID(prefix + "child")
    thread.apply(.upsertSubagent(SubagentPatch(id: target, state: .value(.readyForReview))))
    harness.pump()

    for id in ids {
      let expected = id == target ? 1 : 0
      #expect(
        BodyEvaluationCounter.count(SubagentTreeView.counterKey(for: id)) == expected,
        "The row \(id.rawValue) has the wrong count.")
    }
    #expect(
      harness.element(identifier: SubagentTreeView.rowIdentifier(for: target))?.label
        == SubagentTreeView.rowLabel(title: "Find the call sites", state: .readyForReview))
    BodyEvaluationCounter.reset(prefix: SubagentTreeView.counterKey(for: SubagentRunID(prefix)))
  }

  @Test func eachStateHasADistinctLabel() {
    let states = SubagentState.knownCases + [.unknown("paused")]
    let labels = states.map(SubagentTreeView.stateLabel)
    #expect(Set(labels).count == states.count)
  }

  @Test func theStopButtonCallsTheHostClosure() async throws {
    let runs = Self.threeLevelRuns(prefix: "stop-")
    var stopped: [SubagentRunID] = []
    let harness = HostedViewHarness(
      SubagentTreeView(runs: runs, onStop: { stopped.append($0) }), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let root = SubagentRunID("stop-root")
    try harness.press(identifier: SubagentTreeView.stopIdentifier(for: root))
    await waitUntil(harness: harness) { !stopped.isEmpty }

    #expect(stopped == [root])
  }

  @Test func onlyActiveRunsShowTheStopButton() {
    let runs = Self.threeLevelRuns(prefix: "active-")
    let harness = HostedViewHarness(
      SubagentTreeView(runs: runs, onStop: { _ in }), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let shown = ["active-root", "active-grandchild"]
    let hidden = ["active-child", "active-second"]
    for id in shown {
      #expect(harness.element(identifier: SubagentTreeView.stopIdentifier(for: SubagentRunID(id))) != nil)
    }
    for id in hidden {
      #expect(harness.element(identifier: SubagentTreeView.stopIdentifier(for: SubagentRunID(id))) == nil)
    }
  }

  @Test func theOpenButtonGivesTheRunToTheHostClosure() async throws {
    let runs = Self.threeLevelRuns(prefix: "open-")
    var opened: [SubagentRunID] = []
    let harness = HostedViewHarness(
      SubagentTreeView(runs: runs, onOpen: { opened.append($0.id) }), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let child = SubagentRunID("open-child")
    try harness.press(identifier: SubagentTreeView.openIdentifier(for: child))
    await waitUntil(harness: harness) { !opened.isEmpty }

    #expect(opened == [child])
    let root = harness.element(identifier: SubagentTreeView.openIdentifier(for: SubagentRunID("open-root")))
    #expect(root?.isEnabled == false)
  }

  @Test func aTreeWithNoClosuresShowsNoButtons() {
    let runs = Self.threeLevelRuns(prefix: "plain-")
    let harness = HostedViewHarness(SubagentTreeView(runs: runs), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    let buttons = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(SubagentTreeView.stopIdentifierPrefix)
        || $0.hasPrefix(SubagentTreeView.openIdentifierPrefix)
    }
    #expect(buttons.isEmpty)
  }

  @Test func aTreeWithNoRunsShowsTheEmptyState() {
    let harness = HostedViewHarness(SubagentTreeView(runs: []), size: Self.treeSize)
    defer { harness.close() }
    harness.pump()

    #expect(harness.element(identifier: SubagentTreeView.emptyIdentifier) != nil)
  }

  /// Pumps the run loop until `condition` is true, for at most
  /// `callWaitSeconds`.
  private func waitUntil(
    harness: HostedViewHarness<some View>,
    _ condition: () -> Bool
  ) async {
    let deadline = Date(timeIntervalSinceNow: Self.callWaitSeconds)
    while !condition(), Date() < deadline {
      harness.pump()
      await Task.yield()
    }
  }
}
