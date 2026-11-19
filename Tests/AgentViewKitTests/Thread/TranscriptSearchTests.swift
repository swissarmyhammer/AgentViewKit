import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The search hits of a thread: the lookup of the entry of each hit, the
/// reveal of the best hit, and the mark of each row (D207 (f)).
@MainActor @Suite struct TranscriptSearchTests {
  /// The wire id of the first entry of the transcripts of these tests.
  static let firstID = SessionEntry.ID.userMessage(MessageId(rawValue: "user-1"))

  /// The wire id of the second entry.
  static let secondID = SessionEntry.ID.agentMessage(MessageId(rawValue: "agent-1"))

  /// The wire id of the third entry.
  static let thirdID = SessionEntry.ID.toolCall(ToolCallId(rawValue: "tool-1"))

  /// A wire id that no transcript of these tests holds.
  static let missingID = SessionEntry.ID.toolCall(ToolCallId(rawValue: "tool-missing"))

  /// The row keys of a transcript of the three entries, in order.
  static let rowKeys = [firstID, secondID, thirdID].map(rowKey)

  /// The row key of the entry with a wire id.
  ///
  /// - Parameter id: The wire id.
  /// - Returns: The row key.
  nonisolated static func rowKey(_ id: SessionEntry.ID) -> String {
    TranscriptEntry.ID.wire(id).rowKey
  }

  /// The wire id of an entry.
  ///
  /// - Parameter entry: The entry.
  /// - Returns: The wire id, or `nil` for an entry that the client made.
  static func wireID(of entry: TranscriptEntry) -> SessionEntry.ID? {
    if case .wire(let id) = entry.id { id } else { nil }
  }

  /// Hits with the matched word "parser", in the order of `ids`.
  ///
  /// - Parameter ids: The wire ids of the entries of the hits, best first.
  /// - Returns: The hits.
  static func hits(_ ids: [SessionEntry.ID]) -> TranscriptSearchHits {
    TranscriptSearchHits(ids.map { TranscriptSearchHit(entryID: $0, terms: ["parser"]) })
  }

  /// A search that shows `hits`, and that counts its beeps in `beeps`.
  ///
  /// - Parameters:
  ///   - hits: The hits, best first.
  ///   - rowKeys: The row keys of the transcript, in order.
  ///   - beeps: The count of the beeps of the search.
  /// - Returns: The search, with the first hit current.
  static func search(
    showing hits: TranscriptSearchHits, rowKeys: [String], beeps: CallCounter = CallCounter()
  ) -> TranscriptSearch {
    let search = TranscriptSearch()
    search.beep = { beeps.count += 1 }
    search.show(hits, rowKeys: rowKeys)
    return search
  }

  // MARK: - Lookup

