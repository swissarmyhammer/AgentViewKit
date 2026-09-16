import AgentViewKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKitACP

/// The working directory filter of the tests.
private let projectPath = "/Users/dev/project"

/// The cursor that the first page gives.
private let secondPageCursor = "page-2"

/// The first `session/list` result: two sessions and a next cursor.
private let firstPageResult = #"""
  {"sessions": [
     {"sessionId": "s1", "cwd": "/Users/dev/project", "title": "Fix the build",
      "updatedAt": "2026-09-16T10:00:00Z"},
     {"sessionId": "s2", "cwd": "/Users/dev/project", "title": "   "}],
   "nextCursor": "page-2"}
  """#

/// The second `session/list` result: one session and no next cursor.
private let secondPageResult = #"""
  {"sessions": [{"sessionId": "s3", "cwd": "/Users/dev/project", "title": "Write docs",
                 "updatedAt": "not a time"}]}
  """#

/// The objects of one test: the scripted agent and the provider.
private struct Harness {
  let client = SwiftUIACPClient()
  let agent: ScriptedWireAgent
  let provider: ACPSessionList

  /// Connects a client to a scripted agent and makes the provider.
  ///
  /// - Parameter cwd: The working directory filter of the provider.
  init(cwd: String? = projectPath) async {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    let connection = await client.connect(over: clientEnd)
    agent = ScriptedWireAgent(transport: agentEnd)
    agent.start()
    provider = ACPSessionList(connection: connection, cwd: cwd)
  }
}

@MainActor
@Suite struct ACPSessionListTests {
  @Test func eachPageSendsTheCursorOfThePreviousResponse() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.resultQueues["session/list"] = [firstPageResult, secondPageResult]

    let first = try await harness.agent.bounded { try await harness.provider.page(after: nil) }
    let second = try await harness.agent.bounded { try await harness.provider.page(after: first.next) }

    let requests = harness.agent.messages(method: "session/list").map { $0["params"] }
    #expect(
      requests == [
        .object(["cwd": .string(projectPath)]),
        .object(["cwd": .string(projectPath), "cursor": .string(secondPageCursor)]),
      ])
    #expect(first.next == secondPageCursor)
    #expect(first.sessions.map(\.id) == [SessionID("s1"), SessionID("s2")])
    #expect(second.next == nil)
    #expect(second.sessions.map(\.id) == [SessionID("s3")])
  }

  @Test func aProviderWithNoDirectorySendsNoDirectory() async throws {
    let harness = await Harness(cwd: nil)
    defer { harness.agent.stop() }
    harness.agent.results["session/list"] = secondPageResult

    _ = try await harness.agent.bounded { try await harness.provider.page(after: nil) }

    let request = try #require(harness.agent.messages(method: "session/list").first)
    #expect(request["params"] == .object([:]))
  }

  @Test func theSummaryKeepsTheFieldsOfTheSession() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.resultQueues["session/list"] = [firstPageResult, secondPageResult]

    let first = try await harness.agent.bounded { try await harness.provider.page(after: nil) }
    let second = try await harness.agent.bounded { try await harness.provider.page(after: first.next) }

    #expect(
      first.sessions == [
        SessionSummary(
          id: SessionID("s1"), title: "Fix the build", cwd: projectPath,
          updatedAt: ISO8601Time.date(from: "2026-09-16T10:00:00Z")),
        SessionSummary(id: SessionID("s2"), title: nil, cwd: projectPath, updatedAt: nil),
      ])
    #expect(second.sessions == [SessionSummary(id: SessionID("s3"), title: "Write docs", cwd: projectPath)])
    #expect(first.sessions.first?.updatedAt != nil)
  }

  @Test func aFailedListThrows() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["session/list"]

    await #expect(throws: (any Error).self) {
      try await harness.agent.bounded { try await harness.provider.page(after: nil) }
    }
  }

  @Test func deleteSendsSessionDelete() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }

    try await harness.agent.bounded { try await harness.provider.delete(SessionID("s2")) }

    let request = try #require(harness.agent.messages(method: "session/delete").first)
    #expect(request["params"] == .object(["sessionId": .string("s2")]))
  }

  @Test func aFailedDeleteThrows() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["session/delete"]

    await #expect(throws: (any Error).self) {
      try await harness.agent.bounded { try await harness.provider.delete(SessionID("s2")) }
    }
  }
}
