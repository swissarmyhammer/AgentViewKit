import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The first frame at rest of a thread whose rows came into the list while
/// the rows moved (card ^7625j1b).
///
/// The test shows a ``MovingThread`` of ``answerCount`` agent answers with
/// the height cache of an ``AgentThreadView``
/// (``MovingThread/makeCached(session:frames:)``), and with frames that the
/// test steps by hand (``ManualFrames``). The cache knows the height of
/// each row before the motion, so the test does not show the rows at rest.
/// Then the rows move: the list moves up by ``jumpDistance``, and then by
/// ``lastStepDistance`` in the last step of the motion, so rows come into
/// the list also in that last step. Each row in view comes into the list in
/// the motion and shows its static form. Then the motion ends, and the list
/// lays out with no frame of the queue. No editor of a row that was static
/// in the motion becomes real before the first frame of the queue.
///
/// The test counts only the editors in view
/// (``MovingThread/textViewsInView``). The rows that the lazy stack keeps
/// out of view, and their number, change with the work on the main actor,
/// such as the work of other tests. A row that was real at rest stays real
/// in the motion (``TranscriptRowHolds/wasRealAtRest``), so such rows do
/// not decide the counts of the test.
@MainActor @Suite struct TranscriptRestMountTests {
  /// The number of answers in the transcript: more than the rows in view.
  static let answerCount = 50

  /// The distance of the first move of the motion, in points: more than
  /// the list makes around the rows in view at the bottom, so the rows in
  /// view after it are rows that the list makes in the motion.
  static let jumpDistance: CGFloat = 1_200

  /// The distance of the last step of the motion, in points: more than the
  /// height of one row, so new rows come into the list in that step.
  static let lastStepDistance: CGFloat = 300

  /// The name of the answer texts of the suite
  /// (``AnswerText/answer(_:in:withCodeFence:)``).
  static let textName = "restMount"

  /// The frames of the queue of the list.
  let frames = ManualFrames()

  /// Shows the list with the height cache at the bottom, moves the rows,
  /// brings new rows into the list in the last step of the motion, and
  /// then ends the motion.
  ///
  /// - Returns: The list at rest with no frame of the queue.
  func restAfterAMotion() async throws -> MovingThread {
    let thread = try await MovingThread.makeCached(
      session: .preview(transcript: AnswerText.transcript(count: Self.answerCount, in: Self.textName)), frames: frames)
    await thread.startMoving()
    thread.step(by: Self.jumpDistance, isLive: true)
    await thread.settle()
    thread.step(by: Self.lastStepDistance, isLive: true)
    try #require(thread.textViewsInView.isEmpty, "a row in view is real in the motion")
    await thread.stopMoving()
    try #require(frames.isRunning, "no row waits in the queue at rest")
    return thread
  }

  /// A production change that fails this test: a row that was static in
  /// the motion shows its real form in the first layout at rest, outside
  /// the queue, so the rows in view mount their editors in one frame.
  @Test func noEditorBecomesRealAtRestBeforeTheFirstFrameOfTheQueue() async throws {
    let thread = try await restAfterAMotion()

    #expect(thread.textViewsInView.isEmpty, "\(thread.textViewsInView.count) editors in view at rest")
  }

  /// A production change that fails this test: the rows that wait at rest
  /// do not take their turns, or a turn makes more than one editor real.
  @Test func theFirstFrameOfTheQueueMakesOneEditorReal() async throws {
    let thread = try await restAfterAMotion()

    frames.advance()
    thread.hosting.layoutSubtreeIfNeeded()

    #expect(thread.textViewsInView.count == TranscriptRowMountQueue.editorSlotsPerFrame)
  }
}
