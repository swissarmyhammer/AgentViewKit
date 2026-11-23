import FoundationModelsACP
import FoundationModelsACPClient
import Testing

@testable import AgentViewKit

/// The index of the positions of the row keys of a transcript
/// (``TranscriptRowIndex``, task ^q1fy0n2, #scroll-perf).
///
/// The index must give the same positions as the linear lookup
/// (`position(ofRowKey:)`). It builds its dictionary again only after a
/// change of the transcript. In a debug build, the tests count the builds
/// with the ``BodyEvaluationCounter`` key of each session.
@MainActor @Suite struct TranscriptRowIndexTests {
  /// The raw message id of the agent message that each transcript of these
  /// tests holds (``TranscriptSearchTests/secondID``).
  private static let heldAgentID = "agent-1"

  /// The raw message id of the agent message that a test appends.
  private static let appendedID = "agent-2"

  /// The row key of the agent message that a test appends.
  private static let appendedRowKey = TranscriptSearchTests.rowKey(
    .agentMessage(MessageId(rawValue: appendedID)))

  /// The row key that no transcript of these tests holds.
  private static let missingRowKey = TranscriptSearchTests.rowKey(TranscriptSearchTests.missingID)

  /// A new session model of three entries.
  ///
  /// - Returns: The session model.
  private static func makeSession() -> SessionModel {
    TranscriptSearchTests.session()
  }

  /// Appends a new agent message to the transcript of a session.
  ///
  /// - Parameter session: The session model.
  private static func appendAgentMessage(to session: SessionModel) {
    session.apply(.agentMessageChunk(TranscriptSearchTests.chunk("A new answer.", id: appendedID)))
  }

  /// The positions that an index gives for row keys.
  ///
  /// - Parameters:
  ///   - keys: The row keys.
  ///   - index: The index.
  ///   - session: The session model whose transcript the index reads.
  /// - Returns: The position of each key, in the order of `keys`.
  private static func positions(
    of keys: [String], from index: TranscriptRowIndex, in session: SessionModel
  ) -> [Int?] {
    keys.map { index.position(ofRowKey: $0, in: session) }
  }

  // MARK: - Positions

  /// A production change that fails this test: the index stores the
  /// positions with an offset, or in the wrong order.
  @Test func theIndexGivesThePositionsOfTheLinearLookup() {
    let session = Self.makeSession()
    let index = TranscriptRowIndex()
    let keys = TranscriptSearchTests.rowKeys

    #expect(
      Self.positions(of: keys, from: index, in: session)
        == keys.map { session.transcript.position(ofRowKey: $0) })
  }

  /// A production change that fails this test: the index gives a default
  /// position for a key that it does not hold.
  @Test func theIndexGivesNilForAMissingRowKey() {
    let session = Self.makeSession()

    #expect(TranscriptRowIndex().position(ofRowKey: Self.missingRowKey, in: session) == nil)
  }

  /// A production change that fails this test: the index keeps its first
  /// dictionary after a change of the transcript.
  @Test func theIndexGivesThePositionOfAnEntryThatTheTranscriptAppended() {
    let session = Self.makeSession()
    let index = TranscriptRowIndex()
    _ = index.position(ofRowKey: Self.missingRowKey, in: session)

    Self.appendAgentMessage(to: session)

    #expect(
      index.position(ofRowKey: Self.appendedRowKey, in: session)
        == session.transcript.position(ofRowKey: Self.appendedRowKey))
  }

  /// A production change that fails this test: the index keeps the
  /// dictionary of the first session for a second session.
  @Test func theIndexGivesThePositionsOfANewSession() {
    let first = Self.makeSession()
    let second = Self.makeSession()
    Self.appendAgentMessage(to: second)
    let index = TranscriptRowIndex()
    _ = index.position(ofRowKey: Self.appendedRowKey, in: first)

    #expect(
      index.position(ofRowKey: Self.appendedRowKey, in: second)
        == second.transcript.position(ofRowKey: Self.appendedRowKey))
  }

  // MARK: - Builds

  #if DEBUG
    /// A new session model of three entries, with a build count of zero.
    ///
    /// - Returns: The session model.
    private static func makeCountedSession() -> SessionModel {
      let session = makeSession()
      BodyEvaluationCounter.reset(TranscriptRowIndex.counterKey(for: session))
      return session
    }

    /// The number of builds of the index for a session.
    ///
    /// - Parameter session: The session model.
    /// - Returns: The count.
    private static func buildCount(for session: SessionModel) -> Int {
      BodyEvaluationCounter.count(TranscriptRowIndex.counterKey(for: session))
    }

    /// A production change that fails this test: the index builds its
    /// dictionary for each lookup.
    @Test func manyLookupsBuildTheIndexOneTime() {
      let session = Self.makeCountedSession()
      let index = TranscriptRowIndex()
      let keys = TranscriptSearchTests.rowKeys

      _ = Self.positions(of: keys + keys, from: index, in: session)

      #expect(Self.buildCount(for: session) == 1)
    }

    /// A production change that fails this test: the index builds its
    /// dictionary again for a chunk of an entry that the transcript holds.
    /// The chunk changes the entry, not the transcript.
    @Test func aChunkOfAnEntryThatTheTranscriptHoldsDoesNotBuildTheIndexAgain() {
      let session = Self.makeCountedSession()
      let index = TranscriptRowIndex()
      _ = index.position(ofRowKey: Self.missingRowKey, in: session)

      session.apply(.agentMessageChunk(TranscriptSearchTests.chunk(" More text.", id: Self.heldAgentID)))
      _ = index.position(ofRowKey: Self.missingRowKey, in: session)

      #expect(Self.buildCount(for: session) == 1)
    }

    /// A production change that fails this test: the index builds its
    /// dictionary in the change callback of the transcript, and again on the
    /// next lookup.
    @Test func aChangeOfTheTranscriptBuildsTheIndexOneMoreTime() {
      let session = Self.makeCountedSession()
      let index = TranscriptRowIndex()
      _ = index.position(ofRowKey: Self.missingRowKey, in: session)

      Self.appendAgentMessage(to: session)
      _ = Self.positions(of: [Self.appendedRowKey, Self.missingRowKey], from: index, in: session)

      #expect(Self.buildCount(for: session) == 2)
    }
  #endif
}
