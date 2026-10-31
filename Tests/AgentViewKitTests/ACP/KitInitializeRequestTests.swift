import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKitDemoSupport

/// Tests of the `initialize` request that a kit host sends.
///
/// The request advertises only the capabilities that the kit views can show:
/// the form and the URL elicitation modes. These capabilities come from
/// `ACPClient.capabilities(for: .interactive)`. The request advertises
/// `auth.terminal` only when the host gives a terminal auth runner.
struct KitInitializeRequestTests {
  /// The capabilities that the client advertises for a host with a UI.
  static let interactiveCapabilities = ACPClient.capabilities(for: .interactive)

  /// The JSON value of an empty capability object, such as `{}`.
  static let emptyCapability = JSONValue.object([:])

  /// The name that the demo app sends in the `info` of its request.
  static let demoName = "AgentViewKitDemo"

  /// The version that the demo app sends in the `info` of its request.
  static let demoVersion = "1.0.0"

  /// Checks that the params of an `initialize` request advertise only the kit
  /// capabilities: an empty `elicitation.form`, an empty `elicitation.url`,
  /// and no `auth`.
  ///
  /// - Parameters:
  ///   - params: The JSON form of the params of the request.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: The error of `#require` when the params have no
  ///   `capabilities` or no `elicitation`.
  static func expectOnlyKitCapabilities(
    in params: JSONValue,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let capabilities = try #require(params["capabilities"], sourceLocation: sourceLocation)
    let elicitation = try #require(capabilities["elicitation"], sourceLocation: sourceLocation)
    #expect(elicitation["form"] == emptyCapability, sourceLocation: sourceLocation)
    #expect(elicitation["url"] == emptyCapability, sourceLocation: sourceLocation)
    #expect(capabilities["auth"] == nil, sourceLocation: sourceLocation)
  }

  @Test func theInitializeFrameOfTheTestHelperAdvertisesOnlyTheKitCapabilities() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    let frame = try #require(session.agent.messages(method: "initialize").first)
    let params = try #require(frame["params"])
    #expect(params["info"]?["name"] == .string(ScriptedSession.clientInfo.name))
    try Self.expectOnlyKitCapabilities(in: params)
  }

  @Test func theDemoRequestHasTheDemoInfoTheClientVersionAndOnlyTheKitCapabilities() throws {
    let request = DemoAgent.makeInitializeRequest()

    #expect(request.info.name == Self.demoName)
    #expect(request.info.version == Self.demoVersion)
    #expect(request.protocolVersion == ACPClient.supportedProtocolVersion)
    try Self.expectOnlyKitCapabilities(in: JSONValue(encoding: request))
  }

  @Test func aHostWithATerminalAuthRunnerAdvertisesTerminalAuth() async throws {
    let session = try await ScriptedSession.open(terminalAuthRunner: FakeTerminalAuthRunner(exitStatus: nil))
    defer { session.close() }

    let frame = try #require(session.agent.messages(method: "initialize").first)
    let capabilities = try #require(frame["params"]?["capabilities"])
    #expect(capabilities["auth"]?["terminal"] == Self.emptyCapability)
    #expect(capabilities["elicitation"]?["form"] == Self.emptyCapability)
    #expect(capabilities["elicitation"]?["url"] == Self.emptyCapability)
  }

  @Test func theKitCapabilitiesAreTheInteractiveCapabilitiesOfTheClient() {
    #expect(ClientCapabilities.agentViewKit == Self.interactiveCapabilities)
  }

  @Test func aRequestWithNoTerminalAuthRunnerHasTheInteractiveCapabilitiesOfTheClient() {
    let request = InitializeRequest.makeAgentViewKitRequest(
      info: ScriptedSession.clientInfo,
      terminalAuthRunner: nil
    )

    #expect(request.capabilities == Self.interactiveCapabilities)
  }

  @Test func aTerminalAuthRunnerAddsOnlyTerminalAuthToTheInteractiveCapabilities() {
    var expected = Self.interactiveCapabilities
    expected.auth = AuthCapabilities(terminal: TerminalAuthCapabilities())

    let request = InitializeRequest.makeAgentViewKitRequest(
      info: ScriptedSession.clientInfo,
      terminalAuthRunner: FakeTerminalAuthRunner(exitStatus: nil)
    )

    #expect(request.capabilities == expected)
  }
}
