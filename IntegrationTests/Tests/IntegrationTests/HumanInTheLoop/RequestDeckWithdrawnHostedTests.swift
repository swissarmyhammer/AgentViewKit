@testable import AgentViewKit
import AgentViewKitTestSupport
import EditorCommandsUI
import EditorStyle
import EditorTestSupport
import Foundation
import FoundationModelsACPClient
import SwiftUI
import Testing

/// The notices of the requests that the agent withdraws, in a ``RequestDeck``
/// in a window (card 39a design section 3, test plan 5C).
///
/// The agent sends the form elicitation of the scripted session, and then a
/// `$/cancel_request` frame for it
/// (``ScriptedSession/sendCancelRequest(id:reason:)``). The record of the
/// withdrawal comes into the model in a later main-actor step than the
/// removal of the request. Thus the test waits with
/// ``ObservationWait/until(_:)`` on the count of the records, which the frame
/// is certain to change, and then makes one render pass. A press of Dismiss is
/// followed by a synchronous check of the model, before any wait.
@Suite(.serialized, .hostedSerially) @MainActor struct RequestDeckWithdrawnHostedTests {
  /// The JSON-RPC id of the first request that the agent sends.
  static let firstRequestID = RequestDeckHostedTests.firstRequestID

  /// The reason that the agent gives for the withdrawal.
  static let reason = "The run ended."

  /// The notice of the withdrawn form elicitation of the scripted session,
  /// with ``reason``.
  static let noticeWithReason = "Your name? was withdrawn: The run ended."

  /// The announcement of the form elicitation of the scripted session.
  static let actionRequired = RecordingAnnouncer.Announcement(message: "Action required: Your name?", priority: .high)

  /// Sends the form elicitation of the scripted session, withdraws it, and
  /// waits until the session model holds the record of the withdrawal. Then
  /// one render pass shows the record.
  ///
  /// - Parameters:
  ///   - reason: The reason of the agent, or `nil` for no reason.
  ///   - session: The scripted session.
  ///   - harness: The harness that renders the view after each wait.
  /// - Returns: The record of the withdrawal.
  /// - Throws: The error of the transport, or an issue when the model holds
  ///   no record.
  static func sendAndWithdrawElicitation(
    reason: String?, to session: ScriptedSession, rendering harness: HostedViewHarness<some View>
  ) async throws -> WithdrawnRequest {
    let model = session.model
    try await session.sendInOrder([.formElicitation(id: firstRequestID)])
    harness.render()
    let before = model.withdrawnRequests.count
    try await session.sendCancelRequest(id: firstRequestID, reason: reason)
    await ObservationWait.until { model.withdrawnRequests.count == before + 1 }
    harness.render()
    return try #require(model.withdrawnRequests.last)
  }

  /// The label of the notice of a record.
  ///
  /// - Parameters:
  ///   - record: The record of the withdrawal.
  ///   - harness: The harness.
  /// - Returns: The label, or `nil` when the deck shows no notice for the
  ///   record.
  static func noticeLabel(of record: WithdrawnRequest, in harness: HostedViewHarness<some View>) -> String? {
    RequestDeckHostedTests.label(of: RequestDeck.identifier(forWithdrawn: record.id), in: harness)
  }

  @Test func aWithdrawnRequestShowsANoticeWithTheReasonAndAnnouncesItOneTime() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let reporter = RecordingFocusReporter()
    let harness = RequestDeckAccessibilityHostedTests.mountDeck(of: session, announcer: announcer, reporter: reporter)
    defer { harness.close() }

    let record = try await Self.sendAndWithdrawElicitation(reason: Self.reason, to: session, rendering: harness)

