import AgentViewKit
import DemoSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import PackageFileSupport
import Testing

/// The objects of one test over the in-memory agent: the scripted agent and
/// a connection model that is connected to it.
@MainActor
private struct Harness {
  let agent: ScriptedWireAgent
  let connection = ConnectionModel()

  /// Connects a new connection model to a new scripted agent.
  init() async {
    let (clientEnd, agentEnd) = InMemoryTransport.pair()
    _ = await connection.connect(over: clientEnd)
    agent = ScriptedWireAgent(transport: agentEnd)
    agent.start()
  }

  /// Gives the agent the `initialize` result with `version`.
  ///
  /// - Parameter version: The protocol version of the answer.
  func answerInitialize(with version: ProtocolVersion) {
    agent.results["initialize"] =
      #"{"info": {"name": "agent", "version": "1.0.0"}, "protocolVersion": \#(version.rawValue)}"#
  }

  /// Sends `initialize` with `version` through
  /// `ConnectionModel.initializeCheckingProtocolVersion(_:)`, with the time
  /// limit of the ACP tests.
  ///
  /// - Parameter version: The protocol version of the request.
  /// - Returns: The answer of the agent.
  /// - Throws: The error of the call.
  func initialize(requesting version: ProtocolVersion = .v2) async throws -> InitializeResponse {
    let request = InitializeRequest(
      info: Implementation(name: "AgentViewKitTests", version: "1.0.0"), protocolVersion: version)
    return try await agent.bounded {
      try await connection.initializeCheckingProtocolVersion(request)
    }
  }
}

/// Checks the R6 decision in `Docs/decisions/acp-version.md` and the
/// protocol version check of ``SupportedProtocolVersions``.
@MainActor
@Suite struct ProtocolVersionTests {
  /// The decision file, relative to the package root.
  private static let decisionPath = "Docs/decisions/acp-version.md"

  /// The prefix of the line that states the supported versions.
  private static let supportedPrefix = "supported:"

  /// Protocol version 1, which the kit does not accept.
  private static let v1 = ProtocolVersion(rawValue: 1)

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
    #expect(!SupportedProtocolVersions.contains(Self.v1))
  }

  // MARK: - Direct check

  @Test func aSupportedVersionIsAccepted() {
    #expect(throws: Never.self) {
      try SupportedProtocolVersions.accept(.v2, requested: .v2)
    }
  }

  @Test func anUnsupportedVersionThrowsAnErrorThatNamesBothVersions() throws {
    let error = try #require(throws: UnsupportedProtocolVersionError.self) {
      try SupportedProtocolVersions.accept(Self.v1, requested: .v2)
    }

    #expect(error == UnsupportedProtocolVersionError(received: Self.v1, requested: .v2))
    #expect(error.description.contains("version 1"))
    #expect(error.description.contains("version 2"))
  }

  // MARK: - Over the in-memory agent

  @Test func initializeReturnsTheResponseOfASupportedAgent() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.answerInitialize(with: .v2)

    let response = try await harness.initialize()

    #expect(response.protocolVersion == .v2)
    #expect(harness.connection.initializeResponse == response)
    let sentVersion = harness.agent.messages(method: "initialize").first?["params"]?["protocolVersion"]
    #expect(sentVersion == .number(Double(ProtocolVersion.v2.rawValue)))
  }

  @Test func aV1AgentIsRefusedWithAnErrorThatNamesBothVersions() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.answerInitialize(with: Self.v1)

    await #expect(throws: UnsupportedProtocolVersionError(received: Self.v1, requested: .v2)) {
      try await harness.initialize()
    }
  }

  @Test func anAgentThatAnswersAnUnsupportedRequestedVersionIsRefused() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.answerInitialize(with: Self.v1)

    await #expect(throws: UnsupportedProtocolVersionError(received: Self.v1, requested: Self.v1)) {
      try await harness.initialize(requesting: Self.v1)
    }
  }

  @Test func aTransportFailureThrowsTheErrorOfTheConnection() async throws {
    let harness = await Harness()
    defer { harness.agent.stop() }
    harness.agent.failingMethods = ["initialize"]

    let error = try await #require(throws: (any Error).self) {
      try await harness.initialize()
    }

    #expect(!(error is UnsupportedProtocolVersionError))
  }
}
