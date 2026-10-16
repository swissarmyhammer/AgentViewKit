import Foundation
import Testing

@testable import AgentViewKit

/// The text, the identifiers and the announcements of the withdrawn request
/// notices of a ``RequestDeck`` (card 39a design section 3).
///
/// These tests call pure functions and need no window and no wait.
@Suite @MainActor struct RequestDeckWithdrawnTests {
  /// The title of the withdrawn request in these tests.
  static let title = "Your name?"

  /// The reason of the agent in these tests.
  static let reason = "The run ended."

  @Test func aReasonGivesTheTitleAndTheReason() {
    #expect(RequestDeck.withdrawnText(title: Self.title, reason: Self.reason) == "Your name? was withdrawn: The run ended.")
  }

  @Test func noReasonGivesOnlyTheTitle() {
    #expect(RequestDeck.withdrawnText(title: Self.title, reason: nil) == "Your name? was withdrawn.")
  }

  @Test func anEmptyReasonGivesOnlyTheTitle() {
    #expect(RequestDeck.withdrawnText(title: Self.title, reason: "") == "Your name? was withdrawn.")
  }

  @Test func theIdentifiersHaveThePrefixAndTheID() {
    let id = UUID()

    #expect(RequestDeck.identifier(forWithdrawn: id) == "request-deck-withdrawn-\(id.uuidString)")
    #expect(RequestDeck.dismissIdentifier(forWithdrawn: id) == "request-deck-withdrawn-dismiss-\(id.uuidString)")
  }

  @Test func onlyANewNoticeGivesAnAnnouncementInTheOrderOfTheList() {
    let kept = WithdrawnNotice(id: UUID(), text: "A was withdrawn.")
    let first = WithdrawnNotice(id: UUID(), text: "B was withdrawn.")
    let second = WithdrawnNotice(id: UUID(), text: "C was withdrawn.")

    let texts = RequestDeck.withdrawnAnnouncements(old: [kept], new: [kept, first, second])

    #expect(texts == ["B was withdrawn.", "C was withdrawn."])
  }

  @Test func aDismissedNoticeGivesNoAnnouncement() {
    let kept = WithdrawnNotice(id: UUID(), text: "A was withdrawn.")
    let dismissed = WithdrawnNotice(id: UUID(), text: "B was withdrawn.")

    #expect(RequestDeck.withdrawnAnnouncements(old: [kept, dismissed], new: [kept]).isEmpty)
  }
}
