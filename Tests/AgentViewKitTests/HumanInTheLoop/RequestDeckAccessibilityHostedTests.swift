@testable import AgentViewKit
import AgentViewKitTestSupport
import AppKit
import Foundation
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The focus and the announcements of a ``RequestDeck`` in a window (deck
/// design section 4, test plan row 37).
///
/// The agent sends one form elicitation, and then permission requests
/// (``RequestDeckHostedTests/sendRequests(_:firstID:to:rendering:)``). A
/// frame of the agent is followed by a wait for the count of the pending
/// requests, which the frame is certain to change, and one render pass. The
/// render pass runs the change actions of the deck, which announce and move
/// the focus. An answer on the main actor is followed by one render pass.
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckAccessibilityHostedTests {
  /// The size of the window.
  static let size = CGSize(width: 640, height: 640)

  /// The JSON-RPC id of the first request that the agent sends: the form
  /// elicitation. The permission requests take the next ids.
  static let firstRequestID = RequestDeckHostedTests.firstRequestID

  /// Shows the deck of a session with `announcer` and `reporter`, and with
  /// no command scope, so that the keys go to the cards.
  ///
  /// - Parameters:
  ///   - session: The scripted session.
  ///   - announcer: The announcer of the environment.
  ///   - reporter: The focus reporter of the environment.
  /// - Returns: The harness, after one render pass.
  static func mountDeck(
    of session: ScriptedSession, announcer: RecordingAnnouncer = RecordingAnnouncer(),
    reporter: RecordingFocusReporter = RecordingFocusReporter()
  ) -> HostedViewHarness<some View> {
    let harness = HostedViewHarness(size: size) {
      VStack {
        RequestDeck(session: session.model)
        Spacer()
      }
      .environment(\.announcer, announcer)
      .environment(\.focusReporter, reporter)
      .transaction { $0.disablesAnimations = true }
    }
    harness.render()
    return harness
  }

  /// The action required announcements of the form elicitation and of the
  /// first permission request of a session, in the order of the deck.
  ///
  /// - Parameter model: The session model that holds the two requests.
  /// - Returns: The two announcements at the high priority.
  /// - Throws: An issue when the model holds no such request.
  static func actionRequired(in model: SessionModel) throws -> [RecordingAnnouncer.Announcement] {
    let elicitation = try #require(model.pendingElicitations.first)
    let permission = try #require(model.pendingPermissions.first)
    return [elicitation.request.message, permission.request.title].map {
      RecordingAnnouncer.Announcement(message: "Action required: \($0)", priority: .high)
    }
  }

  /// A URL consent elicitation with
  /// ``ElicitationURLConsentViewHostedTests/makeParams(url:)``. Its card has
  /// no editable text, so no text field can take Esc.
  ///
  /// - Parameter id: The JSON-RPC id of the request.
  /// - Returns: The request.
  static func urlConsent(id: Int) -> ScriptedSession.AgentRequest {
    ScriptedSession.AgentRequest(
      method: ScriptedSession.elicitationMethod, id: id, params: ElicitationURLConsentViewHostedTests.makeParams())
  }

  @Test func aNewRequestAnnouncesOneTimeAtTheHighPriorityAndMovesNoFocus() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let reporter = RecordingFocusReporter()
    let harness = Self.mountDeck(of: session, announcer: announcer, reporter: reporter)
    defer { harness.close() }

    try await RequestDeckHostedTests.sendRequests(1, to: session, rendering: harness)

    let elicitation = try #require(session.model.pendingElicitations.first)
    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Action required: \(elicitation.request.message)", priority: .high)
      ])
    #expect(reporter.moves.isEmpty)
  }

  @Test func anAnswerToTheFrontMovesTheFocusToTheNextCardAndThenToThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let harness = Self.mountDeck(of: session, reporter: reporter)
    defer { harness.close() }
    try await RequestDeckHostedTests.sendRequests(2, to: session, rendering: harness)
    let model = session.model
    let elicitation = try #require(model.pendingElicitations.first)
    let permission = try #require(model.pendingPermissions.first)
    #expect(reporter.moves.isEmpty)

    model.cancelElicitation(elicitation.id)
    harness.render()
    #expect(reporter.moves == [RequestDeck.identifier(for: permission.id.uuidString)])

    await model.cancelPermission(permission.id)
    harness.render()
    #expect(reporter.moves == [RequestDeck.identifier(for: permission.id.uuidString), EditorKitPromptEditor.identifier])
  }

  /// The accept of the only pending request keeps its card in the deck as a
  /// waiting card. The waiting card asks for no input, so the focus goes to
  /// the prompt editor while the waiting card shows.
  @Test func anAcceptOfTheOnlyURLRequestMovesTheFocusToThePromptEditorAndKeepsTheWaitingCard() async throws {
    let reporter = RecordingFocusReporter()
    let mounted = try await ElicitationURLConsentViewHostedTests.mountDeck(
      [ElicitationURLConsentViewHostedTests.urlRequest], reporter: reporter)
    defer { mounted.close() }
    let harness = mounted.harness
    try #require(reporter.moves.isEmpty)

    try harness.press(identifier: ElicitationURLConsentView.openIdentifier)
    // The press accepts the request in the same step, and the render pass
    // after it moves the focus. A press or a deck that broke stops the test
    // here, before the wait.
    try #require(mounted.session.model.pendingRequests.isEmpty)
    try #require(mounted.session.model.awaitingURLCompletions.count == 1)
    harness.render()
    try #require(reporter.moves.last == EditorKitPromptEditor.identifier)
    try #require(harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) != nil)
    await harness.render { mounted.browser.sessions.contains(where: \.isWaiting) }

    #expect(reporter.moves == [EditorKitPromptEditor.identifier])
    #expect(harness.element(identifier: ElicitationURLConsentView.waitingIdentifier) != nil)
  }

  @Test func theCardsBehindTheFrontAreNotInTheAccessibilityTree() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = Self.mountDeck(of: session)
    defer { harness.close() }

    try await RequestDeckHostedTests.sendRequests(3, to: session, rendering: harness)

    let requests = session.model.pendingRequests
    #expect(harness.element(identifier: RequestDeckHostedTests.cardIdentifier(requests[0])) != nil)
    for behind in requests.dropFirst() {
      #expect(harness.element(identifier: RequestDeckHostedTests.cardIdentifier(behind)) == nil)
    }
  }

  @Test func nextMovesTheFocusAndTheKeyboardFocusIntoTheNewFrontCard() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let reporter = RecordingFocusReporter()
    let harness = Self.mountDeck(of: session, reporter: reporter)
    defer { harness.close() }
    try await RequestDeckHostedTests.sendRequests(2, to: session, rendering: harness)
    let model = session.model
    let permission = try #require(model.pendingPermissions.first)

    try harness.press(identifier: RequestDeck.nextIdentifier)
    try #require(model.frontRequestID == permission.id)
    #expect(reporter.moves == [RequestDeck.identifier(for: permission.id.uuidString)])

    // Esc goes to the card with the keyboard focus, and the permission card
    // cancels its request in a task. No model state changes in the same step
    // as Esc, so the test requires the keyboard focus before Esc. When Next
    // moves no keyboard focus, the test stops here and does not wait.
    try harness.requireKeyboardFocusOutsideText()
    try harness.sendKey(.escape)
    let result = await session.result(ofRequest: Self.firstRequestID + 1)

    #expect(result == (try JSONValue(json: #"{"outcome": {"outcome": "cancelled"}}"#)))
    #expect(model.pendingElicitations.count == 1)
  }

  @Test func nextMovesTheKeyboardFocusIntoAnElicitationCardSoEscapeCancelsOnlyIt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let model = session.model
    let reporter = RecordingFocusReporter()
    let harness = Self.mountDeck(of: session, reporter: reporter)
    defer { harness.close() }
    // The permission request is at the front. The URL consent card has no
    // editable text, so no text field can take Esc, and its Esc action
    // cancels on the main actor.
    let elicitationRequestID = Self.firstRequestID + 1
    try await session.sendInOrder([.permission(id: Self.firstRequestID), Self.urlConsent(id: elicitationRequestID)])
    harness.render()
    let elicitation = try #require(model.pendingElicitations.first)

    try harness.press(identifier: RequestDeck.nextIdentifier)
    try #require(model.frontRequestID == elicitation.id)
    #expect(reporter.moves == [RequestDeck.identifier(for: elicitation.id.uuidString)])

    // Esc goes to the card with the keyboard focus. When no card has it, the
    // elicitation stays pending, and the test stops here and does not wait.
    try harness.sendKey(.escape)
    let result = try await session.resultOfAnsweredElicitation(ofRequest: elicitationRequestID)

    #expect(result == (try JSONValue(json: #"{"action": "cancel"}"#)))
    #expect(model.pendingPermissions.count == 1)
  }

  // The elicitation cards set no initial keyboard focus, and the kit gives a
  // new card no keyboard focus. AppKit decides the first keyboard focus of a
  // window. The two tests below show this: in a window with only the URL
  // consent card, a view of the card gets the keyboard focus, and Esc cancels
  // the request; a new card does not take the keyboard focus from a prompt
  // editor that has it.

  @Test func aURLConsentCardAloneInAWindowGetsTheKeyboardFocusSoEscapeCancelsIt() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    // The URL consent card has no editable text, so no text field can take
    // the first responder and send Esc up to the card. Its Esc action
    // cancels on the main actor.
    try await session.sendInOrder([Self.urlConsent(id: Self.firstRequestID)])
    let harness = Self.mountDeck(of: session)
    defer { harness.close() }

    // The keyboard focus is in the view of the window, and no text view or
    // field editor has it.
    try harness.requireKeyboardFocusOutsideText()

    try harness.sendKey(.escape)

    // Only the card with the keyboard focus cancels the request on Esc.
    let result = try await session.resultOfAnsweredElicitation(ofRequest: Self.firstRequestID)
    #expect(result == (try JSONValue(json: #"{"action": "cancel"}"#)))
  }

  @Test func aNewCardDoesNotTakeTheKeyboardFocusFromThePromptEditor() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = HostedViewHarness(size: Self.size) {
      VStack {
        RequestDeck(session: session.model)
        Spacer()
        PromptInputHost(model: PromptInputHostedTestModel())
      }
      .accessibilityFocusScope()
      .environment(\.sessionModel, session.model)
      .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    harness.render()
    let editor = try #require(harness.firstEditableTextView(of: NSTextView.self))
    try #require(harness.window.makeFirstResponder(editor))
    harness.render()

    try await RequestDeckHostedTests.sendRequests(1, to: session, rendering: harness)

    #expect(harness.element(identifier: ElicitationView.formIdentifier) != nil)
    #expect(harness.window.firstResponder === editor)
  }

  @Test func theThreadAndTheDeckWithTwoRequestsGiveExactlyTwoAnnouncements() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let harness = HostedViewHarness(size: Self.size) {
      ThreadAccessibilityHostedTests.threadAndDeck(of: session.model)
        .environment(\.announcer, announcer)
        .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    harness.render()

    try await RequestDeckHostedTests.sendRequests(2, to: session, rendering: harness)

    #expect(announcer.announcements == (try Self.actionRequired(in: session.model)))
  }
}
