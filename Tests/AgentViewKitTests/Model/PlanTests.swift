import AgentViewKit
import Testing

@Suite struct PlanTests {
  /// Each known ACP plan entry priority and the case that it gives.
  nonisolated private static let knownPriorities:
    [(wireValue: String, priority: PlanEntry.Priority)] = [
      ("high", .high),
      ("medium", .medium),
      ("low", .low),
    ]

  /// Each known ACP plan entry status and the case that it gives.
  nonisolated private static let knownStatuses: [(wireValue: String, status: PlanEntry.Status)] = [
    ("pending", .pending),
    ("in_progress", .inProgress),
    ("completed", .completed),
    ("cancelled", .cancelled),
  ]

  // MARK: - Priority

  @Test(arguments: knownPriorities)
  func aKnownPriorityGivesItsCase(wireValue: String, priority: PlanEntry.Priority) {
    #expect(PlanEntry.Priority(wireValue: wireValue) == priority)
    #expect(priority.wireValue == wireValue)
  }

  @Test func anUnknownPriorityGivesUnknown() {
    let priority = PlanEntry.Priority(wireValue: "x")

    #expect(priority == .unknown("x"))
    #expect(priority.wireValue == "x")
  }

  @Test func theKnownPrioritiesHaveDistinctWireValues() {
    let wireValues = PlanEntry.Priority.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownPriorities.count)
  }

  // MARK: - Status

  @Test(arguments: knownStatuses)
  func aKnownStatusGivesItsCase(wireValue: String, status: PlanEntry.Status) {
    #expect(PlanEntry.Status(wireValue: wireValue) == status)
    #expect(status.wireValue == wireValue)
  }

  @Test func anUnknownStatusGivesUnknown() {
    let status = PlanEntry.Status(wireValue: "x")

    #expect(status == .unknown("x"))
    #expect(status.wireValue == "x")
  }

  @Test func theKnownStatusesHaveDistinctWireValues() {
    let wireValues = PlanEntry.Status.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownStatuses.count)
  }

  // MARK: - Plan

  @Test func aPlanKeepsTheOrderOfItsEntries() {
    let entries = [
      PlanEntry(content: "Read the file", priority: .high, status: .completed),
      PlanEntry(content: "Edit the file", priority: .low, status: .pending),
    ]
    let plan = Plan(id: PlanID("plan-1"), entries: entries)

    #expect(plan.id == PlanID("plan-1"))
    #expect(plan.entries.map(\.content) == ["Read the file", "Edit the file"])
  }
}
