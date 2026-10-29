@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import EditorCommands
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// Tests for the EditorKit navigation and jump on the items of a thread
/// (AVK-7d).
///
/// Each item scope (a message row, a tool call card, a request card) is a
/// target of the `nav.*` commands of EditorKit and of its jump mode. The host
/// registers the `nav.*` commands, as EditorKit tells. The tests register them
/// at the thread scope.
///
/// A change that the test makes on the main actor is followed by one render
/// pass. A frame of the agent is followed by a wait for the model value that
/// the frame is certain to change, and then by one render pass. Each key
/// press is followed by a `#require` on its result.
@Suite(.serialized, .hostedSerially) @MainActor struct AgentNavigationHostedTests {
  /// The JSON-RPC id of the first permission request of the deck test.
  static let frontRequestID = 100

  /// The JSON-RPC id of the second permission request of the deck test.
  static let edgeRequestID = 101

  /// The text that the state test types into the comment field of a card.
  static let commentText = "Not this file"

  /// Sends a user message and an agent message from the agent, waits until
  /// the transcript holds both, and then renders `harness`.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Returns: The paths of the two message scopes, in transcript order.
  /// - Throws: The error of the transport.
  static func sendTwoMessages(
    to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws -> [FocusPath] {
    try await AgentCommandScopeHostedTests.send(
      [
        .init(kind: "user_message_chunk", messageID: "nav-first", text: "First"),
        .init(kind: "agent_message_chunk", messageID: "nav-second", text: "Second"),
      ], to: session)
    let model = session.model
    await harness.render { model.transcript.count == 2 }
    let thread = AgentCommandScopeHostedTests.path(of: model)
    return model.transcript.map { thread.appending(AgentScopeKind.message(rowKey: $0.rowKey)) }
  }

  /// The item whose window rect holds the center of the first responder of
  /// the window.
  ///
  /// The center of the responder is in the window space of EditorKit (origin
  /// at the top left, y grows down), the space of the item rects.
  ///
  /// - Parameters:
  ///   - items: The item paths.
  ///   - system: The command system of the window.
  ///   - window: The window.
  /// - Returns: The path, or `nil` when no item holds the first responder.
  static func focusedItem(among items: [FocusPath], in system: CommandSystem, window: NSWindow) -> FocusPath? {
    guard let responder = window.firstResponder as? NSView,
      let frame = WindowSpace.rect(of: responder)
    else { return nil }
    let center = CGPoint(x: frame.midX, y: frame.midY)
    return items.first { system.geometry.rect(of: $0)?.contains(center) == true }
  }

  /// The first message of the transcript is at the top of the thread, so
  /// `nav.down` moves from it to the second message, and `nav.up` moves back.
  @Test func theNavChordsMoveTheFocusBetweenTwoMessageItems() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    let messages = try await Self.sendTwoMessages(to: session, rendering: harness)
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    registerNavCommands(controller: NavModeController(system: system), layer: thread, into: &system.registry)
    try #require(system.geometry.requestFocus(at: messages[0]))
    try #require(Self.focusedItem(among: messages, in: system, window: harness.window) == messages[0])

    try #require(system.registry.performKey(KeySequence(.downArrow), mode: .cua, at: messages[0]))
    #expect(Self.focusedItem(among: messages, in: system, window: harness.window) == messages[1])

    try #require(system.registry.performKey(KeySequence(.upArrow), mode: .cua, at: messages[1]))
    #expect(Self.focusedItem(among: messages, in: system, window: harness.window) == messages[0])
  }

  /// EditorKit stands the jump label of a scope at the centre of its frame,
  /// as a rect of no size.
  @Test func theJumpOverlayListsTheItemsOfTheThreadAtTheCentresOfTheirFrames() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    let messages = try await Self.sendTwoMessages(to: session, rendering: harness)
    let toolCall = try await AgentScopeSubjectHostedTests.sendScopeToolCall(to: session, rendering: harness)
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    let items = messages + [thread.appending(AgentScopeKind.toolCall(toolCall.toolCallId.rawValue))]
    let jump = JumpModeController(system: system)

    try #require(jump.activate(layer: thread))

