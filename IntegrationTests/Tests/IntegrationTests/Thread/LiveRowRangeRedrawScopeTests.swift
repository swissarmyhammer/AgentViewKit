#if DEBUG
  @testable import AgentViewKit
  import EditorTestSupport
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  /// The redraw scope of the responses of a thread when the live rows
  /// (``LiveRowRange``) move (task ^6w0xfxp).
  ///
  /// A move of the live rows changes the liveness of some rows only. A
  /// response whose liveness does not change must not evaluate its body
  /// again, so a scroll of a long thread evaluates only the rows that drop
  /// or make their editors.
  ///
  /// The test shows the rows in a `VStack`, as `LiveRowModelsTests` does,
  /// because a lazy stack evaluates only the rows near the view. The test
  /// reports the rows in view with ``LiveRowRange/noteVisible(positions:)``,
  /// the call that ``ConversationView`` makes when the list reports them.
  @Suite(.serialized, .hostedSerially) @MainActor struct LiveRowRangeRedrawScopeTests {
    /// The number of answers in the transcript. It is larger than the rows
    /// in view and the margins on both sides of them.
    static let answerCount = 60

    /// The number of rows in each report of the rows in view.
    static let visibleCount = 4

    /// The first row in view of the first report.
    static let firstReportStart = 20

    /// The first row in view of the second report. The rows in view move
    /// more than ``LiveRowRange/slack`` rows, so the live rows move.
    static let secondReportStart = firstReportStart + LiveRowRange.slack + visibleCount

    /// The size of the window of the harness.
    static let size = CGSize(width: 600, height: 1_200)

    /// The texts of a transcript of ``answerCount`` answers.
    static let answers = (0..<answerCount).map { "Answer \($0) with **bold** text." }

    /// The rows of each entry of `session`, with the environment that
    /// ``ConversationView`` gives them.
    ///
    /// - Parameters:
    ///   - session: The session.
    ///   - rows: The rows that keep their models.
    /// - Returns: The rows in a stack that keeps each row.
    static func rowsView(of session: SessionModel, rows: LiveRowRange) -> some View {
      VStack(spacing: 0) {
        ForEach(Array(session.transcript.enumerated()), id: \.element.id) { position, entry in
          ItemRow(entry: entry)
            .environment(\.transcriptRowPosition, position)
            .modifier(TranscriptRowLiveness(position: position))
        }
      }
      .environment(\.liveRowRange, rows)
      .environment(\.sessionModel, session)
      .threadTextSelection()
    }

    /// The ``BodyEvaluationCounter`` key of the response of each row.
    ///
    /// - Parameter session: The session. Each entry is an answer with one
    ///   text block.
    /// - Returns: The key of the response of each row, in the order of the
    ///   transcript.
    static func responseKeys(of session: SessionModel) -> [String] {
      session.transcript.map {
        ResponseView.counterKey(for: EntryContentView.blockID(entryID: $0.rowKey, index: 0))
      }
    }

    /// Sets the count of each key to zero.
    ///
    /// - Parameter keys: The ``BodyEvaluationCounter`` keys of the responses.
    static func resetCounts(of keys: [String]) {
      for key in keys {
        BodyEvaluationCounter.reset(key)
      }
    }

    /// The positions of the rows in view of a report that starts at `start`.
    ///
    /// - Parameter start: The first row in view.
    /// - Returns: The positions of the rows in view.
    static func visible(from start: Int) -> [Int] {
      Array(start..<(start + visibleCount))
    }

    /// A production change that fails this test: a response reads the live
    /// rows themselves, so each move of the live rows evaluates the body of
    /// each response.
    @Test func aMoveOfTheLiveRowsEvaluatesOnlyTheResponsesWhoseLivenessChanges() async throws {
      let session = SessionModel.preview(transcript: Self.answers.map { .agent($0) })
      let rows = LiveRowRange()
      let harness = HostedViewHarness(Self.rowsView(of: session, rows: rows), size: Self.size)
      defer { harness.close() }
      let keys = Self.responseKeys(of: session)
      try #require(keys.count == Self.answerCount)
      rows.noteVisible(positions: Self.visible(from: Self.firstReportStart))
      await harness.renderAfter { !rows.isLive(0) }
      let before = (0..<Self.answerCount).map { rows.isLive($0) }
      Self.resetCounts(of: keys)

      rows.noteVisible(positions: Self.visible(from: Self.secondReportStart))
      await harness.renderAfter { rows.isLive(Self.secondReportStart + LiveRowRange.margin) }

      let after = (0..<Self.answerCount).map { rows.isLive($0) }
      let flipped = Set((0..<Self.answerCount).filter { before[$0] != after[$0] })
      try #require(!flipped.isEmpty)
      try #require(flipped.count < Self.answerCount)
      for (position, key) in keys.enumerated() {
        let count = BodyEvaluationCounter.count(key)
        if flipped.contains(position) {
          #expect(count >= 1, "row \(position) changed its liveness")
        } else {
          #expect(count == 0, "row \(position) kept its liveness")
        }
      }
      Self.resetCounts(of: keys)
    }
  }
#endif
