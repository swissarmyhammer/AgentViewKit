import AgentViewKit
import Foundation
import Testing

@Suite @MainActor struct SubagentRunTests {
  static let rootID = SubagentRunID("root")
  static let childID = SubagentRunID("child")

  @Test func stateReadsEachKnownWireValue() {
    for state in SubagentState.knownCases {
      #expect(SubagentState(wireValue: state.wireValue) == state)
    }
    #expect(SubagentState(wireValue: "paused") == .unknown("paused"))
  }

  @Test func stateWireValuesAreDistinct() {
    let values = SubagentState.knownCases.map(\.wireValue)
    #expect(Set(values).count == values.count)
    #expect(SubagentState.knownCases.count == 5)
  }

  @Test func upsertMakesARunAtTheEnd() {
    let thread = AgentThread()
    thread.apply(.upsertSubagent(SubagentPatch(id: Self.rootID, title: .value("Search"))))
    thread.apply(
      .upsertSubagent(
        SubagentPatch(id: Self.childID, parentID: .value(Self.rootID), state: .value(.working))))

    #expect(thread.subagents.map(\.id) == [Self.rootID, Self.childID])
    #expect(thread.subagents[0].title == "Search")
    #expect(thread.subagents[0].revision == 0)
    #expect(thread.subagents[1].parentID == Self.rootID)
    #expect(thread.subagents[1].state == .working)
  }

  @Test func upsertChangesAKnownRunInPlace() {
    let thread = AgentThread()
    let start = Date(timeIntervalSinceReferenceDate: 10)
    let end = Date(timeIntervalSinceReferenceDate: 20)
    thread.apply(
      .upsertSubagent(SubagentPatch(id: Self.rootID, title: .value("Search"), startedAt: .value(start))))
    let run = thread.subagents[0]

    thread.apply(
      .upsertSubagent(
        SubagentPatch(
          id: Self.rootID, state: .value(.done), endedAt: .value(end), threadID: .value("session-1"))))

    #expect(thread.subagents.count == 1)
    #expect(thread.subagents[0] === run)
    #expect(run.title == "Search")
    #expect(run.state == .done)
    #expect(run.startedAt == start)
    #expect(run.endedAt == end)
    #expect(run.threadID == "session-1")
    #expect(run.revision == 1)
  }

  @Test func clearedFieldsGiveTheEmptyValues() {
    let thread = AgentThread()
    thread.apply(
      .upsertSubagent(
        SubagentPatch(
          id: Self.childID, parentID: .value(Self.rootID), title: .value("Search"),
          threadID: .value("session-1"))))
    thread.apply(
      .upsertSubagent(
        SubagentPatch(id: Self.childID, parentID: .cleared, title: .cleared, threadID: .cleared)))

    let run = thread.subagents[0]
    #expect(run.parentID == nil)
    #expect(run.title == "")
    #expect(run.threadID == nil)
  }

  @Test func clearRemovesTheRuns() {
    let thread = AgentThread()
    thread.apply(.upsertSubagent(SubagentPatch(id: Self.rootID)))
    thread.apply(.clear)
    #expect(thread.subagents.isEmpty)

    thread.apply(.upsertSubagent(SubagentPatch(id: Self.rootID)))
    #expect(thread.subagents.map(\.id) == [Self.rootID])
  }

  @Test func aNewRunHasTheDefaultValues() {
    let run = SubagentRun(id: Self.rootID)
    #expect(run.parentID == nil)
    #expect(run.title == "")
    #expect(run.state == .working)
    #expect(run.startedAt == nil)
    #expect(run.endedAt == nil)
    #expect(run.threadID == nil)
    #expect(run.revision == 0)
  }
}
