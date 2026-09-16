import AgentViewKit
import Foundation
import PackageFileSupport
import Testing

/// Checks that the R14 decision in `Docs/decisions/subagent-source.md`, the
/// `SubagentSource.v1` value, and the subagent fixture agree.
@Suite struct SubagentSourceTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/subagent-source.md"

  /// The fixture file, relative to the package root.
  private static let fixturePath = "Tests/Fixtures/subagent/router-agent-spawn.jsonl"

  /// The prefix of the line that states the decision.
  private static let decisionPrefix = "decision:"

  @Test func decisionFileHasTheSurveyTable() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    let header =
      "| candidate | carries parent id | carries state | carries child thread id | available today |"
    #expect(text.contains(header))
    for source in SubagentSource.allCases {
      #expect(text.contains("| `\(source.rawValue)` |"), "The table has no row for \(source).")
    }
  }

  @Test func v1MatchesTheDecisionLine() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    let decisionLines = text.split(separator: "\n").filter {
      $0.hasPrefix(Self.decisionPrefix)
    }
    #expect(decisionLines.count == 1, "The file must have exactly one decision line.")
    let line = try #require(decisionLines.first)
    let value = line.dropFirst(Self.decisionPrefix.count)
      .trimmingCharacters(in: .whitespaces)
      .trimmingCharacters(in: CharacterSet(charactersIn: "`"))
    #expect(SubagentSource(rawValue: value) == SubagentSource.v1)
  }

  @Test func rawValuesAreDistinct() {
    let rawValues = SubagentSource.allCases.map(\.rawValue)
    #expect(Set(rawValues).count == rawValues.count)
  }

  /// Decodes each line of the fixture as one Router event.
  ///
  /// - Returns: The events, in file order.
  private static func fixtureEvents() throws -> [RecordedRouterEvent] {
    let text = try PackageFiles.text(of: fixturePath)
    let decoder = JSONDecoder()
    return try text.split(separator: "\n").filter { !$0.isEmpty }.map {
      try decoder.decode(RecordedRouterEvent.self, from: Data($0.utf8))
    }
  }

  @Test func fixtureDecodes() throws {
    let events = try Self.fixtureEvents()
    #expect(!events.isEmpty)
    #expect(events.map(\.seq) == Array(0..<events.count))
  }

  @Test func fixtureSessionEventCarriesTheSpawnLink() throws {
    let events = try Self.fixtureEvents()
    let sessionEvents = events.filter { $0.kind == "session" }
    #expect(sessionEvents.count == 1)
    let session = try #require(sessionEvents.first)
    let spawn = try #require(session.agentSpawn)
    #expect(!spawn.parentToolCallId.isEmpty)
    #expect(spawn.parentSessionId != session.sessionId)
    #expect(session.parentId == nil, "A spawned session is not a fork.")
    #expect(events.allSatisfy { $0.sessionId == session.sessionId })
    #expect(events.dropFirst().allSatisfy { $0.agentSpawn == nil })
  }
}

/// The fields of one Router `TranscriptEvent` JSON line that the `SubagentRun`
/// mapping reads.
///
/// The core target does not import the Router, so this test decodes the line
/// with its own type. The keys are the Router `TranscriptEvent` keys.
private struct RecordedRouterEvent: Decodable {
  /// The parent session and the tool call that started the session.
  struct AgentSpawn: Decodable, Equatable {
    /// The id of the session whose turn started this session.
    let parentSessionId: String
    /// The tool call id, in the turn of the parent, that started this session.
    let parentToolCallId: String
  }

  /// The id of the session that holds the event. This is the child thread id.
  let sessionId: String
  /// The id of the session that forked this session, or `nil`.
  let parentId: String?
  /// The recorder sequence number.
  let seq: Int
  /// The kind of the event, such as `session` or `response`.
  let kind: String
  /// The spawn link. Only the `session` event of a spawned session has it.
  let agentSpawn: AgentSpawn?
}
