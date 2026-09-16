import AgentViewKit
import AgentViewKitRouter
import Foundation
import FoundationModelsExtras
import PackageFileSupport
import Testing

@testable import FoundationModelsRouter

/// Checks the v1 subagent adapter (`Docs/decisions/subagent-source.md`)
/// against the recorded Router fixture.
@Suite @MainActor struct SubagentAdapterTests {
  /// The fixture file, relative to the package root.
  static let fixturePath = "Tests/Fixtures/subagent/router-agent-spawn.jsonl"

  /// The parent tool call id of the fixture spawn.
  static let spawnRunID = SubagentRunID("run-01M2N0R0000000000000000004")

  /// The child session id of the fixture spawn.
  static let childSessionID = "01M2N0R0000000000000000003"

  /// The parent session id of the fixture spawn.
  static let parentSessionID = "01M2N0R0000000000000000002"

  /// A fixed host clock value.
  static let now = Date(timeIntervalSinceReferenceDate: 1_000)

  /// Decodes each line of the fixture as one Router transcript event.
  ///
  /// - Returns: The events, in file order.
  static func fixtureEvents() throws -> [TranscriptEvent] {
    let text = try PackageFiles.text(of: fixturePath)
    let decoder = JSONDecoder()
    return try text.split(separator: "\n").filter { !$0.isEmpty }.map {
      try decoder.decode(TranscriptEvent.self, from: Data($0.utf8))
    }
  }

  // MARK: - Mapping

