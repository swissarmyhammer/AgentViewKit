#if DEBUG
  import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import DemoSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The pending request cards over the client models (update.md §3 D7, §4.2
  /// "Pending requests", §4.3 "Request-scoped elicitations", §4.6 item 3).
  ///
  /// Each test shows a ``PendingRequestsHost`` over a `SessionModel` or a
  /// `ConnectionModel` of a ``ScriptedSession``. The scripted agent sends the
  /// request, and the test reads the frames that the agent receives.
  @Suite(.serialized, .hostedSerially) @MainActor struct PendingRequestsSessionModelHostedTests {
    /// The longest time that a test waits for a change, in seconds.
    static let waitTimeout: TimeInterval = 5

    /// The size of the hosted cards.
    static let size = CGSize(width: 640, height: 480)

    /// The JSON-RPC id of the request that the agent sends to the client.
    static let agentRequestID = 100

    /// The number of runs of the frame order test.
    static let orderRuns = 50

    /// The comment that the reject tests send.
    static let comment = "Use the test file."

    /// The method of a permission request.
    static let permissionMethod = "session/request_permission"

    /// The method of an elicitation request.
    static let elicitationMethod = "elicitation/create"

    /// The method of a prompt request.
    static let promptMethod = "session/prompt"

    /// The method of a login request.
    static let loginMethod = "auth/login"

    /// The id of the auth method of the agent.
    static let authMethodID = "agent-login"

    /// The `initialize` result with protocol version 2, the session
    /// capabilities and one agent auth method.
    static let initializeResult = #"""
      {"info": {"name": "scripted-agent", "version": "1.0.0"}, "protocolVersion": 2,
       "capabilities": {"session": {}},
       "authMethods": [{"type": "agent", "methodId": "agent-login", "name": "Sign in"}]}
      """#

    /// Decodes JSON text into a kit JSON value.
    ///
    /// - Parameter text: The JSON text.
    /// - Returns: The value.
    static func json(_ text: String) throws -> AgentViewKit.JSONValue {
      try JSONDecoder().decode(AgentViewKit.JSONValue.self, from: Data(text.utf8))
    }

    /// The response frame that the agent received for the request with `id`.
    ///
    /// - Parameters:
    ///   - id: The JSON-RPC id of the request of the agent.
    ///   - session: The scripted session.
    /// - Returns: The frame, or `nil`.
    static func response(to id: Int, in session: ScriptedSession) -> AgentViewKit.JSONValue? {
      session.agent.response(to: Double(id))
    }

    /// Shows the host of a session model.
    ///
    /// - Parameter session: The scripted session.
    /// - Returns: The harness.
    static func mount(session: ScriptedSession) -> HostedViewHarness<some View> {
      HostedViewHarness(size: size) {
        PendingRequestsHost(session: session.model)
          .transaction { $0.disablesAnimations = true }
      }
    }

    /// The identifier of the card container of a pending request.
    ///
    /// - Parameter id: The local id of the request.
    /// - Returns: The identifier.
    static func cardIdentifier(_ id: UUID) -> String {
      PendingRequestsHost.identifier(for: id.uuidString)
    }

    /// The position of the prompt frame with `text` in the frames of `agent`.
    ///
    /// - Parameters:
    ///   - text: The text of the prompt.
    ///   - agent: The scripted agent.
    /// - Returns: The position, or `nil`.
    static func indexOfPrompt(withText text: String, in agent: ScriptedWireAgent) -> Int? {
      agent.received.firstIndex { frame in
        frame["method"]?.stringValue == promptMethod
          && ScriptedWireAgent.promptText(of: frame) == text
      }
    }

    // MARK: - Permission

    @Test func aSelectedOptionGoesToTheAgentAndTheCardGoesAway() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let model = session.model

      try await session.sendRequest(
        Self.permissionMethod, id: Self.agentRequestID, params: ScriptedSession.permissionParams)
      await harness.pump(until: Self.waitTimeout) { !model.pendingPermissions.isEmpty }
      let pending = try #require(model.pendingPermissions.first)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) != nil
      }
      #expect(harness.element(identifier: PermissionView.identifier) != nil)

      try harness.press(identifier: PermissionView.optionIdentifier(for: PermissionOptionID("yes")))
      await harness.pump(until: Self.waitTimeout) { Self.response(to: Self.agentRequestID, in: session) != nil }
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) == nil
      }

      let response = try #require(Self.response(to: Self.agentRequestID, in: session))
      #expect(response["result"] == (try Self.json(#"{"outcome": {"outcome": "selected", "optionId": "yes"}}"#)))
      #expect(model.pendingPermissions.isEmpty)
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) == nil)
      #expect(session.agent.messages(method: Self.promptMethod).isEmpty)
    }

    @Test func aRejectWithACommentSendsTheAnswerAndThenThePrompt() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let model = session.model

      try await session.sendRequest(
        Self.permissionMethod, id: Self.agentRequestID, params: ScriptedSession.permissionParams)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: PermissionView.identifier) != nil
      }
      try harness.press(identifier: PermissionView.optionIdentifier(for: PermissionOptionID("no")))
      harness.pump()
      #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
      harness.type(Self.comment)
      try harness.press(identifier: PermissionView.commentSubmitIdentifier)
      await harness.pump(until: Self.waitTimeout) {
        Self.indexOfPrompt(withText: Self.comment, in: session.agent) != nil
      }

      let answer = try #require(session.agent.index(ofResponseTo: Double(Self.agentRequestID)))
      let prompt = try #require(Self.indexOfPrompt(withText: Self.comment, in: session.agent))
      #expect(answer < prompt)
      #expect(
        session.agent.received[answer]["result"]
          == (try Self.json(#"{"outcome": {"outcome": "selected", "optionId": "no"}}"#)))
      #expect(model.pendingPermissions.isEmpty)
    }

    /// The order of the frames when a client answers a permission request
    /// and then sends a prompt, as the card does for a comment. The test reads
    /// the client models only, and it runs many times to catch a race.
    @Test func thePermissionResponseFrameComesBeforeTheNextPromptFrame() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let model = session.model

      for run in 0..<Self.orderRuns {
        let requestID = Self.agentRequestID + run
        let text = "Comment \(run)"
        try await session.sendRequest(Self.permissionMethod, id: requestID, params: ScriptedSession.permissionParams)
        #expect(await waitUntil { !model.pendingPermissions.isEmpty })
        let pending = try #require(model.pendingPermissions.first)

        model.selectPermission(pending.id, option: PermissionOptionId(rawValue: "no"))
        _ = try await model.prompt([.text(TextContent(text: text))])

        #expect(await waitUntil { Self.indexOfPrompt(withText: text, in: session.agent) != nil })
        let answer = try #require(session.agent.index(ofResponseTo: Double(requestID)))
        let prompt = try #require(Self.indexOfPrompt(withText: text, in: session.agent))
        #expect(answer < prompt, "Run \(run): the prompt frame came before the response frame.")
      }
    }

    // MARK: - Elicitation

    /// The answers that the buttons of an elicitation form give.
    enum ElicitationAnswer: CaseIterable {
      /// The Submit button.
      case accept

      /// The Decline button.
      case decline

      /// The Cancel button.
      case cancel

      /// The accessibility identifier of the button.
      @MainActor var buttonIdentifier: String {
        switch self {
        case .accept: ElicitationView.submitIdentifier
        case .decline: ElicitationView.declineIdentifier
        case .cancel: ElicitationView.cancelIdentifier
        }
      }

      /// The JSON text of the result that the agent receives.
      var expectedResult: String {
        switch self {
        case .accept: #"{"action": "accept", "content": {"name": "Ada"}}"#
        case .decline: #"{"action": "decline"}"#
        case .cancel: #"{"action": "cancel"}"#
        }
      }
    }

    @Test(arguments: ElicitationAnswer.allCases)
    func eachElicitationAnswerGoesToTheAgentAndTheCardGoesAway(answer: ElicitationAnswer) async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let model = session.model

      try await session.sendRequest(
        Self.elicitationMethod, id: Self.agentRequestID, params: ScriptedSession.formElicitationParams)
      await harness.pump(until: Self.waitTimeout) { !model.pendingElicitations.isEmpty }
      let pending = try #require(model.pendingElicitations.first)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ElicitationView.formIdentifier) != nil
      }
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) != nil)

      try harness.press(identifier: answer.buttonIdentifier)
      await harness.pump(until: Self.waitTimeout) { Self.response(to: Self.agentRequestID, in: session) != nil }
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) == nil
      }

      let response = try #require(Self.response(to: Self.agentRequestID, in: session))
      #expect(response["result"] == (try Self.json(answer.expectedResult)))
      #expect(model.pendingElicitations.isEmpty)
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) == nil)
    }

    // MARK: - Request-scoped elicitation

    @Test func aLoginElicitationShowsInTheConnectionHostAndGoesAwayWhenTheLoginEnds() async throws {
      let elicitationID = Self.agentRequestID
      let session = try await ScriptedSession.open { agent in
        agent.results["initialize"] = Self.initializeResult
        agent.heldMethods = [Self.loginMethod]
        agent.leadIns[Self.loginMethod] = { request, _ in
          let loginID = request["id"]?.jsonString ?? "null"
          let params = #"""
            {"requestId": \#(loginID), "message": "Your code?", "mode": "form",
             "requestedSchema": {"type": "object", "properties": {"code": {"type": "string"}}}}
            """#
          return [ScriptedSession.requestFrame(Self.elicitationMethod, id: elicitationID, params: params)]
        }
      }
      defer { session.close() }
      let connection = session.connection
      let harness = HostedViewHarness(size: Self.size) {
        PendingRequestsHost(connection: connection)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }

      let login = Task {
        try await connection.login(LoginAuthRequest(methodId: AuthMethodId(rawValue: Self.authMethodID)))
      }
      await harness.pump(until: Self.waitTimeout) { !connection.pendingElicitations.isEmpty }
      let pending = try #require(connection.pendingElicitations.first)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ElicitationView.formIdentifier) != nil
      }
      #expect(pending.requestMethod == Self.loginMethod)
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) != nil)

      session.agent.releaseHeldAnswer()
      try await login.value
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) == nil
      }

      #expect(connection.pendingElicitations.isEmpty)
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) == nil)
      #expect(await waitUntil { Self.response(to: elicitationID, in: session) != nil })
      let response = try #require(Self.response(to: elicitationID, in: session))
      #expect(response["result"] == (try Self.json(#"{"action": "cancel"}"#)))
    }
  }
#endif
