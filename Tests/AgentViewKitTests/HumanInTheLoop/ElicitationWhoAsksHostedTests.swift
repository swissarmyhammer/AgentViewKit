import AgentViewKit
import AgentViewKitTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The "who asks" line of the elicitation cards of a ``RequestDeck`` in a
/// window (card 39).
///
/// The scripted agent sends each request with
/// ``ScriptedSession/sendInOrder(_:)``, which waits until the session model
/// holds it. Then one render pass shows it. A press on the main actor is
/// followed by a check of the model state that the press changes at once,
/// and then by a render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct ElicitationWhoAsksHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 640, height: 640)

  /// The JSON-RPC id of the first request that the agent sends. The next
  /// requests take the next ids.
  static let firstRequestID = 300

  /// The `_meta` of a request that a reviewer sub-agent sends from `runCode`.
  static let reviewerFromRunCode = #"{"agentPath": ["reviewer"], "source": "runCode"}"#

  /// The `_meta` of a request that a reviewer sub-agent sends with no source.
  static let reviewer = #"{"agentPath": ["reviewer"]}"#

  /// The `_meta` of a request that a planner sub-agent sends with no source.
  static let planner = #"{"agentPath": ["planner"]}"#

  /// Shows the deck of a session, with a root agent label when `rootLabel`
  /// is not `nil`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - rootLabel: The root agent label of the deck, or `nil` for the
  ///     default label.
  /// - Returns: The harness.
  static func mount(session: ScriptedSession, rootLabel: String? = nil) -> HostedViewHarness<some View> {
    HostedViewHarness(size: size) {
      VStack {
        if let rootLabel {
          RequestDeck(session: session.model)
            .environment(\.elicitationRootAgentLabel, rootLabel)
        } else {
          RequestDeck(session: session.model)
        }
        Spacer()
      }
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// A form elicitation of the scripted session with a `_meta` object.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - meta: The JSON text of the `_meta` object.
  /// - Returns: The request.
  static func formElicitation(id: Int, meta: String) -> ScriptedSession.AgentRequest {
    let params = #"""
      {"sessionId": "\#(ScriptedSession.sessionID)", "message": "Your name?", "mode": "form",
       "requestedSchema": {"type": "object", "properties": {"name": {"type": "string", "default": "Ada"}}},
       "_meta": \#(meta)}
      """#
    return ScriptedSession.AgentRequest(method: ScriptedSession.elicitationMethod, id: id, params: params)
  }

  /// A URL mode elicitation of the scripted session with a `_meta` object.
  ///
  /// - Parameters:
  ///   - id: The JSON-RPC id of the request.
  ///   - meta: The JSON text of the `_meta` object.
  /// - Returns: The request.
  static func urlElicitation(id: Int, meta: String) -> ScriptedSession.AgentRequest {
    let params = #"""
      {"sessionId": "\#(ScriptedSession.sessionID)", "message": "Sign in", "mode": "url",
       "url": "https://example.com/auth", "elicitationId": "url-1", "_meta": \#(meta)}
      """#
    return ScriptedSession.AgentRequest(method: ScriptedSession.elicitationMethod, id: id, params: params)
  }

  /// Sends `requests` from the agent, waits until the session model holds
  /// each one, and then makes `harness` show them.
  ///
  /// - Parameters:
  ///   - requests: The requests of the agent.
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Throws: The error of the transport.
  static func send(
    _ requests: [ScriptedSession.AgentRequest], to session: ScriptedSession,
    rendering harness: HostedViewHarness<some View>
  ) async throws {
    try await session.sendInOrder(requests)
    harness.render()
  }

  /// The label of each who-asks element in the accessibility tree, in tree
  /// order.
  ///
  /// - Parameter harness: The harness.
  /// - Returns: The labels.
  static func whoAsksLabels(in harness: HostedViewHarness<some View>) -> [String?] {
    harness.accessibilityElements()
      .filter { $0.identifier == ElicitationView.whoAsksIdentifier }
      .map(\.label)
  }

  @Test func aFormCardShowsTheAgentPathAndTheSource() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    try await Self.send(
      [Self.formElicitation(id: Self.firstRequestID, meta: Self.reviewerFromRunCode)], to: session,
      rendering: harness)

    let line = try #require(harness.element(identifier: ElicitationView.whoAsksIdentifier))
    #expect(line.label == "Asked by root, reviewer, from runCode")
  }

  @Test func aFormCardWithNoMetaShowsNoLine() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    try await Self.send([.formElicitation(id: Self.firstRequestID)], to: session, rendering: harness)

    try #require(harness.element(identifier: ElicitationView.formIdentifier) != nil)
    #expect(harness.element(identifier: ElicitationView.whoAsksIdentifier) == nil)
  }

  @Test func aURLCardShowsTheAgentPathAndTheSource() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    try await Self.send(
      [Self.urlElicitation(id: Self.firstRequestID, meta: Self.reviewerFromRunCode)], to: session,
      rendering: harness)

    try #require(harness.element(identifier: ElicitationURLConsentView.identifier) != nil)
    let line = try #require(harness.element(identifier: ElicitationView.whoAsksIdentifier))
    #expect(line.label == "Asked by root, reviewer, from runCode")
  }

  @Test func theRootLabelOfTheEnvironmentNamesTheRoot() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session, rootLabel: "Claude")
    defer { harness.close() }

    try await Self.send(
      [Self.formElicitation(id: Self.firstRequestID, meta: Self.reviewer)], to: session, rendering: harness)

    let line = try #require(harness.element(identifier: ElicitationView.whoAsksIdentifier))
    #expect(line.label == "Asked by Claude, reviewer")
  }

  @Test func aPermissionCardShowsNoLine() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }

    _ = try await session.sendPermissionRequest(id: Self.firstRequestID, rendering: harness)

    try #require(harness.element(identifier: PermissionView.identifier) != nil)
    #expect(harness.element(identifier: ElicitationView.whoAsksIdentifier) == nil)
  }

  @Test func onlyTheFrontCardLineIsInTheTreeAndNextShowsTheSecondLine() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mount(session: session)
    defer { harness.close() }
    try await Self.send(
      [
        Self.formElicitation(id: Self.firstRequestID, meta: Self.planner),
        Self.formElicitation(id: Self.firstRequestID + 1, meta: Self.reviewer),
      ], to: session, rendering: harness)
    let model = session.model
    let second = try #require(model.pendingRequests.last)

    #expect(Self.whoAsksLabels(in: harness) == ["Asked by root, planner"])

    try harness.press(identifier: RequestDeck.nextIdentifier)
    try #require(model.frontRequest?.id == second.id)
    harness.render()

    #expect(Self.whoAsksLabels(in: harness) == ["Asked by root, reviewer"])
  }
}
