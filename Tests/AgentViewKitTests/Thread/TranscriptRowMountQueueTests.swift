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
  /// The number of frames of a long rest: 2 seconds at 120 Hz, more frames
  /// than a user waits before an interaction with a row.
  static let longRest = 240

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
    for _ in 0..<count {
      advance()
    }
  }
}

/// The queue that keeps the rows of a thread that wait at rest for an
/// interaction of the user (card ^7625j1b).
@MainActor @Suite struct TranscriptRowMountQueueTests {
  /// The number of rows of a test.
  static let rowCount = 3

  /// The position in ``mounts`` of the row that a test acts on.
  static let actedRow = 1

  /// The frames of the queue.
  let frames = ManualFrames()

  /// The queue, with the frames of the test.
  let queue: TranscriptRowMountQueue

  /// One mount for each row of a test, each in the queue.
  let mounts: [TranscriptRowMount]

  /// Makes a queue that holds one waiting mount for each of ``rowCount``
  /// rows.
  init() {
    queue = TranscriptRowMountQueue(frames: frames)
    mounts = (0..<Self.rowCount).map { _ in TranscriptRowMount() }
    for mount in mounts {
      queue.enqueue(mount)
    }
  }

  /// The mount of the row that a test acts on.
  var actedMount: TranscriptRowMount {
    mounts[Self.actedRow]
  }

  /// The mounts of the rows that a test does not act on.
  var otherMounts: [TranscriptRowMount] {
    mounts.enumerated().filter { $0.offset != Self.actedRow }.map(\.element)
  }

  /// A production change that fails this test: the queue makes the waiting
  /// rows real in the frames of a rest, so the rest hitches with no
  /// interaction of the user.
  @Test func aRowThatWaitsStillWaitsAfterTheFramesOfALongRest() {
    frames.advance(ManualFrames.longRest)

    #expect(mounts.allSatisfy { $0.waits })
  }

  /// A production change that fails this test: the queue runs the display
  /// link while a row waits, so the link fires at rest for no work.
  @Test func aRowThatWaitsRunsNoFrame() {
    #expect(!frames.isRunning)
  }

  /// A production change that fails this test: the queue does not run the
  /// work of the next frame, so the rows never come to rest after a live
  /// motion.
  @Test func theWorkOfTheNextFrameRunsInTheNextFrame() {
    var runs = 0
    queue.afterNextFrame { runs += 1 }

    frames.advance()

    #expect(runs == 1)
  }

  /// A production change that fails this test: the queue keeps the frames
  /// in run after the work of the next frame, so the display link fires
  /// for no work.
  @Test func theFramesStopAfterTheWorkOfTheNextFrame() {
    queue.afterNextFrame {}

    frames.advance()

    #expect(!frames.isRunning)
  }

  /// A production change that fails this test: an interaction with a row
  /// does not end its wait, so the row stays static.
  @Test func aReleaseEndsTheWaitOfTheRow() {
    queue.release(actedMount)

    #expect(!actedMount.waits)
  }

  /// A production change that fails this test: an interaction with one row
  /// ends the wait of each row, so each row in view mounts its editors.
  @Test func aReleaseKeepsTheWaitOfEachOtherRow() {
    queue.release(actedMount)

    #expect(otherMounts.allSatisfy { $0.waits })
  }

  /// A production change that fails this test: a jump session does not
  /// make each row in view real, so the jump labels stand on static text.
  @Test func mountAllEndsTheWaitOfEachRowInView() {
    queue.mountAll()

    #expect(mounts.allSatisfy { !$0.waits })
  }

  /// A production change that fails this test: a row that leaves the view
  /// stops to wait, so the list mounts its editors out of view.
  @Test func aRowThatLeavesTheViewKeepsItsWait() {
    queue.withdraw(actedMount)

    #expect(actedMount.waits)
  }

  /// A production change that fails this test: a row that left the view
  /// stays in the queue, so a jump session mounts its editors out of view.
  @Test func aRowThatLeftTheViewKeepsItsWaitInAJumpSession() {
    queue.withdraw(actedMount)

    queue.mountAll()

    #expect(actedMount.waits)
  }

