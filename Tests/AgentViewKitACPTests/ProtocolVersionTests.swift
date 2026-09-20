import AgentViewKit
import AgentViewKitACP
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import PackageFileSupport
import Testing

/// The `initialize` result of an agent that answers with `version`.
private func initializeResult(version: UInt16) -> String {
  #"{"info": {"name": "agent", "version": "1.0.0"}, "protocolVersion": \#(version)}"#
}

/// The `initialize` request of the kit, with `version`.
private func initializeRequest(version: ProtocolVersion = .v2) -> InitializeRequest {
  InitializeRequest(info: Implementation(name: "AgentViewKitTests", version: "1.0.0"), protocolVersion: version)
}

/// The objects of one test: the scripted agent and a source on a new thread.
private struct Harness {
  let agent: ScriptedWireAgent
  let connection: ClientSideConnection
  let source: ACPThreadSource

  /// Makes a harness whose source reads `updates`.
  ///
  /// - Parameter updates: The session updates that the source can read.
  init(updates: AsyncStream<SessionUpdate> = AsyncStream { $0.finish() }) async {
    let client = SwiftUIACPClient()
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    connection = await client.connect(over: clientEnd)
    agent = ScriptedWireAgent(transport: agentEnd)
    agent.start()
    source = ACPThreadSource(thread: AgentThread(), updates: updates, agentName: "Agent")
  }
}

/// Checks the R6 decision in `Docs/decisions/acp-version.md` and the
/// version check of ``ACPThreadSource``.
@MainActor
@Suite struct ProtocolVersionTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/acp-version.md"

  /// The prefix of the line that states the supported versions.
  private static let supportedPrefix = "supported:"

  /// The error records of a thread.
  private func errors(of thread: AgentThread) -> [ThreadError] {
    thread.items.compactMap { item in
      if case .error(let error) = item { error } else { nil }
    }
  }

  /// The message of an error record, or `nil` when the kind is not
  /// `unknown`.
  private func message(of error: ThreadError) -> String? {
    if case .unknown(let message) = error.kind { message } else { nil }
  }

  // MARK: - Decision file

  @Test func valuesMatchTheSupportedLine() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    let lines = text.split(separator: "\n").filter { $0.hasPrefix(Self.supportedPrefix) }
    #expect(lines.count == 1, "The file must have exactly one supported line.")
    let line = try #require(lines.first)
    let versions = line.dropFirst(Self.supportedPrefix.count)
      .split(separator: ",")
      .map { $0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "`")) }
      .compactMap { UInt16($0) }
    #expect(!versions.isEmpty)
    #expect(versions == SupportedProtocolVersions.values)
  }

  @Test func decisionFileHasTheSurveyTable() throws {
    let text = try PackageFiles.text(of: Self.decisionPath)
    #expect(text.contains("| peer | role | ACP library | protocol version | source | checked |"))
    for peer in ["Claude Code", "Codex", "Gemini CLI", "Zed", "Xcode 27"] {
      #expect(text.contains("| \(peer)"), "The table has no row for \(peer).")
    }
  }

  @Test func theLatestWireVersionIsSupported() {
    #expect(SupportedProtocolVersions.contains(.latest))
    #expect(!SupportedProtocolVersions.contains(ProtocolVersion(rawValue: 1)))
  }

  // MARK: - Direct check

  @Test func aSupportedVersionAddsNoRecord() {
    let source = ACPThreadSource(thread: AgentThread(), updates: AsyncStream { $0.finish() }, agentName: "Agent")

    #expect(source.acceptProtocolVersion(.v2, requested: .v2))
    #expect(source.thread.items.isEmpty)
  }

  @Test func anUnsupportedVersionAddsOneErrorThatNamesBothVersions() throws {
    let source = ACPThreadSource(thread: AgentThread(), updates: AsyncStream { $0.finish() }, agentName: "Agent")

    #expect(!source.acceptProtocolVersion(ProtocolVersion(rawValue: 1), requested: .v2))
    #expect(!source.acceptProtocolVersion(ProtocolVersion(rawValue: 1), requested: .v2))

    let recorded = errors(of: source.thread)
    #expect(recorded.count == 1)
    let text = try #require(recorded.first.flatMap(message(of:)))
    #expect(text.contains("version 1"))
    #expect(text.contains("version 2"))
  }

  // MARK: - Over the in-memory agent

  @Test func initializeReturnsTheResponseOfASupportedAgent() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.results["initialize"] = initializeResult(version: 2)

    let response = try await harness.agent.bounded {
      try await harness.source.initialize(over: harness.connection, request: initializeRequest())
    }

    #expect(response?.protocolVersion == .v2)
    #expect(harness.source.thread.items.isEmpty)
    #expect(harness.agent.messages(method: "initialize").first?["params"]?["protocolVersion"] == .number(2))
  }

  @Test func aV1AgentIsRefusedWithOneErrorAndNoUpdate() async throws {
    let update = try SessionUpdateFixtures.decode(SessionUpdateFixtures.agentMessage)
    let updates = AsyncStream<SessionUpdate> { continuation in
      continuation.yield(update)
      continuation.finish()
    }
    let harness = await Harness(updates: updates)
    defer { harness.agent.stop() }
    harness.agent.results["initialize"] = initializeResult(version: 1)

    let response = try await harness.agent.bounded {
      try await harness.source.initialize(over: harness.connection, request: initializeRequest())
    }
    await harness.source.run()

    #expect(response == nil)
    let items = harness.source.thread.items
    #expect(items.count == 1)
    let recorded = errors(of: harness.source.thread)
    #expect(recorded.count == 1)
    let text = try #require(recorded.first.flatMap(message(of:)))
    #expect(text.contains("version 1"))
    #expect(text.contains("version 2"))
  }

  @Test func anAgentThatAnswersAnUnsupportedRequestedVersionIsRefused() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.results["initialize"] = initializeResult(version: 1)

    let response = try await harness.agent.bounded {
      try await harness.source.initialize(
        over: harness.connection, request: initializeRequest(version: ProtocolVersion(rawValue: 1)))
    }

    #expect(response == nil)
    #expect(errors(of: harness.source.thread).count == 1)
  }

  @Test func aTransportFailureThrowsAndAddsNoRecord() async {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["initialize"]

    await #expect(throws: (any Error).self) {
      try await harness.agent.bounded {
        try await harness.source.initialize(over: harness.connection, request: initializeRequest())
      }
    }
    #expect(harness.source.thread.items.isEmpty)
  }
}
