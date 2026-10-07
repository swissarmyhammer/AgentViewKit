import AgentViewKit
import FoundationModelsACP
import Testing

/// Tests of the labels of ``TaskListView``. The hosted tests of the plan rows
/// of a session are in `SessionEntryRowsHostedTests`.
@Suite struct TaskListViewLabelTests {
  /// The entries of a plan, with one entry for each known status.
  static let fourEntries = [
    PlanEntry(content: "Read the file", priority: .high, status: .completed),
    PlanEntry(content: "Change the parser", priority: .medium, status: .inProgress),
    PlanEntry(content: "Run the tests", priority: .low, status: .pending),
    PlanEntry(content: "Write the notes", priority: .low, status: .cancelled),
  ]

  @Test func theEntryLabelHasTheTextTheStatusAndThePriority() {
    #expect(
      TaskListView.entryLabel(Self.fourEntries[1])
        == "Change the parser, In progress, Medium priority")
  }

  @Test func theHeaderCountsTheCompletedEntries() {
    #expect(TaskListView.headerText(for: Self.fourEntries) == "1 of 4 done")
  }

  @Test func eachStatusAndPriorityHasADistinctLabel() {
    let statuses: [PlanEntryStatus] = [.pending, .inProgress, .completed, .cancelled, .unknown("paused")]
    #expect(Set(statuses.map(TaskListView.statusLabel)).count == statuses.count)
    let priorities: [PlanEntryPriority] = [.high, .medium, .low, .unknown("urgent")]
    #expect(Set(priorities.map(TaskListView.priorityLabel)).count == priorities.count)
  }
}
