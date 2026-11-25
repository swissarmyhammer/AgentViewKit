import AgentViewKitTestSupport
import AppKit
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The status line of a modelChanged notice in the transcript
/// (``ModelChangePlacements``, ``ModelChangeNoticeView``).
///
/// The agent sends a notice of `kind` `modelChanged` when a resume moves a
/// session to a different model. The thread shows the notice as a status
/// line after the last message of the history, and not as a banner.
///
/// Each preview item gets the message id `preview-<position>`, from its
/// position in the list. The mounted tests put the thread in a borderless
/// window that is never ordered in: no window shows, and no window takes the
/// focus.
@MainActor @Suite struct ModelChangeNoticeTests {
  /// The title of the notice of the tests.
  static let title = "This session was recorded with model-a. It continues with model-b."

  /// The title of a second notice at the same place.
  static let secondTitle = "This session was recorded with model-b. It continues with model-c."

  /// The message id of the first preview item.
  static let firstId = "preview-0"

  /// The message id of the second preview item.
  static let secondId = "preview-1"

  /// The message id of the third preview item.
  static let thirdId = "preview-2"

  /// A notice item with `_meta` `kind` `modelChanged`.
  ///
  /// - Parameters:
  ///   - id: The raw `afterMessageId`, or `nil` for none.
  ///   - title: The title of the notice.
  /// - Returns: The session update of the notice.
  static func modelChange(after id: String?, title: String = title) -> PreviewTranscriptItem {
    var meta: [String: JSONValue] = [
      "kind": .string("modelChanged"), "recordedModel": .string("model-a"), "model": .string("model-b"),
    ]
    meta["afterMessageId"] = id.map(JSONValue.string)
    return .update(.notice(Notice(severity: .info, title: title, meta: .object(meta))))
  }

  /// A notice item with a `_meta` `kind` that is not `modelChanged`.
  static let otherKind = PreviewTranscriptItem.update(
    .notice(Notice(severity: .info, title: title, meta: .object(["kind": .string("quotaLow")]))))

  /// A notice item with no `_meta`.
  static let plainNotice = PreviewTranscriptItem.update(.notice(Notice(severity: .warning, title: "Quota low")))

  /// The placed status lines of a session.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The placements of the modelChanged notices of the session.
  static func placements(of session: SessionModel) -> ModelChangePlacements {
    ModelChangePlacements(notices: session.notices, transcript: session.transcript)
  }

  /// The titles of the status lines after the entry at `position`.
  ///
  /// - Parameters:
  ///   - position: The position of the entry in the transcript.
  ///   - session: The session model.
  /// - Returns: The titles, in the order of the lines.
  static func titles(after position: Int, in session: SessionModel) -> [String] {
    placements(of: session).lines(at: .after(session.transcript[position].id)).map(\.title)
  }

  /// The titles of the status lines before the first entry.
  ///
  /// - Parameter session: The session model.
  /// - Returns: The titles, in the order of the lines.
  static func titlesAtStart(of session: SessionModel) -> [String] {
    placements(of: session).lines(at: .start).map(\.title)
  }

  // MARK: - Place

  /// A production change that fails this test: the place reads only agent
  /// messages, so a notice after a user message has no place.
  @Test func aNoticeAfterAUserMessageIsPlacedAfterIt() {
    let session = SessionModel.preview(transcript: [.user("u1"), Self.modelChange(after: Self.firstId)])

    #expect(Self.titles(after: 0, in: session) == [Self.title])
  }

  /// A production change that fails this test: the place reads only user
  /// messages, so a notice after an agent message has no place.
  @Test func aNoticeAfterAnAgentMessageIsPlacedAfterIt() {
    let session = SessionModel.preview(transcript: [
      .user("u1"), .agent("a1"), Self.modelChange(after: Self.secondId),
    ])

    #expect(Self.titles(after: 1, in: session) == [Self.title])
  }