  /// A production change that fails this test: a hold on a row that left
  /// the queue with its wait does not make the row real, so the row stays
  /// static for ever when the hold ends.
  @Test func aReleaseOfARowOutOfTheQueueEndsItsWait() {
    queue.withdraw(actedMount)

    queue.release(actedMount)

    #expect(!actedMount.waits)
  }

  /// A production change that fails this test: a row that comes into view
  /// while a jump session is open waits, so a jump target stands on
  /// static text.
  @Test func aRowThatComesIntoTheQueueInAJumpSessionIsReal() {
    let mount = TranscriptRowMount(waits: true)
    queue.mountAll()

    queue.enqueue(mount)

    #expect(!mount.waits)
  }

  /// A production change that fails this test: the end of a jump session
  /// does not end the real mounts, so the rows that come into view after
  /// it mount their editors with no interaction.
  @Test func aRowThatComesIntoTheQueueAfterAJumpSessionWaits() {
    let mount = TranscriptRowMount()
    queue.mountAll()
    queue.endMountAll()

    queue.enqueue(mount)

    #expect(mount.waits)
  }

  // MARK: - The form of a waiting row

  /// A production change that fails this test: a row that waits shows its
  /// real form at rest, so all rows mount in one frame.
  @Test func aRowThatWaitsIsStaticAtRest() {
    #expect(
      TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: true))
  }

  /// A production change that fails this test: the focus does not end the
  /// wait, so the focused row stays static.
  @Test func aFocusedRowThatWaitsIsRealAtOnce() {
    #expect(
      !TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(hasFocus: true), knowsHeight: true))
  }

  /// A production change that fails this test: a find hit in the text of a
  /// waiting row does not end the wait at rest, so the row shows no find
  /// mark in its text.
  @Test func aSearchTargetThatWaitsIsRealAtRest() {
    #expect(
      !TranscriptRowForm.isStatic(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(isSearchTarget: true), knowsHeight: true))
  }

  /// A production change that fails this test: a find hit keeps a row real
  /// while the rows move, so a flick through the hits mounts the editors
  /// of each hit.
  @Test func aSearchTargetIsStaticWhileTheRowsMove() {
    #expect(
      TranscriptRowForm.isStatic(
        rowsMove: true, waitsToMount: true, holds: TranscriptRowHolds(isSearchTarget: true), knowsHeight: true))
  }

  /// A production change that fails this test: a find hit that marks words
  /// does not make its row a search target.
  @Test func aHitWithTermsMakesTheRowASearchTarget() {
    #expect(TranscriptRowHolds.isSearchTarget(TranscriptSearchMark(terms: ["parser"], isCurrent: false)))
  }

  /// A production change that fails this test: a find hit that marks the
  /// whole entry, which the static form shows, mounts the editors of the
  /// row.
  @Test func aHitOnTheWholeEntryIsNoSearchTarget() {
    #expect(!TranscriptRowHolds.isSearchTarget(TranscriptSearchMark(terms: [], isCurrent: true)))
  }

  /// A production change that fails this test: the slots of a row that
  /// waits at rest take no press, so a click stays on the static form.
  @Test func theSlotsOfARowThatWaitsAtRestWait() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: true) == .waiting)
  }

  /// A production change that fails this test: a slot of a moving row
  /// takes the press of a waiting row while the rows move.
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
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(hasSelection: true), knowsHeight: true)
        == .real)
  }

  /// A production change that fails this test: the slots of a row with no
  /// known height do not show their editors at once.
  @Test func theSlotsOfARowWithNoKnownHeightAreReal() {
    #expect(
      TranscriptRowForm.slotForm(
        rowsMove: false, waitsToMount: true, holds: TranscriptRowHolds(), knowsHeight: false) == .real)
  }

  /// A production change that fails this test: a slot of a row that waits
  /// at rest shows its editor.
  @Test func aSlotOfARowThatWaitsShowsItsStillView() {
    #expect(TranscriptSlotForm.waiting.showsStill)
  }

  /// A production change that fails this test: a slot of a real row shows
  /// its still view.
  @Test func aSlotOfARealRowShowsItsEditor() {
    #expect(!TranscriptSlotForm.real.showsStill)
  }
}

