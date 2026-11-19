import EditorTestSupport
import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// Find Next Hit and Find Previous Hit over the search hits of a thread:
/// the order of the transcript, the wrap with its beep, and the
/// announcement of the current hit (D207 (f)).
@MainActor @Suite struct TranscriptSearchStepTests {
  /// The wire id of the first entry of the transcript of these tests.
  static let firstID = TranscriptSearchTests.firstID

  /// The wire id of the second entry.
  static let secondID = TranscriptSearchTests.secondID

  /// The wire id of the third entry.
  static let thirdID = TranscriptSearchTests.thirdID

  /// The row keys of a transcript of the three entries, in order.
  static let rowKeys = TranscriptSearchTests.rowKeys

  /// A search with hits in `ids`, best first, that counts its beeps in
  /// `beeps`.
  ///
  /// - Parameters:
  ///   - ids: The wire ids of the entries of the hits, best first.
  ///   - beeps: The count of the beeps of the search.
  /// - Returns: The search, with the first hit current.
  static func search(
    _ ids: [SessionEntry.ID], beeps: CallCounter = CallCounter()
  ) -> TranscriptSearch {
    search(TranscriptSearchTests.hits(ids), beeps: beeps)
  }

  /// A search that shows `hits`, and that counts its beeps in `beeps`.
  ///
  /// - Parameters:
  ///   - hits: The hits, best first.
  ///   - beeps: The count of the beeps of the search.
  /// - Returns: The search, with the first hit current.
  static func search(
    _ hits: TranscriptSearchHits, beeps: CallCounter = CallCounter()
  ) -> TranscriptSearch {
    TranscriptSearchTests.search(showing: hits, rowKeys: rowKeys, beeps: beeps)
  }

  /// The row key of the entry with a wire id.
  ///
  /// - Parameter id: The wire id.
  /// - Returns: The row key.
  static func rowKey(_ id: SessionEntry.ID) -> String {
    TranscriptSearchTests.rowKey(id)
  }

  // MARK: - Order

  /// A production change that fails this test: Next goes to the next hit
  /// in the order of the hits (best first), and not of the transcript.
  @Test func nextGoesToTheNextHitInTheTranscript() {
    let search = Self.search([Self.secondID, Self.firstID, Self.thirdID])

    search.step(forward: true)

    #expect(search.currentHit?.rowKey == Self.rowKey(Self.thirdID))
  }

  /// A production change that fails this test: Previous goes to the
  /// previous hit in the order of the hits, and not of the transcript.
  @Test func previousGoesToThePreviousHitInTheTranscript() {
    let search = Self.search([Self.secondID, Self.thirdID, Self.firstID])

    search.step(forward: false)

    #expect(search.currentHit?.rowKey == Self.rowKey(Self.firstID))
  }

  /// A production change that fails this test: a step makes a hit current
  /// with no reveal, so the list does not scroll to it.
  @Test func aStepRevealsTheNewCurrentHit() {
    let search = Self.search([Self.firstID, Self.secondID])
    _ = search.takeRevealRequest()

    search.step(forward: true)

    #expect(search.takeRevealRequest()?.rowKey == Self.rowKey(Self.secondID))
  }

  /// A production change that fails this test: two hits in one entry are
  /// two stops, so Next stays on the same entry.
  @Test func twoHitsInOneEntryAreOneStop() {
    let search = Self.search(
      TranscriptSearchHits([
        TranscriptSearchHit(entryID: Self.firstID, terms: ["parser"]),
        TranscriptSearchHit(entryID: Self.firstID, terms: ["lexer"]),
        TranscriptSearchHit(entryID: Self.secondID, terms: ["parser"]),
      ]))

    search.step(forward: true)

    #expect(search.currentHit?.rowKey == Self.rowKey(Self.secondID))
  }

  // MARK: - Wrap

  /// A production change that fails this test: Next at the last hit of the
  /// transcript stays there.
  @Test func nextAtTheLastHitWrapsToTheFirstHit() {
    let search = Self.search([Self.thirdID, Self.firstID])

    search.step(forward: true)

    #expect(search.currentHit?.rowKey == Self.rowKey(Self.firstID))
  }