  /// A production change that fails this test: the place does not read
  /// thoughts, so a notice after a thought goes to the start.
  @Test func aNoticeAfterAThoughtIsPlacedAfterIt() {
    let session = SessionModel.preview(transcript: [
      .user("u1"), .thought("t1"), Self.modelChange(after: Self.secondId),
    ])

    #expect(Self.titles(after: 1, in: session) == [Self.title])
  }

  /// A production change that fails this test: a notice with no
  /// `afterMessageId` has no place, so it does not show.
  @Test func aNoticeWithNoAfterMessageIdIsPlacedAtTheStart() {
    let session = SessionModel.preview(transcript: [.user("u1"), Self.modelChange(after: nil)])

    #expect(Self.titlesAtStart(of: session) == [Self.title])
  }

  /// A production change that fails this test: a notice with an id that no
  /// entry has does not show.
  @Test func aNoticeWithAnUnknownIdIsPlacedAtTheStart() {
    let session = SessionModel.preview(transcript: [.user("u1"), Self.modelChange(after: "no-such-message")])

    #expect(Self.titlesAtStart(of: session) == [Self.title])
  }

  /// A production change that fails this test: the lines of one place are
  /// sorted by title, and not kept in arrival order.
  @Test func twoNoticesAtOnePlaceKeepTheirArrivalOrder() {
    let session = SessionModel.preview(transcript: [
      .agent("a1"), Self.modelChange(after: Self.firstId, title: Self.secondTitle),
      Self.modelChange(after: Self.firstId),
    ])

    #expect(Self.titles(after: 0, in: session) == [Self.secondTitle, Self.title])
  }

  /// A production change that fails this test: the placements read each
  /// notice, so a notice of another kind shows as a status line.
  @Test func aNoticeOfAnotherKindIsNotPlaced() {
    let session = SessionModel.preview(transcript: [.agent("a1"), Self.otherKind, Self.plainNotice])

    #expect(Self.placements(of: session).isEmpty)
  }

  // MARK: - Key

  /// A production change that fails this test: the key is the `UUID` of the
  /// `SessionNotice`, which a replay makes again.
  @Test func theKeyIsTheSameAfterAReplay() {
    let items: [PreviewTranscriptItem] = [.user("u1"), .agent("a1"), Self.modelChange(after: Self.secondId)]
    let first = SessionModel.preview(transcript: items)
    let replay = SessionModel.preview(transcript: items)

    let keys = [first, replay].map { session in
      Self.placements(of: session).lines(at: .after(session.transcript[1].id)).map(\.identifier)
    }

    #expect(keys[0] == keys[1] && !keys[0].isEmpty)
  }

  // MARK: - Mounted thread

  /// The accessibility identifiers of the rows and the status lines of a
  /// thread, in tree order.
  ///
  /// - Parameters:
  ///   - session: The session model of the thread.
  ///   - pageSize: The number of rows on one page of the conversation.
  /// - Returns: The identifiers that start with the row prefix or the status
  ///   line prefix.
  /// - Throws: An error when the window has no content view.
  static func rowIdentifiers(
    of session: SessionModel, pageSize: Int = ConversationLayout.defaultPageSize
  ) async throws -> [String] {
    let thread = AgentThreadView(session: session).conversationPageSize(pageSize).commandSystem(CommandSystem())
    let window = AnswerTextHitTests.mount(thread)
    let hosting = try #require(window.contentView)
    return await withAccessibilityTree {
      accessibilitySubtree(of: hosting).compactMap(accessibilityIdentifier(of:)).filter {
        $0.hasPrefix(ItemRow.identifierPrefix) || $0.hasPrefix(ModelChangeNoticeView.identifierPrefix)
      }
    }
  }