/// One row in a host, with the queue that keeps its static form at rest
/// until an interaction of the user (card ^7625j1b).
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
  /// - Parameters:
  ///   - item: The transcript item of the row.
  ///   - search: The find hits of the thread, or `nil` (the default) for no
  ///     search.
  /// - Returns: The host, with the row at rest, and the number of EditorKit
  ///   text views of the real row.
  func restingRowThatEnteredWhileMoving(
    _ item: PreviewTranscriptItem = TranscriptStaticRowTests.plainAnswer, search: TranscriptSearch? = nil
  ) -> (host: StaticRowHost, realTextViews: Int) {
    let host = StaticRowHost(item, width: TranscriptStaticRowTests.widths[1])
    let realTextViews = host.textViewCount
    host.mounts = queue
    host.search = search
    host.enterWhileMoving()
    PendingRunLoopBlocks.run()
    host.show(rowsMove: false)
    return (host, realTextViews)
  }

  /// Presses the first still view of the row with an assistive app, and
  /// lays the row out again.
  ///
  /// - Parameter host: The host of the row.
  func pressTheStillText(in host: StaticRowHost) async throws {
    try await withAccessibilityTree {
      let still = try #require(host.accessibilityElements(identifiedAs: StaticSlotAccessibility.identifier).first)
      _ = try performAccessibilityPress(on: still)
    }
    host.layOut()
  }

  /// A production change that fails this test: the frames of a rest mount
  /// the editors of a row that entered while the rows moved, with no
  /// interaction of the user.
  @Test func aRowThatEnteredWhileMovingStaysStaticAfterALongRest() async {
    let (host, _) = restingRowThatEnteredWhileMoving()

    frames.advance(ManualFrames.longRest)
    host.layOut()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the still text of a row
  /// that waits at rest is no accessibility element, or a press of an
  /// assistive app on it does not make the row real.
  @Test func anAccessibilityPressOnTheStillTextOfARowThatWaitsMakesTheRowReal() async throws {
    let (host, _) = restingRowThatEnteredWhileMoving()

    try await pressTheStillText(in: host)

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: a row that waits at rest
  /// keeps its static form when its block expands, so the row shows the
  /// stale height and text of its static form.
  @Test func anExpansionOfARowThatWaitsAtRestMakesTheRowReal() async {
    let (host, _) = restingRowThatEnteredWhileMoving()

    host.store.toggle(entry: host.entry)
    host.layOut()

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: a find hit in the text of a
  /// row that waits at rest does not make the row real, so the row shows
  /// no find mark in its text.
  @Test func aFindHitInTheTextOfARowThatWaitsAtRestMakesTheRowReal() async throws {
    let search = TranscriptSearch()
    let (host, _) = restingRowThatEnteredWhileMoving(search: search)
    let id = try #require(host.entry.wireID, "the entry has no wire id")

    search.show(TranscriptSearchTests.hits([id]), in: host.session)
    host.layOut()

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: the press that mounts a
  /// waiting row changes its height, so the rows below it jump.
  @Test func aRowKeepsItsHeightWhenAPressMountsIt() async throws {
    let (host, _) = restingRowThatEnteredWhileMoving()
    let still = host.rowHeight

    try await pressTheStillText(in: host)
    host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - still) <= TranscriptStaticRowTests.heightTolerance)
  }

  /// A production change that fails this test: a press on one slot of a
  /// row mounts only that slot, so the other text areas of the row stay
  /// static.
  @Test func aPressOnAFencedRowShowsEachEditorOfTheRow() async throws {
    let (host, realTextViews) = restingRowThatEnteredWhileMoving(TranscriptRowFixtures.agentFenced)

    try await pressTheStillText(in: host)

    #expect(host.textViewCount == realTextViews)
  }
}
