import AppKit
import EditorTestSupport
import SwiftUI
import Testing

@testable import AgentViewKit

/// A frame source that a test steps by hand: one call of ``advance()`` is
/// one frame of the display (card ^7625j1b).
///
/// The source has no clock. A frame comes only when the test calls
/// ``advance()``, and only while the queue runs the source.
@MainActor final class ManualFrames: TranscriptFrameSource {
  /// The step of each frame, while the source runs.
  private var step: (@MainActor () -> Void)?

  /// Whether the queue runs the source.
  var isRunning: Bool {
    step != nil
  }

  func start(_ step: @escaping @MainActor () -> Void) {
    self.step = step
  }

  func stop() {
    step = nil
  }

  func attach(to view: NSView) {}

  /// Gives one frame: the step runs one time, if the source runs.
  func advance() {
    step?()
  }
}

/// The queue that mounts the real rows of a thread a few at a time when
/// the rows come to rest (card ^7625j1b).
@MainActor @Suite struct TranscriptRowMountQueueTests {
  /// The distances of the rows of a test from the vertical center of the
  /// view, in points. They are not in order.
  static let distances: [CGFloat] = [300, 10, 150, 5, 80]

  /// The frames of the queue.
  let frames = ManualFrames()

  /// The queue, with the frames of the test.
  let queue: TranscriptRowMountQueue

  /// One waiting mount for each of ``distances``, in the same order.
  let mounts: [TranscriptRowMount]

  /// Makes a queue that holds one waiting mount for each of ``distances``,
  /// while the rows move.
  init() {
    queue = TranscriptRowMountQueue(frames: frames)
    queue.noteRowsMove(true)
    mounts = Self.distances.map { distance in
      let mount = TranscriptRowMount()
      mount.centerDistance = distance
      return mount
    }
    mounts.forEach(queue.enqueue)
  }

  /// The distances of the mounts that do not wait, in order.
  var mountedDistances: [CGFloat] {
    mounts.filter { !$0.waits }.map(\.centerDistance).sorted()
  }

  /// A production change that fails this test: the queue mounts all rows
  /// in the first frame at rest.
  @Test func afterOneFrameAtRestAtMostTwoRowsAreReal() {
    queue.noteRowsMove(false)

    frames.advance()

    #expect(mounts.count { !$0.waits } == TranscriptRowMountQueue.rowsPerFrame)
  }

  /// A production change that fails this test: the queue mounts the rows
  /// in the order of their arrival, and not from the center out.
  @Test func theRowsNearestTheCenterMountFirst() {
    queue.noteRowsMove(false)

    frames.advance()
    frames.advance()

    #expect(mountedDistances == [5, 10, 80, 150])
  }

  /// A production change that fails this test: the queue mounts a row while
  /// the rows still move.
  @Test func noRowMountsWhileTheRowsMove() {
    frames.advance()

    #expect(mounts.allSatisfy { $0.waits })
  }

  /// A production change that fails this test: a new motion does not stop
  /// the queue, so the rows mount while the list moves.
  @Test func aNewMotionStopsTheMounts() {
    queue.noteRowsMove(false)
    frames.advance()

    queue.noteRowsMove(true)
    frames.advance()

    #expect(mountedDistances == [5, 10])
  }

  /// A production change that fails this test: the rows that wait when a
  /// new motion starts never mount at the next rest.
  @Test func theNextRestMountsTheRowsThatStillWait() {
    queue.noteRowsMove(false)
    frames.advance()
    queue.noteRowsMove(true)

    queue.noteRowsMove(false)
    frames.advance()

    #expect(mountedDistances == [5, 10, 80, 150])
  }

  /// A production change that fails this test: the queue keeps the frame
  /// source in run after the last row mounts, so the display link fires
  /// for no work.
  @Test func theQueueStopsTheFramesWhenNoRowWaits() {
    queue.noteRowsMove(false)

    (0..<Self.distances.count).forEach { _ in frames.advance() }

    #expect(!frames.isRunning)
  }

  /// A production change that fails this test: a row that mounts at once
  /// still waits in the queue, and takes the turn of a different row.
  @Test func aRowThatMountsAtOnceTakesNoTurn() {
    queue.release(mounts[3])
    queue.noteRowsMove(false)

    frames.advance()

    #expect(mountedDistances == [5, 10, 80])
  }

  /// A production change that fails this test: a jump session does not
  /// mount each row, so the jump labels stand on static rows.
  @Test func mountAllMountsEachRowAtOnce() {
    queue.mountAll()

    #expect(mounts.allSatisfy { !$0.waits })
  }

  // MARK: - The form of a waiting row

  /// A production change that fails this test: a row that waits for its
  /// turn shows its real form at rest, so all rows mount in one frame.
  @Test func aRowThatWaitsIsStaticAtRest() {
    #expect(
      TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: true))
  }

  /// A production change that fails this test: the focus does not skip
  /// the queue, so the focused row waits for its turn.
  @Test func aFocusedRowThatWaitsIsRealAtOnce() {
    #expect(
      !TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(hasFocus: true), knowsHeight: true))
  }

  // MARK: - A row in a host

  /// Shows a row that entered while the rows moved, in a host with the
  /// queue of the test, and then shows it at rest.
  ///
  /// - Returns: The host, with the row at rest.
  func restingRowThatEnteredWhileMoving() async -> StaticRowHost {
    let host = StaticRowHost(TranscriptStaticRowTests.plainAnswer, width: TranscriptStaticRowTests.widths[1])
    host.mounts = queue
    host.enterWhileMoving()
    await RunLoopBlockFence.afterPendingBlocks()
    queue.noteRowsMove(false)
    host.show(rowsMove: false)
    return host
  }

  /// A production change that fails this test: a row that entered while
  /// the rows moved mounts its editors in the frame of the rest.
  @Test func aRowThatEnteredWhileMovingStaysStaticAtRestUntilItsTurn() async {
    let host = await restingRowThatEnteredWhileMoving()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the turn of a row in the
  /// queue does not mount its editors.
  @Test func aRowThatEnteredWhileMovingIsRealAfterItsTurn() async {
    let host = await restingRowThatEnteredWhileMoving()

    (0..<Self.distances.count).forEach { _ in frames.advance() }
    host.layOut()

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: the turn of a row changes
  /// its height, so the rows below it jump.
  @Test func aRowKeepsItsHeightWhenItsTurnMountsIt() async {
    let host = await restingRowThatEnteredWhileMoving()
    let still = host.rowHeight

    (0..<Self.distances.count).forEach { _ in frames.advance() }
    await host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - still) <= TranscriptStaticRowTests.heightTolerance)
  }
}
