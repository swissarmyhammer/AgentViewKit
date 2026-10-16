@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommands
import EditorCommandsUI
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The depth, the FIFO order, and the Previous and Next controls of a
/// ``RequestDeck`` in a window (deck design sections 2 and 3, test plan
/// row 36).
///
/// The scripted agent sends one form elicitation, and then permission
/// requests. A frame of the agent is followed by a wait for the count of the
/// pending requests, which the frame is certain to change. A press or a key
/// on the main actor is followed by one render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 640, height: 640)

  /// The JSON-RPC id of the first request that the agent sends. The next
  /// requests take the next ids.
  static let firstRequestID = 100

  /// The text that the typed-value test types into the form field.
  static let typedText = "Lovelace"

  /// Shows the deck of a session in the agent command scope of the session,
  /// with a command system.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - system: The command system of the window.
  /// - Returns: The harness.
  static func mount(session: ScriptedSession, system: CommandSystem) -> HostedViewHarness<some View> {
    HostedViewHarness(size: size) {
      VStack {
        RequestDeck(session: session.model)
        Spacer()
      }
      .agentCommandScope(session: session.model)
      .commandSystem(system)
      .transaction { $0.disablesAnimations = true }
    }
  }

  /// The path of the agent command scope of a session at the root of a
  /// window.
  ///
  /// - Parameter model: The session model.
  /// - Returns: The path.
  static func path(of model: SessionModel) -> FocusPath {
    .root(AgentCommandTarget.segment(for: model))
  }

  /// Sends `count` requests from the agent: first one form elicitation, then
  /// permission requests. Waits until the session model holds them all, and
  /// then makes `harness` show them.
  ///
  /// The client handles each request of the agent in its own task, so two
  /// requests sent together can come into the model in a different order.
  /// Thus the function sends a request only after the model holds the
  /// request before it, and the order of the model is the order of the ids.
  ///
  /// - Parameters:
  ///   - count: The number of requests, one or more.
  ///   - firstID: The JSON-RPC id of the first request.
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Throws: The error of the transport.
  static func sendRequests(
    _ count: Int, firstID: Int = firstRequestID, to session: ScriptedSession,
    rendering harness: HostedViewHarness<some View>
  ) async throws {
    let model = session.model
    let before = model.pendingRequests.count
    for offset in 0..<count {
      let isFirst = before == 0 && offset == 0
      try await session.sendRequest(
        isFirst ? ScriptedSession.elicitationMethod : ScriptedSession.permissionMethod,
        id: firstID + offset,
        params: isFirst ? ScriptedSession.formElicitationParams : ScriptedSession.permissionParams)
      await ObservationWait.until { model.pendingRequests.count == before + offset + 1 }
    }
    harness.render()
  }

  /// The label of the element with `identifier`.
  ///
  /// - Parameters:
  ///   - identifier: The accessibility identifier.
  ///   - harness: The harness.
  /// - Returns: The label, or `nil` when no element has the identifier.
  static func label(of identifier: String, in harness: HostedViewHarness<some View>) -> String? {
    harness.element(identifier: identifier)?.label
  }

  /// The identifier of the card container of a pending request.
  ///
  /// - Parameter request: The pending request.
  /// - Returns: The identifier `pending-card-<id>`.
  static func cardIdentifier(_ request: PendingRequest) -> String {
    RequestDeck.identifier(for: request.id.uuidString)
  }

  @Test func sixRequestsShowOneOfSixThreeEdgesAndPlusTwo() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }

    try await Self.sendRequests(6, to: session, rendering: harness)

    let requests = session.model.pendingRequests
    #expect(Self.label(of: RequestDeck.positionIdentifier, in: harness) == "1 of 6")
    #expect(Self.label(of: RequestDeck.moreIdentifier, in: harness) == "+2")
    let front = try #require(harness.frame(identifier: Self.cardIdentifier(requests[0])))
    for edge in requests[1...3] {
      let frame = try #require(harness.frame(identifier: Self.cardIdentifier(edge)))
      #expect(frame.maxY > front.maxY, "An edge card shows its top above the front card.")
    }
    for hidden in requests[4...5] {
      #expect(harness.element(identifier: Self.cardIdentifier(hidden)) == nil)
    }
  }

  @Test func nextAndThenTheNextKeyGiveTwoOfSixAndThenThreeOfSix() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    try await Self.sendRequests(6, to: session, rendering: harness)
    let model = session.model

    try harness.press(identifier: RequestDeck.nextIdentifier)
    #expect(Self.label(of: RequestDeck.positionIdentifier, in: harness) == "2 of 6")

    let key = try #require(AgentKeymap.defaultChords[.nextRequest])
    #expect(system.registry.performKey(key.asSequence, mode: .cua, at: Self.path(of: model)))
    harness.render()

    #expect(Self.label(of: RequestDeck.positionIdentifier, in: harness) == "3 of 6")
    #expect(model.frontRequest?.id == model.pendingRequests[2].id)
  }

  @Test func aTypedValueSurvivesNextAndPrevious() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    try await Self.sendRequests(3, to: session, rendering: harness)
    // The form field is the first editable text view: the cards behind are
    // permission cards, which show no text field until a reject option.
    #expect(harness.focusFirstEditableTextView())
    harness.type(Self.typedText)

    try harness.press(identifier: RequestDeck.nextIdentifier)
    try harness.press(identifier: RequestDeck.previousIdentifier)
    try harness.press(identifier: ElicitationView.submitIdentifier)
    let result = await session.result(ofRequest: Self.firstRequestID)

    let name = try #require(result?["content"]?["name"]?.stringValue)
    #expect(name.contains(Self.typedText))
  }

  @Test func anAnswerToTheFrontGivesOneOfFive() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    try await Self.sendRequests(6, to: session, rendering: harness)
    let model = session.model

    try harness.press(identifier: ElicitationView.submitIdentifier)
    await ObservationWait.until { model.pendingRequests.count == 5 }
    harness.render()

    #expect(Self.label(of: RequestDeck.positionIdentifier, in: harness) == "1 of 5")
  }

  @Test func oneRequestHasNoHeaderAndNoControlsAndTheVerbsAreNotAvailable() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    try await Self.sendRequests(1, to: session, rendering: harness)
    let path = Self.path(of: session.model)

    #expect(harness.element(identifier: RequestDeck.positionIdentifier) == nil)
    #expect(harness.element(identifier: RequestDeck.previousIdentifier) == nil)
    #expect(harness.element(identifier: RequestDeck.nextIdentifier) == nil)
    #expect(harness.element(identifier: RequestDeck.moreIdentifier) == nil)
    #expect(!system.registry.perform(AgentCommandVerb.previousRequest.id, at: path))
    #expect(!system.registry.perform(AgentCommandVerb.nextRequest.id, at: path))
  }

  @Test func aNewRequestDoesNotChangeTheFront() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = Self.mount(session: session, system: system)
    defer { harness.close() }
    try await Self.sendRequests(3, to: session, rendering: harness)
    let model = session.model
    try harness.press(identifier: RequestDeck.nextIdentifier)
    let front = try #require(model.frontRequest)

    try await Self.sendRequests(1, firstID: Self.firstRequestID + 3, to: session, rendering: harness)

    #expect(model.frontRequest?.id == front.id)
    #expect(Self.label(of: RequestDeck.positionIdentifier, in: harness) == "2 of 4")
  }
}