  /// A production change that fails this test: Previous at the first hit of
  /// the transcript stays there.
  @Test func previousAtTheFirstHitWrapsToTheLastHit() {
    let search = Self.search([Self.firstID, Self.thirdID])

    search.step(forward: false)

    #expect(search.currentHit?.rowKey == Self.rowKey(Self.thirdID))
  }

  /// A production change that fails this test: the wrap makes no sound.
  @Test func theWrapBeeps() {
    let beeps = CallCounter()
    let search = Self.search([Self.thirdID, Self.firstID], beeps: beeps)

    search.step(forward: true)

    #expect(beeps.count == 1)
  }

  /// A production change that fails this test: each step beeps.
  @Test func aStepThatDoesNotWrapDoesNotBeep() {
    let beeps = CallCounter()
    let search = Self.search([Self.firstID, Self.thirdID], beeps: beeps)

    search.step(forward: true)

    #expect(beeps.count == 0)
  }

  /// A production change that fails this test: a step with no hits makes a
  /// hit current, or beeps.
  @Test func aStepWithNoHitsDoesNothing() {
    let beeps = CallCounter()
    let search = Self.search([], beeps: beeps)

    search.step(forward: true)

    #expect(search.currentHit == nil && beeps.count == 0)
  }

  // MARK: - Place

  /// A production change that fails this test: the number of the current
  /// hit counts the hits best first, and not in the transcript.
  @Test func theNumberOfTheCurrentHitIsItsPlaceInTheTranscript() {
    let search = Self.search([Self.thirdID, Self.firstID, Self.secondID])

    #expect(search.currentHitNumber == 3)
  }

  /// A production change that fails this test: two hits in one entry count
  /// as two places.
  @Test func theHitCountCountsTheEntriesWithHits() {
    let search = Self.search(
      TranscriptSearchHits([
        TranscriptSearchHit(entryID: Self.firstID, terms: ["parser"]),
        TranscriptSearchHit(entryID: Self.firstID, terms: ["lexer"]),
        TranscriptSearchHit(entryID: Self.thirdID, terms: []),
      ]))

    #expect(search.hitCount == 2)
  }

  // MARK: - Announcement

  /// A production change that fails this test: the announcement does not
  /// tell the place of the hit or the author of its entry.
  @Test func theAnnouncementTellsThePlaceAndTheAuthor() {
    #expect(
      TranscriptSearchDriver.announcement(number: 2, count: 7, author: "You") == "Hit 2 of 7, You")
  }

  /// A production change that fails this test: the author of a user
  /// message is not the user.
  @Test func theAuthorOfAUserMessageIsTheUser() throws {
    let session = SessionModel.preview(transcript: [.user("Why does the parser fail?")])
    let entry = try #require(session.transcript.first)

    let author = TranscriptSearchDriver.author(of: entry, titles: SessionTitles())
    #expect(author == MessageRole.user.title)
  }

  /// A production change that fails this test: the author of a tool call
  /// is not the agent.
  @Test func theAuthorOfAToolCallIsTheAgent() throws {
    let session = SessionModel.preview(transcript: [
      .toolCall(title: "Run the parser", kind: .execute, status: .completed)
    ])
    let entry = try #require(session.transcript.first)

    let author = TranscriptSearchDriver.author(of: entry, titles: SessionTitles())
    #expect(author == MessageRole.assistant.title)
  }

  /// A production change that fails this test: the current hit posts no
  /// announcement, or posts it with the wrong place or author.
  @Test func theCurrentHitPostsItsAnnouncement() throws {
    let session = SessionModel.preview(transcript: [.user("Why?"), .agent("The parser fails.")])
    let ids = session.transcript.compactMap(TranscriptSearchTests.wireID)
    let search = TranscriptSearchTests.search(
      showing: TranscriptSearchTests.hits(ids.reversed()),
      rowKeys: session.transcript.map(\.rowKey))
    let announcer = RecordingAnnouncer()

    TranscriptSearchDriver.announceCurrentHit(
      of: search, in: session.transcript, titles: SessionTitles(), to: announcer)

    let expected = "Hit 2 of 2, \(MessageRole.assistant.title)"
    #expect(announcer.announcements.map(\.message) == [expected])
  }
}
