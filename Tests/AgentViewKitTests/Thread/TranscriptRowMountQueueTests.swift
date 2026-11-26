import AppKit
import EditorTestSupport
import FoundationModelsACPClient
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

  /// Gives `count` frames.
  ///
  /// - Parameter count: The number of frames.
  func advance(_ count: Int) {
    (0..<count).forEach { _ in advance() }
  }
}

/// The queue that makes the editor slots of the rows of a thread real one
/// at a time when the rows come to rest (card ^7625j1b).
@MainActor @Suite struct TranscriptRowMountQueueTests {
  /// The distances of the rows of a test from the vertical center of the
  /// view, in points. They are not in order.
  static let distances: [CGFloat] = [300, 10, 150, 5, 80]

  /// The tops of the editor slots of each row of a test, in the coordinate
  /// space of the row, in points. They are not in order.
  static let slotTops: [CGFloat] = [40, 0, 20]

  /// The number of editor slots of all rows of a test.
  static let slotCount = distances.count * slotTops.count

  /// The position in ``distances`` of the row nearest the center.
  static let centerRow = 3

  /// The position in ``distances`` of the second row from the center.
  static let secondRow = 1

  /// The frames of the queue.
  let frames = ManualFrames()

  /// The queue, with the frames of the test.
  let queue: TranscriptRowMountQueue

  /// One waiting mount for each of ``distances``, in the same order.
  let mounts: [TranscriptRowMount]

  /// The editor slots of each of ``mounts``: one for each of ``slotTops``,
  /// in the same order.
  let slots: [[TranscriptSlotMount]]

  /// Makes a queue that holds one waiting mount for each of ``distances``,
  /// each with one editor slot for each of ``slotTops``, while the rows
  /// move.
  init() {
    queue = TranscriptRowMountQueue(frames: frames)
    queue.noteRowsMove(true)
    mounts = Self.distances.map { distance in
      let mount = TranscriptRowMount()
      mount.centerDistance = distance
      return mount
    }
    slots = mounts.map { mount in
      Self.slotTops.map { top in
        let slot = TranscriptSlotMount()
        slot.top = top
        mount.add(slot)
        return slot
      }
    }
    mounts.forEach(queue.enqueue)
  }

  /// The number of editor slots of all rows that do not wait.
  var realSlotCount: Int {
    slots.joined().count { !$0.waits }
  }

  /// The tops of the editor slots of the row at `row` that do not wait, in
  /// order.
  ///
  /// - Parameter row: The position of the row in ``distances``.
  /// - Returns: The tops, from the top of the row.
  func realTops(ofRow row: Int) -> [CGFloat] {
    slots[row].filter { !$0.waits }.map(\.top).sorted()
  }

  /// A production change that fails this test: the queue makes all editor
  /// slots of a row real in the same frame.
  @Test func afterOneFrameAtRestAtMostOneEditorSlotIsReal() {
    queue.noteRowsMove(false)

    frames.advance()

    #expect(realSlotCount == TranscriptRowMountQueue.editorSlotsPerFrame)
  }

  /// A production change that fails this test: the queue makes the slots
  /// real in the order of the arrival of their rows, and not from the
  /// center out.
  @Test func theFirstSlotIsInTheRowNearestTheCenter() {
    queue.noteRowsMove(false)

    frames.advance()

    #expect(realTops(ofRow: Self.centerRow) == [0])
  }

  /// A production change that fails this test: the slots of a row become
  /// real in the order of their arrival, and not from top to bottom.
  @Test func theSlotsOfARowBecomeRealFromTopToBottom() {
    queue.noteRowsMove(false)

    frames.advance(2)

    #expect(realTops(ofRow: Self.centerRow) == [0, 20])
  }

  /// A production change that fails this test: a row stops to wait when
  /// its first slot becomes real, so its frame takes its content height
  /// while its other slots are still static.
  @Test func aRowWithThreeSlotsStillWaitsAfterTwoFrames() {
    queue.noteRowsMove(false)

    frames.advance(2)

    #expect(mounts[Self.centerRow].waits)
  }

  /// A production change that fails this test: the row does not stop to
  /// wait when its last slot becomes real, so it keeps the frame of its
  /// static form.
  @Test func aRowWithThreeSlotsIsRealAfterThreeFrames() {
    queue.noteRowsMove(false)

    frames.advance(Self.slotTops.count)

    #expect(!mounts[Self.centerRow].waits)
  }

