import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The row under the mouse at the end of a live motion of the user (card
/// ^9ync5h3, card ^7625j1b).
///
/// At the end of a live motion, the rows take the hit test again, and
/// SwiftUI tells the row under a still mouse that the mouse is on it. That
/// row does not make its EditorKit editors real: it waits in the
/// ``TranscriptRowMountQueue`` for an interaction as each other row of the
/// motion waits. Each test shows one row of a fixture with two editor slots (its
/// text and its code fence) in a ``StaticRowHost``, with the height cache of
/// a thread and frames that the test steps by hand (``ManualFrames``).
@MainActor @Suite struct TranscriptHoverAtRestTests {
  /// The frames of the queue of the row.
  let frames = ManualFrames()

  /// The hover responder in the footer of the row.
  let probe = HoverResponderProbe()

  /// The row of a fixture with two editor slots, made in a live motion and
  /// then at rest, with a hover responder in its footer. The row waits in
  /// the queue for an interaction.
  ///
  /// - Returns: The host of the row.
  func waitingRowAtRest() async throws -> StaticRowHost {
    let host = await StaticRowHost.makeCached(.agentFenced, width: TranscriptStaticRowTests.widths[1], frames: frames)
    host.messageFooter = probe.footer
    host.show(rowsMove: true)
    host.show(rowsMove: false)
    try #require(host.textViewCount == 0, "the row is real at rest before an interaction")
    return host
  }

  /// A production change that fails this test: the mouse that comes on a
  /// row at the end of a live motion holds the row, so the row makes each
  /// of its editor slots real with no press.
  @Test func aMouseThatComesOnAWaitingRowAtRestMountsNoEditor() async throws {
    let host = try await waitingRowAtRest()

    try host.moveMouse(over: probe, moves: 1)
    host.layOut()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the frames of a rest mount
  /// the editors of the row under the mouse, so a hover that stays on a
  /// row mounts its editors with no press.
  @Test func theRowUnderTheMouseStaysStaticAfterALongRest() async throws {
    let host = try await waitingRowAtRest()
    try host.moveMouse(over: probe, moves: 1)

    frames.advance(ManualFrames.longRest)
    host.layOut()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the hover holds a row that
  /// waits in the queue at rest, so a hover mounts the editors of the row.
  @Test func theHoverDoesNotMakeAWaitingRowRealAtOnce() {
    #expect(
      TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(isHovered: true), knowsHeight: true))
  }
}

/// The end of a live motion of the user in a ``ConversationView`` (card
/// ^9ync5h3).
///
/// At the end of a live motion, the rows first take the hit test again,
/// and the rows keep their motion form. One frame later, the rows come to
/// rest and change their form. Thus the hover and the form change of the
/// rows never land in the same frame. A row that the list makes in the end
/// of the motion waits in the ``TranscriptRowMountQueue`` as a row of the
/// motion does. The tests step the frames by hand (``ManualFrames``).
///
/// EditorKit keeps the work of a text that it laid out before, so each
/// test shows texts of its own (``AnswerText/answer(_:in:withCodeFence:)``).
@MainActor @Suite struct TranscriptMotionEndTests {
  /// The number of answers in the transcript: more than the rows in view.
  static let answerCount = 50

  /// The distance of a short live step, in points: less than the height
  /// of the list, so the rows that were real at rest stay in view.
  static let shortStepDistance: CGFloat = 150

  /// The distance of the first move of the motion of a cached list, in
  /// points: more than the list makes around the rows in view at the
  /// bottom, so the rows in view after it are rows that the list makes in
  /// the motion.
  static let jumpDistance: CGFloat = 1_200

  /// The distance of the move in the end of the motion, in points: more
  /// than the height of one row, so new rows come into the list there.
  static let endMoveDistance: CGFloat = 300

  /// The frames of the queue of the list.
  let frames = ManualFrames()

  /// The form signal of the rows of the list.
  let probe = RowMotionProbe()

  /// Shows the list of the texts of a test at the bottom with a
  /// ``RowMotionProbe`` in the footer of each row, moves it in one short
  /// live step, and ends the live motion. The rows that were real at rest
  /// stay real and in view.
  ///
  /// - Parameter test: The name of the test (``AnswerText/answer(_:in:withCodeFence:)``).
  /// - Returns: The list in the first layout after the end of the motion.
  func endOfAShortLiveMotion(test: String) throws -> MovingThread {
    let answers = AnswerText.transcript(count: Self.answerCount, in: test)
    let thread = try MovingThread(session: .preview(transcript: answers), frames: frames, messageFooter: probe.footer)
    thread.settle()
    thread.startMoving()
    thread.step(by: Self.shortStepDistance, isLive: true)
    thread.settle()
    try #require(probe.rowsMove == true, "the rows do not move in the live motion")
    thread.stopMoving()
    return thread
  }

  /// A production change that fails this test: the rows change their form
  /// in the frame in which the live motion ends, so the hover of the rows
  /// and the form change of the rows land in one frame.
  @Test func theRowsKeepTheirMotionFormInTheFirstLayoutAfterALiveMotion() throws {
    _ = try endOfAShortLiveMotion(test: "endForm")

    #expect(probe.rowsMove == true)
  }

  /// A production change that fails this test: the rows take the hit test
  /// again only when they come to rest, one frame after the end of the
  /// live motion.
  @Test func theRowsTakeTheHitTestInTheFirstLayoutAfterALiveMotion() throws {
    let thread = try endOfAShortLiveMotion(test: "endHit")

    #expect(thread.hitReachesATextViewInView)
  }

  /// A production change that fails this test: the rows keep their motion
  /// form after the frame that follows the end of the live motion.
  @Test func theRowsComeToRestOneFrameAfterALiveMotion() throws {
    let thread = try endOfAShortLiveMotion(test: "endRest")

    frames.advance()
    thread.settle()

    #expect(probe.rowsMove == false)
  }

  /// A production change that fails this test: the frame after the end of
  /// a live motion brings the rows to rest also when a new live motion
  /// started before that frame.
  @Test func aNewLiveMotionBeforeTheNextFrameKeepsTheRowsMoving() throws {
    let thread = try endOfAShortLiveMotion(test: "endAgain")
    thread.startMoving()

    frames.advance()
    thread.settle()

    #expect(probe.rowsMove == true)
  }

  /// A production change that fails this test: the binding of the scroll
  /// position keeps the position of the first scroll to the bottom after a
  /// write of the scroll view, so the evaluation of the list at the end of
  /// a live motion gives the scroll view that old position again, and the
  /// list goes back to the bottom.
  @Test func theEndOfALiveMotionKeepsTheOffsetOfTheList() async throws {
    let answers = AnswerText.transcript(count: Self.answerCount, in: "endOffset")
    let thread = try await MovingThread.makeCached(session: .preview(transcript: answers), frames: frames)
    thread.startMoving()
    thread.step(by: Self.jumpDistance, isLive: true)
    thread.settle()
    let offsetInMotion = thread.scrollView.contentView.bounds.origin.y

    thread.stopMoving()

    #expect(thread.scrollView.contentView.bounds.origin.y == offsetInMotion)
  }

  /// A production change that fails this test: a row that the list makes
  /// in the end of a live motion does not wait in the queue, so it makes
  /// each of its editors real at rest in one frame.
  @Test func aRowThatTheListMakesInTheEndOfALiveMotionWaits() async throws {
    let answers = AnswerText.transcript(count: Self.answerCount, in: "endRows")
    let thread = try await MovingThread.makeCached(session: .preview(transcript: answers), frames: frames)
    thread.startMoving()
    thread.step(by: Self.jumpDistance, isLive: true)
    thread.settle()
    let inMotion = thread.rowKeysInView
    try #require(thread.textViewsInView.isEmpty, "a row in view is real in the motion")

    thread.stopMoving(afterMovingBy: Self.endMoveDistance)
    frames.advance()
    thread.settle()

    try #require(!thread.rowKeysInView.isSubset(of: inMotion), "no new row came into view in the end of the motion")
    #expect(thread.textViewsInView.isEmpty, "\(thread.textViewsInView.count) editors in view at rest")
  }

  /// A production change that fails this test: a row that the list makes
  /// after the live motion ended and before the rows come to rest, such as
  /// a row of the last offset of the motion, does not wait in the queue,
  /// so it makes each of its editors real at rest in one frame.
  @Test func aRowThatTheListMakesBeforeTheRowsComeToRestWaits() async throws {
    let answers = AnswerText.transcript(count: Self.answerCount, in: "endFrameRows")
    let thread = try await MovingThread.makeCached(session: .preview(transcript: answers), frames: frames)
    thread.startMoving()
    thread.step(by: Self.jumpDistance, isLive: true)
    thread.settle()
    try #require(thread.textViewsInView.isEmpty, "a row in view is real in the motion")
    thread.stopMoving()
    let atTheEnd = thread.rowKeysInView

    thread.step(by: Self.endMoveDistance, isLive: false)
    thread.settle()
    frames.advance()
    thread.settle()

    try #require(!thread.rowKeysInView.isSubset(of: atTheEnd), "no new row came into view before the rest")
    #expect(thread.textViewsInView.isEmpty, "\(thread.textViewsInView.count) editors in view at rest")
  }
}
