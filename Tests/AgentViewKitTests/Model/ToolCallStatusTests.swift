import AgentViewKit
import Testing

@Suite struct ToolCallStatusTests {
  /// Each known tool call status wire string and the case that it gives.
  nonisolated private static let knownStatuses: [(wireValue: String, status: ToolCallStatus)] = [
    ("pending", .pending),
    ("in_progress", .inProgress),
    ("completed", .completed),
    ("failed", .failed),
    ("cancelled", .cancelled),
    ("_lost", .lost),
  ]

  /// Each known tool kind wire string and the case that it gives.
  nonisolated private static let knownKinds: [(wireValue: String, kind: ToolKind)] = [
    ("read", .read),
    ("edit", .edit),
    ("delete", .delete),
    ("move", .move),
    ("search", .search),
    ("execute", .execute),
    ("think", .think),
    ("fetch", .fetch),
    ("switch_mode", .switchMode),
    ("other", .other),
  ]

  // MARK: - Status

  @Test(arguments: knownStatuses)
  func aKnownStatusGivesItsCase(wireValue: String, status: ToolCallStatus) {
    #expect(ToolCallStatus(wireValue: wireValue) == status)
    #expect(status.wireValue == wireValue)
  }

  @Test func theLostWireValueGivesLost() {
    #expect(ToolCallStatus(wireValue: "_lost") == .lost)
  }

  @Test(arguments: ["_custom", "lost", "Pending", ""])
  func anUnknownStatusGivesUnknown(wireValue: String) {
    let status = ToolCallStatus(wireValue: wireValue)

    #expect(status == .unknown(wireValue))
    #expect(status.wireValue == wireValue)
  }

  @Test func theKnownStatusesHaveDistinctWireValues() {
    let wireValues = ToolCallStatus.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownStatuses.count)
  }

  // MARK: - Kind

  @Test(arguments: knownKinds)
  func aKnownKindGivesItsCase(wireValue: String, kind: ToolKind) {
    #expect(ToolKind(wireValue: wireValue) == kind)
    #expect(kind.wireValue == wireValue)
  }

  @Test func anUnknownKindGivesUnknown() {
    let kind = ToolKind(wireValue: "browse")

    #expect(kind == .unknown("browse"))
    #expect(kind.wireValue == "browse")
  }

  @Test func theKnownKindsHaveDistinctWireValues() {
    let wireValues = ToolKind.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownKinds.count)
  }
}
