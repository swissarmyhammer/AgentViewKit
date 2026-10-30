import AgentViewKit
import DemoSupport
import EditorTestSupport
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
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
  /// `ConnectionModel.initializeCheckingProtocolVersion(_:)`.
  ///
  /// - Parameter version: The protocol version of the request.
  /// - Returns: The answer of the agent.
  /// - Throws: The error of the call.
  func initialize(requesting version: ProtocolVersion = .v2) async throws -> InitializeResponse {
    let request = InitializeRequest(
      info: Implementation(name: "AgentViewKitTests", version: "1.0.0"), protocolVersion: version)
    return try await connection.initializeCheckingProtocolVersion(request)
  }
}

/// Checks the protocol version check of ``SupportedProtocolVersions``.
@MainActor
@Suite struct ProtocolVersionTests {
  /// Protocol version 1, which the kit does not accept.
  private static let v1 = ProtocolVersion(rawValue: 1)

  // MARK: - Supported versions

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
