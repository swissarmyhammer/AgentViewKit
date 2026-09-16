import AgentViewKit
import AgentViewKitTestSupport
import SwiftUI
import Testing

@Suite(.serialized) @MainActor struct TaskListViewHostedTests {
  /// The size of a list that shows each entry.
  static let listSize = CGSize(width: 480, height: 640)

  /// The longest time that a test waits for the list to update, in seconds.
  static let updateWaitSeconds: TimeInterval = 1

  /// A plan with one entry for each known status.
  ///
  /// - Parameter id: The identifier of the plan.
  /// - Returns: The plan.
  static func fourEntryPlan(id: String) -> Plan {
    Plan(
      id: PlanID(id),
      entries: [
        PlanEntry(content: "Read the file", priority: .high, status: .completed),
        PlanEntry(content: "Change the parser", priority: .medium, status: .inProgress),
        PlanEntry(content: "Run the tests", priority: .low, status: .pending),
        PlanEntry(content: "Write the notes", priority: .low, status: .cancelled),
      ])
  }

  /// A view that shows the plans of a thread, so that a change to the thread
  /// updates the list.
  struct ThreadTaskList: View {
    /// The thread to show.
    let thread: AgentThread

    var body: some View {
      TaskListView(plans: thread.plans)
    }
  }

  @Test func eachEntryShowsItsTextStatusAndPriority() {
    let plan = Self.fourEntryPlan(id: "labels")
    let harness = HostedViewHarness(TaskListView(plans: [plan.id: plan]), size: Self.listSize)
    defer { harness.close() }
    harness.pump()

    for (index, entry) in plan.entries.enumerated() {
      let element = harness.element(identifier: TaskListView.entryIdentifier(plan: plan.id, index: index))
      #expect(element?.label == TaskListView.entryLabel(entry), "The entry \(index) has the wrong label.")
    }
    #expect(
      TaskListView.entryLabel(plan.entries[1])
        == "Change the parser, In progress, Medium priority")
  }

  @Test func theHeaderCountsTheCompletedEntries() {
    let plan = Self.fourEntryPlan(id: "header")
    #expect(TaskListView.headerText(for: plan) == "1 of 4 done")
  }

  @Test func eachStatusAndPriorityHasADistinctLabel() {
    let statuses = PlanEntry.Status.knownCases + [.unknown("paused")]
    #expect(Set(statuses.map(TaskListView.statusLabel)).count == statuses.count)
    let priorities = PlanEntry.Priority.knownCases + [.unknown("urgent")]
    #expect(Set(priorities.map(TaskListView.priorityLabel)).count == priorities.count)
  }

  @Test func thePlansShowInTheOrderOfTheirIdentifiers() {
    let second = Self.fourEntryPlan(id: "order-b")
    let first = Self.fourEntryPlan(id: "order-a")
    let plans = [second.id: second, first.id: first]
    #expect(TaskListView.orderedPlans(plans).map(\.id) == [first.id, second.id])

    let harness = HostedViewHarness(TaskListView(plans: plans), size: Self.listSize)
    defer { harness.close() }
    harness.pump()
    let entries = harness.accessibilityElements().compactMap(\.identifier).filter {
      $0.hasPrefix(TaskListView.entryIdentifierPrefix)
    }
    let expected = [first, second].flatMap { plan in
      plan.entries.indices.map { TaskListView.entryIdentifier(plan: plan.id, index: $0) }
    }
    #expect(entries == expected)
  }

  @Test func replacingAPlanKeepsTheSectionAndUpdatesTheEntries() async {
    let thread = AgentThread()
    let plan = Self.fourEntryPlan(id: "replace")
    let stateKey = TaskListView.sectionStateKey(for: plan.id)
    BodyEvaluationCounter.reset(stateKey)
    defer { BodyEvaluationCounter.reset(stateKey) }
    thread.apply(.setPlan(plan))
    let harness = HostedViewHarness(ThreadTaskList(thread: thread), size: Self.listSize)
    defer { harness.close() }
    harness.pump()
    #expect(BodyEvaluationCounter.count(stateKey) == 1)

    let replacement = Plan(
      id: plan.id,
      entries: [
        PlanEntry(content: "Read the file", priority: .high, status: .completed),
        PlanEntry(content: "Change the parser", priority: .medium, status: .completed),
      ])
    thread.apply(.setPlan(replacement))
    let secondIdentifier = TaskListView.entryIdentifier(plan: plan.id, index: 1)
    let expectedLabel = TaskListView.entryLabel(replacement.entries[1])
    await harness.pump(until: Self.updateWaitSeconds) {
      harness.element(identifier: secondIdentifier)?.label == expectedLabel
    }

    #expect(harness.element(identifier: secondIdentifier)?.label == expectedLabel)
    #expect(harness.element(identifier: TaskListView.entryIdentifier(plan: plan.id, index: 2)) == nil)
    #expect(BodyEvaluationCounter.count(stateKey) == 1)
  }

  @Test func removingAPlanShowsTheEmptyState() async {
    let thread = AgentThread()
    let plan = Self.fourEntryPlan(id: "remove")
    thread.apply(.setPlan(plan))
    let harness = HostedViewHarness(ThreadTaskList(thread: thread), size: Self.listSize)
    defer { harness.close() }
    harness.pump()
    #expect(harness.element(identifier: TaskListView.emptyIdentifier) == nil)

    thread.apply(.removePlan(plan.id))
    await harness.pump(until: Self.updateWaitSeconds) {
      harness.element(identifier: TaskListView.emptyIdentifier) != nil
    }

    #expect(harness.element(identifier: TaskListView.emptyIdentifier) != nil)
  }
}
