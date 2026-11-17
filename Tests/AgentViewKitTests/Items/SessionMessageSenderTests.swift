import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Tests for the sender line of a message from another session (AVK-15.5,
/// D199 (f)).
@Suite @MainActor struct SessionMessageSenderTests {
  /// The sender session of the tests.
  static let source = SessionId(rawValue: "01SOURCE")

  /// The recipient session of the tests.
  static let target = SessionId(rawValue: "01TARGET")

  /// A message with a sender of `kind`.
  static func message(_ kind: SAH.SessionMessage.Sender.Kind, title: String? = nil) -> SAH.SessionMessage {
    SAH.SessionMessage(sender: .init(kind: kind, sessionId: source, title: title))
  }

  @Test func aUserMessageNamesTheUserAndTheSessionOfTheUser() {
    let text = SessionMessageView.participantsText(
      sender: Self.source, recipient: Self.target, message: Self.message(.user, title: "Fix the parser"))

    #expect(text == "From the user, in Fix the parser")
  }

  @Test func aSessionMessageNamesTheSenderSession() {
    let text = SessionMessageView.participantsText(
      sender: Self.source, recipient: Self.target, message: Self.message(.session, title: "planner"))

    #expect(text == "From planner")
  }

  @Test func theHostTitleShowsWhenTheMetaHasNoTitle() {
    let titles = SessionTitles { $0 == Self.source ? "planner" : nil }

    let text = SessionMessageView.participantsText(
      sender: Self.source, recipient: Self.target, message: Self.message(.session), titles: titles)

    #expect(text == "From planner")
  }

  @Test func theMetaTitleWinsOverTheHostTitle() {
    let titles = SessionTitles { _ in "host title" }

    let text = SessionMessageView.participantsText(
      sender: Self.source, recipient: Self.target, message: Self.message(.session, title: "meta title"),
      titles: titles)

    #expect(text == "From meta title")
  }

  @Test func theRawIdShowsWhenNoTitleIsKnown() {
    let text = SessionMessageView.participantsText(
      sender: Self.source, recipient: Self.target, message: Self.message(.session))

    #expect(text == "From 01SOURCE")
  }

  @Test func withNoMetaTheLineNamesBothSessionsWithTheirHostTitles() {
    let titles = SessionTitles { $0 == Self.target ? "reviewer" : nil }

    let text = SessionMessageView.participantsText(sender: Self.source, recipient: Self.target, titles: titles)

    #expect(text == "From 01SOURCE to reviewer")
  }

  @Test func theSenderOfTheMetaComesFromTheEntryMeta() throws {
    let meta = try SAH.SessionMessage(sender: .init(kind: .user, sessionId: Self.source)).inject(into: nil)

    #expect(SessionMessageView.sender(in: meta)?.sender.kind == .user)
    #expect(SessionMessageView.sender(in: nil) == nil)
  }
}