  /// A production change that fails this test: the queue goes to the next
  /// row before each slot of the row nearest the center is real.
  @Test func theNextSlotAfterAWholeRowIsInTheSecondRowFromTheCenter() {
    queue.noteRowsMove(false)

    frames.advance(Self.slotTops.count + 1)

    #expect(realTops(ofRow: Self.secondRow) == [0])
  }

  /// A production change that fails this test: the queue makes a slot real
  /// while the rows still move.
  @Test func noSlotBecomesRealWhileTheRowsMove() {
    frames.advance()

    #expect(realSlotCount == 0)
  }

  /// A production change that fails this test: a new motion does not stop
  /// the queue, so the editors mount while the list moves.
  @Test func aNewMotionStopsTheQueue() {
    queue.noteRowsMove(false)
    frames.advance()

    queue.noteRowsMove(true)
    frames.advance()

    #expect(realSlotCount == 1)
  }

  /// A production change that fails this test: the slots that wait when a
  /// new motion starts never become real at the next rest.
  @Test func theNextRestMakesTheSlotsThatStillWaitReal() {
    queue.noteRowsMove(false)
    frames.advance()
    queue.noteRowsMove(true)

    queue.noteRowsMove(false)
    frames.advance()

    #expect(realSlotCount == 2)
  }

  /// A production change that fails this test: the queue keeps the frame
  /// source in run after the last slot becomes real, so the display link
  /// fires for no work.
  @Test func theQueueStopsTheFramesWhenNoSlotWaits() {
    queue.noteRowsMove(false)

    frames.advance(Self.slotCount)

    #expect(!frames.isRunning)
  }

  /// A production change that fails this test: a row that leaves the queue
  /// at once, such as a row with a hold, keeps a slot that waits for its
  /// turn.
  @Test func aRowThatLeavesTheQueueMakesEachOfItsSlotsReal() {
    queue.release(mounts[Self.centerRow])

    #expect(slots[Self.centerRow].allSatisfy { !$0.waits })
  }

  /// A production change that fails this test: a row that leaves the queue
  /// at once still takes the turn of the next slot.
  @Test func aRowThatLeavesTheQueueTakesNoTurn() {
    queue.release(mounts[Self.centerRow])
    queue.noteRowsMove(false)

    frames.advance()

    #expect(realTops(ofRow: Self.secondRow) == [0])
  }

  /// A production change that fails this test: a row with no editor slot
  /// waits for ever, or takes the turn of an editor slot.
  @Test func aRowWithNoEditorSlotTakesNoTurn() {
    let empty = TranscriptRowMount()
    empty.centerDistance = 0
    queue.enqueue(empty)
    queue.noteRowsMove(false)

    frames.advance()

    #expect(realTops(ofRow: Self.centerRow) == [0])
  }

  /// A production change that fails this test: a slot that comes into a
  /// row that waits shows its editor at once.
  @Test func aSlotThatComesIntoAWaitingRowWaits() {
    let slot = TranscriptSlotMount()

    mounts[Self.centerRow].add(slot)

    #expect(slot.waits)
  }

  /// A production change that fails this test: a slot that shows again in
  /// its row, such as when it changes from its still view to its editor,
  /// waits again for a turn.
  @Test func aSlotWhoseTurnCameDoesNotWaitWhenItShowsAgain() {
    queue.noteRowsMove(false)
    frames.advance()
    let slot = slots[Self.centerRow][1]

    mounts[Self.centerRow].add(slot)

    #expect(!slot.waits)
  }

  /// A production change that fails this test: a jump session does not
  /// make each slot real, so the jump labels stand on static text.
  @Test func mountAllMakesEachSlotRealAtOnce() {
    queue.mountAll()

    #expect(realSlotCount == Self.slotCount)
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

  /// A production change that fails this test: the slots of a row that
  /// waits at rest do not take their own turns.
  @Test func theSlotsOfARowThatWaitsAtRestTakeTurns() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: true) == .inTurn)
  }

  /// A production change that fails this test: a slot of a moving row
  /// whose turn came shows its editor while the rows move.
  @Test func theSlotsOfAStaticRowThatMovesAreStill() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: true, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: true) == .still)
  }

  /// A production change that fails this test: a hold does not make each
  /// slot of the row real at once.
  @Test func theSlotsOfAHeldRowAreReal() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(isHovered: true), knowsHeight: true)
        == .real)
  }

  /// A production change that fails this test: the slots of a row with no
  /// known height do not show their editors at once.
  @Test func theSlotsOfARowWithNoKnownHeightAreReal() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: false) == .real)
  }

  /// A production change that fails this test: a slot that waits in a row
  /// that takes turns shows its editor.
  @Test func aSlotThatWaitsForItsTurnIsStill() {
    #expect(TranscriptSlotForm.inTurn.showsStill(slotWaits: true))
  }

  /// A production change that fails this test: a slot whose turn came
  /// stays static until each slot of its row is real.
  @Test func aSlotWhoseTurnCameIsReal() {
    #expect(!TranscriptSlotForm.inTurn.showsStill(slotWaits: false))
  }
}

