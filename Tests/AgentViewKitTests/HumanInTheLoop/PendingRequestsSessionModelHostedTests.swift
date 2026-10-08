#if DEBUG
  @testable import AgentViewKit
  import AgentViewKitTestSupport
  import AppKit
  import DemoSupport
  import Foundation
  import FoundationModelsACP
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The pending request cards over the client models (plan.md §3.2
  /// "Pending requests", §3.3 "Request-scoped elicitations", §11 decision 4).
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

    /// The comment that the reject tests send.
    static let comment = "Use the test file."

    /// The `allow_once` option of ``ScriptedSession/permissionParams``.
    static let allowOptionID = PermissionOptionId(rawValue: "yes")

    /// The `reject_once` option of ``ScriptedSession/permissionParams``.
    static let rejectOptionID = PermissionOptionId(rawValue: "no")

    /// The result that the agent receives for a cancelled permission request.
    static let cancelledPermissionResult = #"{"outcome": {"outcome": "cancelled"}}"#

    /// The result that the agent receives for a cancelled elicitation.
    static let cancelledElicitationResult = #"{"action": "cancel"}"#

    /// The method of a permission request.
    static let permissionMethod = "session/request_permission"

    /// The method of an elicitation request.
    static let elicitationMethod = "elicitation/create"

    /// The runs of the frame order test. Many runs find a race between the
    /// two frames. `@Test(arguments:)` reads the range outside the main actor.
    nonisolated static let frameOrderRuns = 1...100

    /// Decodes JSON text into an ACP JSON value.
    ///
    /// - Parameter text: The JSON text.
    /// - Returns: The value.
    static func json(_ text: String) throws -> JSONValue {
      try JSONDecoder().decode(JSONValue.self, from: Data(text.utf8))
    }

    /// The response frame that the agent received for the request with `id`.
    ///
    /// - Parameters:
    ///   - id: The JSON-RPC id of the request of the agent.
    ///   - session: The scripted session.
    /// - Returns: The frame, or `nil`.
    static func response(to id: Int, in session: ScriptedSession) -> JSONValue? {
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
        frame["method"]?.stringValue == ScriptedSession.promptMethod
          && ScriptedWireAgent.promptText(of: frame) == text
      }
    }

    /// Whether the transcript of `model` has a user message with `text`.
    ///
    /// - Parameters:
    ///   - text: The text of the message.
    ///   - model: The session model.
    /// - Returns: `true` when a user message entry has that text.
    static func transcriptHasUserMessage(withText text: String, in model: SessionModel) -> Bool {
      model.transcript.contains { entry in
        SessionTranscriptViewHostedTests.userMessage(entry).map {
          SessionTranscriptViewHostedTests.text(of: $0.content) == text
        } ?? false
      }
    }

    /// Watches the next change of the pending permissions of `model`.
    ///
    /// The change handler runs when the pending request goes away, before the
    /// change is done. It sets the flag when the transcript has no user message
    /// with `text` at that time, which shows that the answer came before the
    /// prompt. A prompt before the answer, or no change, leaves the flag clear.
    ///
    /// - Parameters:
    ///   - text: The text of the prompt that the answer comes before.
    ///   - model: The session model.
    /// - Returns: A flag that is not set yet.
    static func flagAnswerBeforePrompt(withText text: String, in model: SessionModel) -> ChangeFlag {
      ChangeFlag.observing {
        _ = model.pendingPermissions
      } when: {
        MainActor.assumeIsolated { !transcriptHasUserMessage(withText: text, in: model) }
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

      try harness.press(identifier: PermissionView.optionIdentifier(for: Self.allowOptionID))
      await harness.pump(until: Self.waitTimeout) { Self.response(to: Self.agentRequestID, in: session) != nil }
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) == nil
      }

      let response = try #require(Self.response(to: Self.agentRequestID, in: session))
      #expect(response["result"] == (try Self.json(#"{"outcome": {"outcome": "selected", "optionId": "yes"}}"#)))
      #expect(model.pendingPermissions.isEmpty)
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) == nil)
      #expect(session.agent.messages(method: ScriptedSession.promptMethod).isEmpty)
    }

    /// A reject with a comment answers the request, and then sends the comment
    /// as a prompt.
    ///
    /// The card calls `selectPermission(_:option:)` before `prompt(_:meta:)`.
    /// The test reads that order in the client model: when the pending request
    /// goes away, the transcript has no user message with the comment yet.
    ///
    /// ``anAnswerWithACommentWritesTheResponseFrameBeforeThePromptFrame(run:)``
    /// examines the order of the two frames on the wire.
    @Test func aRejectWithACommentAnswersTheRequestBeforeItSendsThePrompt() async throws {
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
      try harness.press(identifier: PermissionView.optionIdentifier(for: Self.rejectOptionID))
      harness.pump()
      #expect(harness.focusFirstEditableTextView(of: NSTextField.self))
      harness.type(Self.comment)
      let answeredBeforePrompt = Self.flagAnswerBeforePrompt(withText: Self.comment, in: model)
      try harness.press(identifier: PermissionView.commentSubmitIdentifier)
      await harness.pump(until: Self.waitTimeout) {
        Self.indexOfPrompt(withText: Self.comment, in: session.agent) != nil
      }
      await harness.pump(until: Self.waitTimeout) { Self.response(to: Self.agentRequestID, in: session) != nil }

      #expect(answeredBeforePrompt.value)
      #expect(Self.transcriptHasUserMessage(withText: Self.comment, in: model))
      let response = try #require(Self.response(to: Self.agentRequestID, in: session))
      #expect(response["result"] == (try Self.json(#"{"outcome": {"outcome": "selected", "optionId": "no"}}"#)))
      #expect(model.pendingPermissions.isEmpty)
    }

    /// An answer with a comment writes the permission response frame before
    /// the prompt frame of the comment.
    ///
    /// `SessionModel.answerPermission(_:option:comment:)` sends the prompt
    /// only after `selectPermission(_:option:)` returns, and that call
    /// returns after the client writes the response frame. The scripted agent
    /// records the frames in arrival order. The test runs many times to find
    /// a race, and it waits with the run loop, with no sleep.
    ///
    /// - Parameter run: The number of the run, for the failure message.
    @Test(arguments: frameOrderRuns)
    func anAnswerWithACommentWritesTheResponseFrameBeforeThePromptFrame(run: Int) async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let model = session.model
      let requestID = Double(Self.agentRequestID)

      let pendingID = try await session.sendPermissionRequest(
        id: Self.agentRequestID, pumping: harness, timeout: Self.waitTimeout)
      model.answerPermission(try #require(pendingID), option: Self.rejectOptionID, comment: Self.comment)
      await harness.pump(until: Self.waitTimeout) {
        Self.indexOfPrompt(withText: Self.comment, in: session.agent) != nil
          && session.agent.index(ofResponseTo: requestID) != nil
      }

      let answer = try #require(session.agent.index(ofResponseTo: requestID))
      let prompt = try #require(Self.indexOfPrompt(withText: Self.comment, in: session.agent))
      #expect(answer < prompt, "Run \(run): the prompt frame came before the response frame.")
    }

    @Test func aSelectThroughTheModelRemovesTheCard() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let pending = try await session.receivePermissionRequest(id: Self.agentRequestID)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) != nil
      }
      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) != nil)

      await session.model.selectPermission(pending.id, option: Self.allowOptionID)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: Self.cardIdentifier(pending.id)) == nil
      }

      #expect(harness.element(identifier: Self.cardIdentifier(pending.id)) == nil)
      #expect(harness.element(identifier: PermissionView.identifier) == nil)
      let result = await session.result(ofRequest: Self.agentRequestID)
      #expect(result == (try Self.json(#"{"outcome": {"outcome": "selected", "optionId": "yes"}}"#)))
    }

    @Test func cancelAllPendingOnTheModelRemovesTheShownCards() async throws {
      let session = try await ScriptedSession.open()
      defer { session.close() }
      let harness = Self.mount(session: session)
      defer { harness.close() }
      let elicitationRequestID = Self.agentRequestID + 1
      let permission = try await session.receivePermissionRequest(id: Self.agentRequestID)
      let elicitation = try await session.receiveElicitation(
        id: elicitationRequestID, params: ScriptedSession.formElicitationParams)
      let cards = [permission.id, elicitation.id].map(Self.cardIdentifier)
      await harness.pump(until: Self.waitTimeout) {
        cards.allSatisfy { harness.element(identifier: $0) != nil }
      }
      #expect(cards.allSatisfy { harness.element(identifier: $0) != nil })

      session.model.cancelAllPending()
      await harness.pump(until: Self.waitTimeout) {
        cards.allSatisfy { harness.element(identifier: $0) == nil }
      }

      #expect(cards.allSatisfy { harness.element(identifier: $0) == nil })
      #expect(await session.result(ofRequest: Self.agentRequestID) == (try Self.json(Self.cancelledPermissionResult)))
      #expect(
        await session.result(ofRequest: elicitationRequestID) == (try Self.json(Self.cancelledElicitationResult)))
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
      let session = try await ScriptedSession.openWithLoginElicitation(id: elicitationID)
      defer { session.close() }
      let connection = session.connection
      let harness = HostedViewHarness(size: Self.size) {
        PendingRequestsHost(connection: connection)
          .transaction { $0.disablesAnimations = true }
      }
      defer { harness.close() }

      let login = session.startLogin()
      await harness.pump(until: Self.waitTimeout) { !connection.pendingElicitations.isEmpty }
      let pending = try #require(connection.pendingElicitations.first)
      await harness.pump(until: Self.waitTimeout) {
        harness.element(identifier: ElicitationView.formIdentifier) != nil
      }
      #expect(pending.requestMethod == ScriptedSession.loginMethod)
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
