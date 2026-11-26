import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The first frame at rest of a thread whose rows came into the list while
/// the rows moved (card ^7625j1b).
///
/// The test shows a ``MovingThread`` of ``answerCount`` agent answers, with
/// frames that the test steps by hand (``ManualFrames``). It first shows
/// each row at rest, so each row has the height of its real layout. Then
/// the rows move: the list moves up by ``jumpDistance``, and then by
/// ``lastStepDistance`` in the last step of the motion, so rows come into
/// the list also in that last step. Then the motion ends, and the list lays
/// out with no frame of the queue. No editor of a row that was static in
/// the motion becomes real before the first frame of the queue.
@MainActor @Suite struct TranscriptRestMountTests {
  /// The number of answers in the transcript: more than the rows in view.
  static let answerCount = 50

  /// The distance of the first move of the motion, in points: more than
  /// the list keeps around the rows in view, so the rows in view after it
  /// are rows that the list makes in the motion.
  static let jumpDistance: CGFloat = 1_200

  /// The distance of the last step of the motion, in points: more than the
  /// height of one row, so new rows come into the list in that step.
  static let lastStepDistance: CGFloat = 300

  /// The text of the answer at `index`.
  ///
  /// - Parameter index: The index of the answer.
  /// - Returns: The text.
  static func answer(_ index: Int) -> String {
    "Rest mount answer \(index): the parser reads each line of the file."
  }

  /// The frames of the queue of the list.
  let frames = ManualFrames()

  /// Shows each row at rest, moves the rows, brings new rows into the list
  /// in the last step of the motion, and then ends the motion.
  ///
  /// - Returns: The list at rest with no frame of the queue, and the number
  ///   of EditorKit text views of the list in the last step of the motion.
  func restAfterAMotion() async throws -> (thread: MovingThread, editorsInMotion: Int) {
    let thread = try MovingThread(
      session: .preview(transcript: (0..<Self.answerCount).map { .agent(Self.answer($0)) }), frames: frames)
    await thread.showEachRowAtRest()
    await thread.startMoving()
    thread.step(by: Self.jumpDistance, isLive: true)
    await thread.settle()
    thread.step(by: Self.lastStepDistance, isLive: true)
    let editorsInMotion = thread.textViewCount
    await thread.stopMoving()
    try #require(frames.isRunning, "no row waits in the queue at rest")
    return (thread, editorsInMotion)
  }

  /// A production change that fails this test: a row that was static in
  /// the motion shows its real form in the first layout at rest, outside
  /// the queue, so the rows in view mount their editors in one frame.
  @Test func noEditorBecomesRealAtRestBeforeTheFirstFrameOfTheQueue() async throws {
    let (thread, editorsInMotion) = try await restAfterAMotion()

    #expect(
      thread.textViewCount == editorsInMotion,
      "\(editorsInMotion) editors in the motion, \(thread.textViewCount) at rest")
  }

  /// A production change that fails this test: the rows that wait at rest
  /// do not take their turns, or a turn makes more than one editor real.
  @Test func theFirstFrameOfTheQueueMakesOneEditorReal() async throws {
    let (thread, editorsInMotion) = try await restAfterAMotion()

    frames.advance()
    thread.hosting.layoutSubtreeIfNeeded()

    #expect(thread.textViewCount == editorsInMotion + TranscriptRowMountQueue.editorSlotsPerFrame)
  }
}