  @Test func theFixtureGivesOneUpsertSubagent() throws {
    let changes = try Self.fixtureEvents().compactMap {
      SubagentMapping.spawnChange(for: $0, parentRunID: nil)
    }

    #expect(changes.count == 1)
    guard case .upsertSubagent(let patch) = try #require(changes.first) else {
      Issue.record("The change is not upsertSubagent.")
      return
    }
    #expect(patch.id == Self.spawnRunID)
    #expect(patch.threadID == .value(Self.childSessionID))
    #expect(patch.parentID == .cleared)
  }

  @Test func theSpawnChangeKeepsTheParentRun() throws {
    let event = try #require(try Self.fixtureEvents().first)
    let parent = SubagentRunID("parent-run")
    guard case .upsertSubagent(let patch) = SubagentMapping.spawnChange(for: event, parentRunID: parent)
    else {
      Issue.record("The spawn event gives no upsertSubagent.")
      return
    }
    #expect(patch.parentID == .value(parent))
  }

  @Test func theParentSessionIDComesFromTheSpawn() throws {
    let events = try Self.fixtureEvents()
    #expect(events.compactMap(SubagentMapping.parentSessionID) == [Self.parentSessionID])
  }

  @Test func eachRouterToolStatusGivesAState() {
    #expect(SubagentMapping.state(for: FoundationModelsRouter.ToolCallStatus.running) == .working)
    #expect(SubagentMapping.state(for: FoundationModelsRouter.ToolCallStatus.completed) == .done)
    #expect(SubagentMapping.state(for: FoundationModelsRouter.ToolCallStatus.failed) == .failed)
  }

  @Test func eachKitToolStatusGivesAState() {
    let expected: [(AgentViewKit.ToolCallStatus, SubagentState)] = [
      (.pending, .working), (.inProgress, .working), (.completed, .done), (.failed, .failed),
      (.cancelled, .failed), (.lost, .failed), (.unknown("_paused"), .unknown("_paused")),
    ]
    for (status, state) in expected {
      #expect(SubagentMapping.state(for: status) == state)
    }
  }

  @Test func eachOutcomeGivesAState() {
    let expected: [(OperationOutcome, SubagentState)] = [
      (.succeeded, .done), (.failed, .failed), (.timedOut, .failed), (.stopped, .failed),
      (.lost, .failed), (.cancelled, .unknown("cancelled")), (.other("parked"), .unknown("parked")),
    ]
    for (outcome, state) in expected {
      #expect(SubagentMapping.state(for: outcome) == state)
    }
  }

  @Test func sessionEventsGivePatchesForTheRunID() {
    let id = "call-1"
    let runID = SubagentRunID(id)
    #expect(
      SubagentMapping.patch(for: .toolCall(id: id, name: "spawn_agent", argumentsJSON: "{}"), now: Self.now)
        == SubagentPatch(id: runID, title: .value("spawn_agent"), startedAt: .value(Self.now)))
    #expect(
      SubagentMapping.patch(
        for: .toolStatus(id: id, status: .running, summary: nil, output: nil), now: Self.now)
        == SubagentPatch(id: runID, state: .value(.working)))
    #expect(
      SubagentMapping.patch(
        for: .toolStatus(id: id, status: .completed, summary: "ok", output: nil), now: Self.now)
        == SubagentPatch(id: runID, state: .value(.done), endedAt: .value(Self.now)))
    #expect(
      SubagentMapping.patch(for: .runSettled(Self.operation(id, kind: .completed, outcome: .failed)), now: Self.now)
        == SubagentPatch(id: runID, state: .value(.failed), endedAt: .value(Self.now)))
    #expect(
      SubagentMapping.patch(for: .elicitationRequested(Self.operation(id, kind: .elicitation)), now: Self.now)
        == SubagentPatch(id: runID, state: .value(.needsInput)))
    #expect(SubagentMapping.patch(for: .textDelta("text"), now: Self.now) == nil)
  }

  // MARK: - Source

  @Test func theSourceAddsTheSpawnedRunWithTheToolCallFields() throws {
    let session = FakeRouterSession()
    var clock = Self.now
    let source = RouterThreadSource(port: session, clock: { clock })
    source.apply(.toolCall(id: Self.spawnRunID.rawValue, name: "spawn_agent", argumentsJSON: "{}"))
    clock = Self.now.addingTimeInterval(5)

    for event in try Self.fixtureEvents() {
      source.apply(event)
    }

    let run = try #require(source.thread.subagent(id: Self.spawnRunID))
    #expect(source.thread.subagents.count == 1)
    #expect(run.title == "spawn_agent")
    #expect(run.state == .working)
    #expect(run.startedAt == Self.now)
    #expect(run.threadID == Self.childSessionID)
    #expect(run.parentID == nil)
  }

  @Test func theSourceLinksANestedSpawnToItsParentRun() throws {
    let session = FakeRouterSession()
    let source = RouterThreadSource(port: session, clock: { Self.now })
    let parent = SubagentRunID("outer-run")
    source.thread.apply(
      .upsertSubagent(SubagentPatch(id: parent, threadID: .value(Self.parentSessionID))))

    for event in try Self.fixtureEvents() {
      source.apply(event)
    }

    #expect(source.thread.subagent(id: Self.spawnRunID)?.parentID == parent)
  }

  @Test func theSourcePatchesOnlyKnownRuns() throws {
    let session = FakeRouterSession()
    let source = RouterThreadSource(port: session, clock: { Self.now })
    source.apply(.toolStatus(id: "plain-call", status: .completed, summary: nil, output: nil))
    #expect(source.thread.subagents.isEmpty)

    for event in try Self.fixtureEvents() {
      source.apply(event)
    }
    source.apply(
      .toolStatus(id: Self.spawnRunID.rawValue, status: .completed, summary: "ok", output: nil))

    let run = try #require(source.thread.subagent(id: Self.spawnRunID))
    #expect(run.state == .done)
    #expect(run.endedAt == Self.now)
    #expect(source.thread.subagents.count == 1)
  }

  /// An operation event for a run.
  ///
  /// - Parameters:
  ///   - correlationID: The id of the run.
  ///   - kind: The kind of the event.
  ///   - outcome: The outcome of a completed event.
  /// - Returns: The event.
  static func operation(
    _ correlationID: String, kind: OperationEventKind, outcome: OperationOutcome? = nil
  ) -> OperationEvent {
    OperationEvent(
      tool: "agents", op: "spawn agent", correlationID: correlationID, kind: kind, detail: "{}",
      outcome: outcome)
  }
}