  /// A production change that fails this test: the conversation does not
  /// show the status lines, or shows them after the last row.
  @Test func theStatusLineStandsDirectlyAfterTheRowOfItsMessage() async throws {
    let session = SessionModel.preview(transcript: [
      .user("u1"), .agent("a1"), Self.modelChange(after: Self.secondId), .user("u2"),
    ])
    let line = try #require(Self.placements(of: session).lines(at: .after(session.transcript[1].id)).first)
    let rows = session.transcript.map { ItemRow.identifier(for: $0.rowKey) }

    let identifiers = try await Self.rowIdentifiers(of: session)

    #expect(identifiers == [rows[0], rows[1], line.identifier, rows[2]])
  }

  /// A production change that fails this test: the conversation does not
  /// show a status line that is placed before the first entry.
  @Test func aStatusLineAtTheStartStandsAboveTheFirstRow() async throws {
    let session = SessionModel.preview(transcript: [.user("u1"), Self.modelChange(after: nil), .agent("a1")])
    let line = try #require(Self.placements(of: session).lines(at: .start).first)
    let rows = session.transcript.map { ItemRow.identifier(for: $0.rowKey) }

    let identifiers = try await Self.rowIdentifiers(of: session)

    #expect(identifiers == [line.identifier] + rows)
  }

  /// A production change that fails this test: the conversation shows the
  /// status lines at the start above a later page, so a line of the history
  /// stands above rows that are not its first rows.
  @Test func aStatusLineAtTheStartWaitsForTheFirstPage() async throws {
    let session = SessionModel.preview(transcript: [.user("u1"), Self.modelChange(after: nil), .agent("a1")])
    let rows = session.transcript.map { ItemRow.identifier(for: $0.rowKey) }

    let identifiers = try await Self.rowIdentifiers(of: session, pageSize: 1)

    #expect(identifiers == [rows[1]])
  }

  // MARK: - Banner

  /// The number of accessibility elements of the banner of the first notice
  /// of a session.
  ///
  /// - Parameter session: The session model with one notice.
  /// - Returns: The number of elements with the identifier of the banner.
  /// - Throws: An error when the session has no notice, or the window has no
  ///   content view.
  static func bannerElementCount(of session: SessionModel) async throws -> Int {
    let notice = try #require(session.notices.first)
    let window = AnswerTextHitTests.mount(SessionNoticeBanner(session: session))
    let hosting = try #require(window.contentView)
    let identifier = SessionNoticeBanner.identifier(for: notice.id)
    return await withAccessibilityTree {
      accessibilityElements(identifiedAs: identifier, under: hosting).count
    }
  }

  /// A production change that fails this test: the banner shows each notice,
  /// so a modelChanged notice shows twice.
  @Test func theBannerShowsNoModelChangedNotice() async throws {
    let session = SessionModel.preview(transcript: [Self.modelChange(after: nil)])

    #expect(try await Self.bannerElementCount(of: session) == 0)
  }

  /// A production change that fails this test: the banner hides each notice
  /// with a `_meta`, or each notice.
  @Test func theBannerStillShowsAPlainNotice() async throws {
    let session = SessionModel.preview(transcript: [Self.plainNotice])

    #expect(try await Self.bannerElementCount(of: session) == 1)
  }

  // MARK: - Status line

  /// A production change that fails this test: the status line gets the
  /// Dismiss button of a banner.
  @Test func theStatusLineHasNoButton() async throws {
    let session = SessionModel.preview(transcript: [.agent("a1"), Self.modelChange(after: Self.firstId)])
    let line = try #require(Self.placements(of: session).lines(at: .after(session.transcript[0].id)).first)
    let window = AnswerTextHitTests.mount(ModelChangeNoticeView(line: line))
    let hosting = try #require(window.contentView)

    let (hasLine, buttonCount) = await withAccessibilityTree {
      let nodes = accessibilitySubtree(of: hosting)
      let buttons = nodes.filter { accessibilityRole(of: $0) == NSAccessibility.Role.button.rawValue }
      return (nodes.contains { accessibilityIdentifier(of: $0) == line.identifier }, buttons.count)
    }

    #expect(hasLine)
    #expect(buttonCount == 0)
  }
}