/// One row in a host, with the queue that makes its editor slots real one
/// at a time at rest (card ^7625j1b).
@MainActor @Suite struct TranscriptRowMountQueueHostTests {
  /// The frames of the queue.
  let frames = ManualFrames()

  /// The queue, with the frames of the test.
  let queue: TranscriptRowMountQueue

  /// Makes an empty queue.
  init() {
    queue = TranscriptRowMountQueue(frames: frames)
  }

  /// Shows the row of `item` at rest, then as a row that enters while the
  /// rows move, in a host with the queue of the test, and then shows it at
  /// rest.
  ///
  /// - Parameter item: The transcript item of the row.
  /// - Returns: The host, with the row at rest, and the number of
  ///   EditorKit text views of the real row.
  func restingRowThatEnteredWhileMoving(
    _ item: PreviewTranscriptItem = TranscriptStaticRowTests.plainAnswer
  ) async -> (host: StaticRowHost, realTextViews: Int) {
    let host = StaticRowHost(item, width: TranscriptStaticRowTests.widths[1])
    let realTextViews = host.textViewCount
    host.mounts = queue
    queue.noteRowsMove(true)
    host.enterWhileMoving()
    await RunLoopBlockFence.afterPendingBlocks()
    queue.noteRowsMove(false)
    host.show(rowsMove: false)
    return (host, realTextViews)
  }

  /// Gives `count` frames, and lays the row out again.
  ///
  /// - Parameters:
  ///   - count: The number of frames.
  ///   - host: The host of the row.
  func advance(_ count: Int, in host: StaticRowHost) {
    frames.advance(count)
    host.layOut()
  }

  /// A production change that fails this test: a row that entered while
  /// the rows moved mounts its editors in the frame of the rest.
  @Test func aRowThatEnteredWhileMovingStaysStaticAtRestUntilItsTurn() async {
    let (host, _) = await restingRowThatEnteredWhileMoving()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the turn of a row in the
  /// queue does not mount its editors.
  @Test func aRowThatEnteredWhileMovingIsRealAfterItsTurn() async {
    let (host, _) = await restingRowThatEnteredWhileMoving()

    advance(1, in: host)

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: the turn of a row changes
  /// its height, so the rows below it jump.
  @Test func aRowKeepsItsHeightWhenItsTurnMountsIt() async {
    let (host, _) = await restingRowThatEnteredWhileMoving()
    let still = host.rowHeight

    advance(1, in: host)
    await host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - still) <= TranscriptStaticRowTests.heightTolerance)
  }

  /// A production change that fails this test: the queue mounts more than
  /// one editor of a row in one frame, or a slot whose turn came shows no
  /// editor.
  @Test(arguments: 1...2)
  func afterEachFrameOneMoreEditorOfAFencedRowIsReal(frameCount: Int) async {
    let (host, _) = await restingRowThatEnteredWhileMoving(TranscriptRowFixtures.agentFenced)

    advance(frameCount, in: host)

    #expect(host.textViewCount == frameCount)
  }

  /// A production change that fails this test: a row with one slot for
  /// each editor does not show each editor after the turns of its slots.
  @Test func aFencedRowShowsEachEditorAfterTheTurnsOfItsSlots() async {
    let (host, realTextViews) = await restingRowThatEnteredWhileMoving(TranscriptRowFixtures.agentFenced)

    advance(realTextViews, in: host)

    #expect(host.textViewCount == realTextViews)
  }

  /// A production change that fails this test: a row that is half static
  /// and half real takes the height of its content in place of the height
  /// of the cache, so the rows below it jump.
  @Test func aRowWithStaticAndRealSlotsHasTheCacheHeight() async throws {
    let (host, _) = await restingRowThatEnteredWhileMoving(TranscriptRowFixtures.agentFenced)
    let cacheHeight = try #require(host.heights.height(of: host.entry.id, width: host.width))

    advance(1, in: host)
    try #require(host.textViewCount == 1)

    #expect(abs(host.rowHeight - cacheHeight) <= TranscriptStaticRowTests.heightTolerance)
  }
}
