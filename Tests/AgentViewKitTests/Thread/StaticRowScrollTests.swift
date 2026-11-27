#if DEBUG
  import AppKit
  import FoundationModelsACPClient
  import SwiftUI
  import Testing

  @testable import AgentViewKit

  /// The static rows of a moving thread do no work on a scroll step that
  /// moves only the offset (card ^9ync5h3, #perf).
  ///
  /// The test shows a ``MovingThread`` of ``answerCount`` agent answers with
  /// the height cache of an ``AgentThreadView``
  /// (``MovingThread/makeCached(session:frames:)``), so the cache knows the
  /// height of each row before the motion. Then the rows move, and the list
  /// moves up by ``jumpDistance``: each row in view comes into the list in
  /// the motion, and shows its static form. No row in view was real at
  /// rest, so the rows that SwiftUI keeps from rest do not change the rows
  /// in view. Then the test moves the offset in ``stepCount`` steps.
  ///
  /// For each row in view at the start and at the end of the steps, the test
  /// counts the bodies of the static row (``TranscriptStaticRow``), the
  /// bodies of its static text (the picture of the text,
  /// ``StaticPictureView``, or its SwiftUI `Text`, ``StaticMarkdownText``)
  /// and the layouts of
  /// its frame (``TranscriptStaticRowFrame``). Each count stays at its value
  /// before the steps.
  @MainActor @Suite struct StaticRowScrollTests {
    /// The number of answers in the transcript: more than the rows in view.
    static let answerCount = 50

    /// The number of scroll steps while the rows move.
    static let stepCount = 30

    /// The distance of one scroll step while the rows move, in points. It
    /// has a fraction, as a step of a flick has.
    static let stepDistance: CGFloat = 2.3

    /// The distance of the first move of the motion, in points: more than
    /// the list makes around the rows in view at the bottom, so the rows in
    /// view after it are rows that the list makes in the motion.
    static let jumpDistance: CGFloat = 1_200

    /// The name of the answer texts of the suite
    /// (``AnswerText/answer(_:in:withCodeFence:)``). No other test uses it,
    /// so the counter key of each static text is the key of this test.
    static let textName = "staticScroll"

    /// The work counts of one row.
    struct RowCounts: Equatable, CustomStringConvertible {
      /// The bodies of the static row modifier (``TranscriptStaticRow``).
      let rowBodies: Int

      /// The bodies of the static text: its picture (``StaticPictureView``)
      /// and its SwiftUI `Text` (``StaticMarkdownText``). A row that was
      /// never static has none.
      let textBodies: Int

      /// The layouts of the frame of the row (``TranscriptStaticRowFrame``).
      let frameLayouts: Int

      var description: String {
        "\(rowBodies)/\(textBodies)/\(frameLayouts)"
      }
    }

    /// The counts of the row of the answer at `index`.
    ///
    /// - Parameters:
    ///   - index: The index of the answer in the transcript.
    ///   - session: The session of the list.
    /// - Returns: The counts.
    static func counts(ofAnswer index: Int, in session: SessionModel) -> RowCounts {
      let rowKey = session.transcript[index].rowKey
      let text = AnswerText.answer(index, in: textName)
      return RowCounts(
        rowBodies: BodyEvaluationCounter.count(TranscriptStaticRow.counterKey(for: rowKey)),
        textBodies: BodyEvaluationCounter.count(StaticPictureView.counterKey(for: text))
          + BodyEvaluationCounter.count(StaticMarkdownText.counterKey(for: text)),
        frameLayouts: BodyEvaluationCounter.count(TranscriptStaticRowFrame.counterKey(for: rowKey)))
    }

    /// The indices of the answers whose rows are in view.
    ///
    /// - Parameter thread: The list.
    /// - Returns: The indices in the transcript.
    static func answersInView(of thread: MovingThread) -> Set<Int> {
      let inView = thread.rowKeysInView
      return Set(thread.session.transcript.indices.filter { inView.contains(thread.session.transcript[$0].rowKey) })
    }

    /// A production change that fails this test: a value that each row
    /// observes changes on each scroll step, or the frame of a static row
    /// takes a new layout on each step, so SwiftUI lays out and draws the
    /// static text of each row in view again on each frame of a flick.
    @Test func aStaticRowInViewDoesNoWorkOnAStepOfTheOffset() async throws {
      let thread = try await MovingThread.makeCached(
        session: .preview(transcript: AnswerText.transcript(count: Self.answerCount, in: Self.textName)), frames: ManualFrames())
      thread.startMoving()
      thread.step(by: Self.jumpDistance, isLive: true)
      thread.settle()
      let atStart = Self.answersInView(of: thread)
      try #require(!atStart.isEmpty)
      let before = Dictionary(
        uniqueKeysWithValues: atStart.map { ($0, Self.counts(ofAnswer: $0, in: thread.session)) })
      // Each row in view came into the list in the motion: static.
      try #require(
        before.values.allSatisfy { $0.rowBodies > 0 && $0.textBodies > 0 && $0.frameLayouts > 0 },
        "rows \(atStart.sorted()): \(atStart.sorted().map { before[$0] })")

      for _ in 0..<Self.stepCount {
        thread.step(by: Self.stepDistance, isLive: true)
      }

      let staying = atStart.intersection(Self.answersInView(of: thread)).sorted()
      try #require(!staying.isEmpty)
      let after = staying.map { Self.counts(ofAnswer: $0, in: thread.session) }
      #expect(after == staying.map { before[$0] }, "rows \(staying): \(staying.map { before[$0] }) -> \(after)")
    }
  }
#endif
