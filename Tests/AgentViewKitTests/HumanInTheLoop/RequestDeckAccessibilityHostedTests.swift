@testable import AgentViewKit
import AgentViewKitTestSupport
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
    #expect(reporter.moves == [RequestDeck.identifier(for: permission.id.uuidString), StockPromptEditor.identifier])
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
    #expect(reporter.moves == [RequestDeck.identifier(for: permission.id.uuidString)])

    // Esc goes to the card with the keyboard focus, and the permission card
    // cancels its request.
    try harness.sendKey(.escape)
    let result = await session.result(ofRequest: Self.firstRequestID + 1)

    #expect(result == (try JSONValue(json: #"{"outcome": {"outcome": "cancelled"}}"#)))
    #expect(model.pendingElicitations.count == 1)
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