  /// A production change that fails this test: the lookup reads the hits in
  /// the order of the transcript, and not best first.
  @Test func theLookupFindsTheRowOfEachHitBestFirst() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)

    #expect(search.hits.map(\.position) == [2, 0])
  }

  /// A production change that fails this test: the lookup does not use the
  /// row key of the wire id, so no entry of a model is found.
  @Test func theLookupFindsAnEntryOfASessionModel() throws {
    let session = SessionModel.preview(transcript: [.user("Why?"), .agent("The parser fails.")])
    let id = try #require(session.transcript.last.flatMap(Self.wireID))
    let search = TranscriptSearch()

    search.show(Self.hits([id]), rowKeys: session.transcript.map(\.rowKey))

    #expect(search.hits.map(\.position) == [1])
  }

  /// A production change that fails this test: a hit whose entry the model
  /// does not have stays in the hits.
  @Test func aWireIDThatTheModelDoesNotHaveIsSkipped() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.missingID, Self.secondID]), rowKeys: Self.rowKeys)

    #expect(search.hits.map(\.rowKey) == [Self.rowKey(Self.secondID)])
  }

  // MARK: - Reveal

  /// A production change that fails this test: the reveal goes to the first
  /// hit of the transcript, and not to the best hit.
  @Test func theRevealGoesToTheFirstHit() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)

    #expect(search.takeRevealRequest()?.rowKey == Self.rowKey(Self.thirdID))
  }

  /// A production change that fails this test: the first hit does not
  /// become current.
  @Test func theFirstHitBecomesCurrent() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)

    #expect(search.currentIndex == 0)
  }

  /// A production change that fails this test: the reveal goes to a hit
  /// whose entry the model does not have.
  @Test func theRevealSkipsAWireIDThatTheModelDoesNotHave() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.missingID, Self.secondID]), rowKeys: Self.rowKeys)

    #expect(search.takeRevealRequest()?.rowKey == Self.rowKey(Self.secondID))
  }

  /// A production change that fails this test: a view that mounts again
  /// reveals the hit again, and moves the list away from the place of the
  /// user.
  @Test func theRevealGoesOutOneTime() {
    let search = TranscriptSearch()
    search.show(Self.hits([Self.secondID]), rowKeys: Self.rowKeys)
    _ = search.takeRevealRequest()

    #expect(search.takeRevealRequest() == nil)
  }

  /// A production change that fails this test: hits that come before the
  /// transcript of the session never reveal.
  @Test func theRevealWaitsForTheEntryOfAHit() {
    let search = TranscriptSearch()
    search.show(Self.hits([Self.thirdID]), rowKeys: [])

    search.transcriptChanged(rowKeys: Self.rowKeys)

    #expect(search.takeRevealRequest()?.rowKey == Self.rowKey(Self.thirdID))
  }

  /// A production change that fails this test: each new entry of the
  /// transcript reveals the hit again.
  @Test func aNewEntryAfterTheRevealDoesNotRevealAgain() {
    let search = TranscriptSearch()
    search.show(Self.hits([Self.firstID]), rowKeys: Self.rowKeys)
    _ = search.takeRevealRequest()

    search.transcriptChanged(rowKeys: Self.rowKeys + [Self.rowKey(Self.missingID)])

    #expect(search.takeRevealRequest() == nil)
  }

  /// A production change that fails this test: the list does not load the
  /// earlier pages, so the reveal of a hit on a row that is not loaded does
  /// not find the row.
  @Test func theRevealOfARowThatIsNotLoadedLoadsItsPage() throws {
    let pageSize = 1
    let search = TranscriptSearch()
    search.show(Self.hits([Self.firstID]), rowKeys: Self.rowKeys)
    let target = try #require(search.takeRevealRequest())

    let pages = ConversationLayout.pageCount(
      forScrollTo: Self.rowKeys.firstIndex(of: target.rowKey), count: Self.rowKeys.count,
      pageSize: pageSize, shownPages: 1)

    #expect(pages == Self.rowKeys.count)
  }

  /// A production change that fails this test: a scroll to a row that the
  /// list shows takes away pages that the user loaded.
  @Test func aScrollToALoadedRowKeepsThePages() {
    let shownPages = 3

    let pages = ConversationLayout.pageCount(
      forScrollTo: 2, count: 3, pageSize: 1, shownPages: shownPages)

    #expect(pages == shownPages)
  }

  /// A production change that fails this test: a scroll to a row that the
  /// transcript does not hold changes the pages.
  @Test func aScrollToAnUnknownRowKeepsThePages() {
    #expect(
      ConversationLayout.pageCount(forScrollTo: nil, count: 3, pageSize: 1, shownPages: 2) == 2)
  }

  // MARK: - Marks

  /// A production change that fails this test: the current hit has no
  /// current mark.
  @Test func theMarkOfTheCurrentHitIsCurrent() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)

    #expect(
      search.mark(forRowKey: Self.rowKey(Self.thirdID))
        == TranscriptSearchMark(terms: ["parser"], isCurrent: true))
  }

  /// A production change that fails this test: each hit has the current
  /// mark.
  @Test func theMarkOfAnotherHitIsNotCurrent() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)

    #expect(
      search.mark(forRowKey: Self.rowKey(Self.firstID))
        == TranscriptSearchMark(terms: ["parser"], isCurrent: false))
  }

  /// A production change that fails this test: a row with no hit gets a
  /// mark.
  @Test func aRowWithNoHitHasNoMark() {
    let search = TranscriptSearch()

    search.show(Self.hits([Self.thirdID]), rowKeys: Self.rowKeys)

    #expect(search.mark(forRowKey: Self.rowKey(Self.secondID)) == nil)
  }

  /// A production change that fails this test: the hits stay after the
  /// host removes them.
  @Test func noHitsRemoveTheMarks() {
    let search = TranscriptSearch()
    search.show(Self.hits([Self.thirdID]), rowKeys: Self.rowKeys)

    search.show(nil, rowKeys: Self.rowKeys)

    #expect(search.mark(forRowKey: Self.rowKey(Self.thirdID)) == nil)
  }

  /// A production change that fails this test: a new current hit gets no
  /// reveal, so the next task cannot go to the next hit.
  @Test func aNewCurrentHitIsRevealed() {
    let search = TranscriptSearch()
    search.show(Self.hits([Self.thirdID, Self.firstID]), rowKeys: Self.rowKeys)
    _ = search.takeRevealRequest()

    search.makeCurrent(1)

    #expect(search.takeRevealRequest()?.rowKey == Self.rowKey(Self.firstID))
  }

  // MARK: - Open

  /// A production change that fails this test: a collapsed tool call that
  /// is the current hit stays closed, so its marks do not show.
  @Test func aCollapsedToolCallThatIsTheCurrentHitOpens() throws {
    let session = SessionModel.preview(transcript: [
      .toolCall(title: "Run the parser", kind: .execute, status: .completed)
    ])
    let entry = try #require(session.transcript.first)
    let search = TranscriptSearch()
    let store = ExpandedBlocksStore()
    search.show(
      Self.hits([try #require(Self.wireID(of: entry))]), rowKeys: session.transcript.map(\.rowKey))

    TranscriptSearchDriver.openCurrentHit(of: search, in: session.transcript, store: store)

    #expect(store.isExpanded(entry: entry))
  }

  /// A production change that fails this test: an entry that is not the
  /// current hit opens.
  @Test func aToolCallThatIsNotTheCurrentHitStaysClosed() throws {
    let session = SessionModel.preview(transcript: [
      .toolCall(title: "Run the parser", kind: .execute, status: .completed),
      .agent("The parser fails."),
    ])
    let toolCall = try #require(session.transcript.first)
    let answer = try #require(session.transcript.last)
    let search = TranscriptSearch()
    let store = ExpandedBlocksStore()
    search.show(
      Self.hits([try #require(Self.wireID(of: answer))]), rowKeys: session.transcript.map(\.rowKey))

    TranscriptSearchDriver.openCurrentHit(of: search, in: session.transcript, store: store)

    #expect(!store.isExpanded(entry: toolCall))
  }
}