    let chips = try #require(jump.overlayState?.chips)
    let anchors = Dictionary(uniqueKeysWithValues: chips.map { ($0.id, $0.anchor) })
    for item in items {
      let anchor = try #require(anchors[item])
      let frame = try #require(system.geometry.rect(of: item))
      #expect(!frame.isEmpty)
      #expect(anchor == CGRect(origin: CGPoint(x: frame.midX, y: frame.midY), size: .zero))
    }
  }

  @Test(arguments: [0, 1])
  func aJumpToAMessageFocusesThatMessage(position: Int) async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: false)
    defer { harness.close() }
    let messages = try await Self.sendTwoMessages(to: session, rendering: harness)
    let jump = JumpModeController(system: system)
    try #require(jump.activate(layer: AgentCommandScopeHostedTests.path(of: session.model)))

    try #require(jump.commit(messages[position]))

    #expect(Self.focusedItem(among: messages, in: system, window: harness.window) == messages[position])
  }

  /// The deck shows the first request whole, and only the top edge of the
  /// second. The second card is no jump target, because its label would be
  /// on a card that does not show.
  @Test func onlyTheDeckCardThatShowsWholeIsAJumpTarget() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    let cards = try await Self.sendDeckOfTwoPermissions(to: session, rendering: harness)
    let jump = JumpModeController(system: system)

    try #require(jump.activate(layer: AgentCommandScopeHostedTests.path(of: session.model)))

    let targets = Set(try #require(jump.overlayState?.chips).map(\.id))
    #expect(targets.contains(cards.front))
    #expect(!targets.contains(cards.edge))
  }

  /// The deck keeps the edge card mounted behind the front card, so a
  /// `nav.*` move must not land on it: the edge card is not in the
  /// navigation snapshot of the thread, and the front card is.
  @Test func anEdgeDeckCardIsNotInTheNavigationSnapshotOfTheThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    let cards = try await Self.sendDeckOfTwoPermissions(to: session, rendering: harness)

    let snapshot = system.geometry.snapshot(layer: AgentCommandScopeHostedTests.path(of: session.model))

    let scopes = Set(snapshot.scopes.map(\.path))
    #expect(scopes.contains(cards.front))
    #expect(!scopes.contains(cards.edge))
  }

  /// A card that goes behind the front card and comes back keeps its state:
  /// the text of its comment field. The targetable switch of the card
  /// changes with its role, and does not change the identity of the card.
  @Test func aDeckCardKeepsItsCommentTextWhenItGoesBehindAndComesBack() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: CommandSystem(), outerScope: true)
    defer { harness.close() }
    _ = try await Self.sendDeckOfTwoPermissions(to: session, rendering: harness)
    let reject = PermissionOptionId(rawValue: AgentCommandFixtures.rejectOptionID)
    try harness.press(identifier: PermissionView.optionIdentifier(for: reject))
    try SingleLineFieldChecks.type(Self.commentText, intoFieldWith: PermissionView.commentIdentifier, in: harness)

    try harness.press(identifier: RequestDeck.nextIdentifier)
    try #require(harness.element(identifier: PermissionView.commentIdentifier) == nil)
    try harness.press(identifier: RequestDeck.previousIdentifier)

    #expect(harness.element(identifier: PermissionView.commentIdentifier)?.value == Self.commentText)
  }

  /// The scope paths of the two cards of a deck of two permission requests.
  struct DeckCards {
    /// The path of the card that shows whole.
    let front: FocusPath

    /// The path of the card that shows only its top edge.
    let edge: FocusPath
  }

  /// Sends two permission requests from the agent, waits until the session
  /// model holds both, and then renders `harness`. The deck shows the first
  /// request whole, and only the top edge of the second.
  ///
  /// The deck is beside the thread view, so the harness must have the outer
  /// scope that puts the cards in the scope of the thread.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after the wait.
  /// - Returns: The scope paths of the two cards.
  /// - Throws: The error of the transport, or an issue when the model does
  ///   not hold two permission requests.
  static func sendDeckOfTwoPermissions(
    to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws -> DeckCards {
    try await session.sendInOrder([.permission(id: frontRequestID), .permission(id: edgeRequestID)])
    harness.render()
    let requests = session.model.pendingPermissions.map(\.id)
    try #require(requests.count == 2)
    let thread = AgentCommandScopeHostedTests.path(of: session.model)
    return DeckCards(
      front: thread.appending(AgentScopeKind.request(requests[0])),
      edge: thread.appending(AgentScopeKind.request(requests[1])))
  }

  /// A message row, a tool call card and the front request card each give
  /// the area of their content to the navigation snapshot of the thread.
  @Test func eachItemKindIsInTheNavigationSnapshotOfTheThread() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let system = CommandSystem()
    let harness = AgentCommandScopeHostedTests.mount(session: session, system: system, outerScope: true)
    defer { harness.close() }
    try await AgentCommandScopeHostedTests.sendScopeMessage(to: session, rendering: harness)
    let toolCall = try await AgentScopeSubjectHostedTests.sendScopeToolCall(to: session, rendering: harness)
    let request = try await session.sendPermissionRequest(
      id: Self.frontRequestID, rendering: harness)
    let message = try #require(model.transcript.first)
    let thread = AgentCommandScopeHostedTests.path(of: model)

    let scopes = Set(system.geometry.snapshot(layer: thread).scopes.map(\.path))

    #expect(scopes.contains(thread.appending(AgentScopeKind.message(rowKey: message.rowKey))))
    #expect(scopes.contains(thread.appending(AgentScopeKind.toolCall(toolCall.toolCallId.rawValue))))
    #expect(scopes.contains(thread.appending(AgentScopeKind.request(request))))
  }
}
