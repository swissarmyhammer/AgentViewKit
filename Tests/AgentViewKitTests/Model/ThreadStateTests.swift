import AgentViewKit
import Testing

@Suite struct ThreadStateTests {
  /// Each known ACP stop reason and the case that it gives.
  nonisolated private static let knownStopReasons: [(wireValue: String, reason: StopReason)] = [
    ("end_turn", .endTurn),
    ("max_tokens", .maxTokens),
    ("max_turn_requests", .maxTurnRequests),
    ("refusal", .refusal),
    ("cancelled", .cancelled),
  ]

  @Test(arguments: knownStopReasons)
  func aKnownWireValueGivesItsCase(wireValue: String, reason: StopReason) {
    #expect(StopReason(wireValue: wireValue) == reason)
    #expect(reason.wireValue == wireValue)
  }

  @Test func maxTokensGivesMaxTokens() {
    #expect(StopReason(wireValue: "max_tokens") == .maxTokens)
  }

  @Test func anUnknownWireValueGivesUnknown() {
    let reason = StopReason(wireValue: "x")

    #expect(reason == .unknown("x"))
    #expect(reason.wireValue == "x")
  }

  @Test func theKnownCasesHaveDistinctWireValues() {
    let wireValues = StopReason.knownCases.map(\.wireValue)

    #expect(Set(wireValues).count == wireValues.count)
    #expect(wireValues.count == Self.knownStopReasons.count)
  }

  @Test func idleCarriesAnOptionalStopReason() {
    #expect(ThreadState.idle(nil) != ThreadState.idle(.endTurn))
    #expect(ThreadState.idle(.endTurn) == ThreadState.idle(.endTurn))
    #expect(ThreadState.running != ThreadState.requiresAction)
  }
}
