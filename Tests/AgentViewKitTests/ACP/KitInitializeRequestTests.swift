import AgentViewKit
import AgentViewKitTestSupport
import FoundationModelsACP
import Testing

@testable import DemoSupport

/// Tests of the `initialize` request that a kit host sends.
///
/// The request advertises only the capabilities that the kit views can show:
/// the form and the URL elicitation modes, and no `auth` capability.
struct KitInitializeRequestTests {
  /// The JSON value of an empty capability object, such as `{}`.
  static let emptyCapability = AgentViewKit.JSONValue.object([:])

  @Test func theInitializeFrameOfTheTestHelperAdvertisesOnlyTheKitCapabilities() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }

    let frame = try #require(session.agent.messages(method: "initialize").first)
    let params = try #require(frame["params"])
    let capabilities = try #require(params["capabilities"])
    let elicitation = try #require(capabilities["elicitation"])
    #expect(params["info"]?["name"] == .string(ScriptedSession.clientInfo.name))
    #expect(elicitation["form"] == Self.emptyCapability)
    #expect(elicitation["url"] == Self.emptyCapability)
    #expect(capabilities["auth"] == nil)
  }

  @Test func theDemoSessionSendsTheKitRequestWithTheInfoOfTheDemo() {
    #expect(
      ACPDemoSession.initializeRequest
        == InitializeRequest.makeAgentViewKitRequest(info: ACPDemoSession.clientInfo))
  }
}