    #expect(Self.noticeLabel(of: record, in: harness) == Self.noticeWithReason)
    #expect(harness.element(identifier: RequestDeck.identifier(for: record.id.uuidString)) == nil)
    #expect(
      announcer.announcements == [
        Self.actionRequired, RecordingAnnouncer.Announcement(message: Self.noticeWithReason, priority: .medium),
      ])
    // The front request left, so the focus goes to the prompt editor, as
    // before. The notice takes no focus.
    #expect(reporter.moves == [EditorKitPromptEditor.identifier])
  }

  @Test func dismissRemovesTheNoticeAndGivesNoAnnouncementAndNoFocusMove() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let announcer = RecordingAnnouncer()
    let reporter = RecordingFocusReporter()
    let harness = RequestDeckAccessibilityHostedTests.mountDeck(of: session, announcer: announcer, reporter: reporter)
    defer { harness.close() }
    let record = try await Self.sendAndWithdrawElicitation(reason: Self.reason, to: session, rendering: harness)
    let announcements = announcer.announcements
    let moves = reporter.moves

    try harness.press(identifier: RequestDeck.dismissIdentifier(forWithdrawn: record.id))
    // The model removes the record in the same step as the press, so a press
    // that did not dismiss stops the test here.
    try #require(session.model.withdrawnRequests.isEmpty)
    harness.render()

    #expect(Self.noticeLabel(of: record, in: harness) == nil)
    #expect(announcer.announcements == announcements)
    #expect(reporter.moves == moves)
  }

  @Test func aWithdrawnRequestWithNoReasonShowsOnlyTheTitle() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = RequestDeckAccessibilityHostedTests.mountDeck(of: session)
    defer { harness.close() }

    let record = try await Self.sendAndWithdrawElicitation(reason: nil, to: session, rendering: harness)

    #expect(record.reason == nil)
    #expect(Self.noticeLabel(of: record, in: harness) == "Your name? was withdrawn.")
  }

  @Test func aNewRequestDoesNotRemoveTheNotice() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = RequestDeckAccessibilityHostedTests.mountDeck(of: session)
    defer { harness.close() }
    let record = try await Self.sendAndWithdrawElicitation(reason: Self.reason, to: session, rendering: harness)

    try await session.sendInOrder([.permission(id: Self.firstRequestID + 1)])
    harness.render()

    let permission = try #require(session.model.pendingPermissions.first)
    #expect(harness.element(identifier: RequestDeck.identifier(for: permission.id.uuidString)) != nil)
    #expect(Self.noticeLabel(of: record, in: harness) == Self.noticeWithReason)
  }

  /// A deck with only a notice has the deck padding around the notice. The
  /// notice has its own padding around its text and its Dismiss button. The
  /// frames have the origin at the bottom, so the top of a frame is its
  /// `maxY`.
  @Test func aDeckWithOnlyANoticeShowsTheNoticeInTheDeckPadding() async throws {
    let session = try await ScriptedSession.open()
    defer { session.close() }
    let harness = RequestDeckAccessibilityHostedTests.mountDeck(of: session)
    defer { harness.close() }
    let record = try await Self.sendAndWithdrawElicitation(reason: Self.reason, to: session, rendering: harness)
    try #require(session.model.pendingRequests.isEmpty)

    let deck = try #require(harness.frame(identifier: RequestDeck.identifier))
    let text = try #require(harness.frame(identifier: RequestDeck.identifier(forWithdrawn: record.id)))
    let dismiss = try #require(harness.frame(identifier: RequestDeck.dismissIdentifier(forWithdrawn: record.id)))

    // The deck pads its tiles by the tile margin, and the notice pads its
    // own content by the tile padding.
    let tile = EditorStyle.default.tile
    let insets = tile.margin + tile.padding
    // The bar centers its parts, so the taller of the text and the button
    // stands on the tile padding at each edge.
    #expect(deck.maxY - max(text.maxY, dismiss.maxY) == insets)
    #expect(min(text.minY, dismiss.minY) - deck.minY == insets)
  }

  @Test func aWithdrawnLoginElicitationShowsANoticeInTheConnectionDeckUntilDismiss() async throws {
    let session = try await ScriptedSession.openWithLoginElicitation(id: Self.firstRequestID)
    defer { session.close() }
    let connection = session.connection
    let announcer = RecordingAnnouncer()
    let harness = HostedViewHarness(size: RequestDeckAccessibilityHostedTests.size) {
      VStack {
        RequestDeck(connection: connection)
        Spacer()
      }
      .environment(\.announcer, announcer)
      .transaction { $0.disablesAnimations = true }
    }
    defer { harness.close() }
    harness.render()
    // The agent sends the elicitation before it holds its answer to the
    // login, so the elicitation is certain to come.
    let login = session.startLogin()
    await ObservationWait.until { !connection.pendingRequests.isEmpty }
    harness.render()

    try await session.sendCancelRequest(id: Self.firstRequestID, reason: Self.reason)
    await ObservationWait.until { !connection.withdrawnRequests.isEmpty }
    harness.render()
    let record = try #require(connection.withdrawnRequests.first)
    let notice = "Your code? was withdrawn: The run ended."
    #expect(Self.noticeLabel(of: record, in: harness) == notice)
    #expect(
      announcer.announcements == [
        RecordingAnnouncer.Announcement(message: "Action required: Your code?", priority: .high),
        RecordingAnnouncer.Announcement(message: notice, priority: .medium),
      ])

    try harness.press(identifier: RequestDeck.dismissIdentifier(forWithdrawn: record.id))
    // The connection model removes the record in the same step as the press.
    try #require(connection.withdrawnRequests.isEmpty)
    harness.render()
    #expect(Self.noticeLabel(of: record, in: harness) == nil)

    session.agent.releaseHeldAnswer()
    try await login.value
  }
}
