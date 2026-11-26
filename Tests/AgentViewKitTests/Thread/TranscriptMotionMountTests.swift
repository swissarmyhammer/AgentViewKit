import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The EditorKit editors that the rows of a thread mount in a flick, at its
/// end, and after a jump at rest (card ^7625j1b).
///
/// The tests show a ``MovingThread`` of agent answers at the first row, with frames that the test steps by hand (``ManualFrames``).
/// Each answer has a code fence, which the height cache does not measure
/// exactly, so a row that the list did not show real yet has no known
/// height: it shows its real form also while the rows move. The flick moves
/// the list down by ``stepDistance`` in each of ``stepCount`` live steps.
///
/// EditorKit keeps the work of a text that it laid out before, so a row of
/// a text that a test showed before gets its height in its first layout.
/// Thus each test shows texts of its own (``answer(_:in:)``), and the suite
/// runs its tests one at a time.
@MainActor @Suite(.serialized) struct TranscriptMotionMountTests {
  /// The number of answers in the transcript of a flick: more than the
  /// rows that the flick brings into view.
  static let answerCount = 80

  /// The number of answers in the transcript of a jump: more than one page
  /// of the list (``ConversationLayout/defaultPageSize``), as in the hosted
  /// test of the model cache of a thread, so a jump to the first row loads
  /// an earlier page.
  static let jumpAnswerCount = 300

  /// The number of live steps of the flick.
  static let stepCount = 12

  /// The distance of each live step of the flick, in points: less than the
  /// height of the list, so each row that the flick passes comes into view.
  static let stepDistance: CGFloat = 150

  /// The number of editors that are real at the end of a step of the
  /// flick and that the list did not have before the flick. Each row that
  /// comes into view takes its static form in the step in which the thread
  /// gets its height, so no editor of the flick stays real after its step.
  /// Commit 62a65153, before the mounts of the motion waited from their
  /// start, gives the same count for the same steps.
  static let flickMounts = 0

  /// The text of the answer at `index` of the transcript of a test: a line
  /// of prose and a code fence.
  ///
  /// - Parameters:
  ///   - index: The index of the answer.
  ///   - test: The name of the test, which makes the text its own.
  /// - Returns: The Markdown text.
  static func answer(_ index: Int, in test: String) -> String {
    "Motion mount \(test) answer \(index): the parser reads each line.\n\n```swift\nlet \(test)\(index) = \(index)\n```\n"
  }

  /// The frames of the queue of the list.
  let frames = ManualFrames()

  /// Shows the list of the texts of a test at its first row, at rest: a
  /// jump at rest to the first row (``MovingThread/jumpAtRest(to:)``), so
  /// the list reports its first row in view.
  ///
  /// - Parameters:
  ///   - count: The number of answers.
  ///   - test: The name of the test (``answer(_:in:)``).
  /// - Returns: The list.
  func restingThread(count: Int = answerCount, test: String) async throws -> MovingThread {
    let thread = try MovingThread(
      session: .preview(transcript: (0..<count).map { .agent(Self.answer($0, in: test)) }), frames: frames)
    let firstKey = try #require(thread.session.transcript.first?.rowKey)
    await thread.jumpAtRest(to: firstKey)
    return thread
  }

  /// Moves the list in a flick of ``stepCount`` live steps, and records
  /// each editor of the list at the end of each step. Each step lays the
  /// host out after the blocks of the main run loop that its layout added,
  /// so the rows show the forms of the changes of the step. The flick does
  /// not end.
  ///
  /// - Parameter thread: The list at rest.
  /// - Returns: The record of the editors of the list.
  func flick(_ thread: MovingThread) async -> EditorMountRecord {
    let record = EditorMountRecord(thread.textViews)
    await thread.startMoving()
    record.note(thread.textViews)
    for _ in 0..<Self.stepCount {
      thread.step(by: -Self.stepDistance, isLive: true)
      await thread.settle()
      record.note(thread.textViews)
    }
    return record
  }

  /// A production change that fails this test: a row whose height is not
  /// known when it comes into the list in a motion keeps its editors for
  /// the whole motion and does not take its static form when it gets its
  /// height, so more editors are real in the flick.
  @Test func aFlickMountsNoMoreEditorsThanBeforeTheMotionRowsWaited() async throws {
    let thread = try await restingThread(test: "flickMounts")

    let record = await flick(thread)

    #expect(record.mountCount == Self.flickMounts, "\(record.mountCount) editors mounted in the flick")
  }

  /// A production change that fails this test: a row that is real in the
  /// motion waits in the queue, so at rest it takes its static form, and
  /// its editors leave the window before the queue mounts them again.
  @Test func noEditorLeavesTheWindowInTheFirstLayoutAtRest() async throws {
    let thread = try await restingThread(test: "flickRest")
    _ = await flick(thread)
    let inMotion = thread.textViews

    await thread.stopMoving()

    let atRest = thread.textViews
    let left = inMotion.filter { editor in !atRest.contains { $0 === editor } }
    #expect(left.isEmpty, "\(left.count) of \(inMotion.count) editors left the window")
  }

  /// A production change that fails this test: a row whose height is not
  /// known when it comes into view in a live motion keeps its editors when
  /// it gets the height of its first layout, so its editors stay real for
  /// the whole motion.
  @Test func aRowWithNoKnownHeightTakesItsStaticFormWhenItGetsItsHeightInALiveMotion() async {
    let host = await StaticRowHost.cached(.agentFenced, width: TranscriptStaticRowTests.widths[1], frames: frames)

    host.layOut()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: a row that a scroll of the
  /// kit makes while the rows move waits from its start as a row of a live
  /// motion, so at rest it takes its static form and its editors leave the
  /// window.
  @Test func aRowThatAScrollOfTheKitMakesStaysRealAtRest() async {
    let host = await StaticRowHost.cached(
      .agentFenced, width: TranscriptStaticRowTests.widths[1], frames: frames, movesLive: false)

    host.mounts?.noteRowsMove(false)
    host.show(rowsMove: false)

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: a row that a scroll of the
  /// kit makes while the rows move waits in the queue, so the queue runs
  /// at rest for a row that is real.
  @Test func aRowThatAScrollOfTheKitMakesDoesNotWait() async {
    let host = await StaticRowHost.cached(
      .agentFenced, width: TranscriptStaticRowTests.widths[1], frames: frames, movesLive: false)

    host.mounts?.noteRowsMove(false)
    host.show(rowsMove: false)

    #expect(!frames.isRunning)
  }

  /// A production change that fails this test: an animated scroll of the
  /// kit, such as a scroll to a row, is a live motion, so the rows that it
  /// makes wait in the queue.
  @Test func anAnimatedScrollIsNotALiveMotion() {
    #expect(!TranscriptRowMotion.isLiveMotion(.animating))
  }

  /// A production change that fails this test: a drag, a flick or its
  /// deceleration is not a live motion, so the rows of a flick do not wait
  /// in the queue.
  @Test func eachScrollOfTheUserIsALiveMotion() {
    let phases: [ScrollPhase] = [.tracking, .interacting, .decelerating]

    #expect(phases.allSatisfy(TranscriptRowMotion.isLiveMotion))
  }

  /// A production change that fails this test: a jump at rest to a row
  /// on an earlier page, to the last row, and back to the first row does
  /// not bring the row of each jump into view.
  @Test func eachJumpAtRestShowsItsRowInView() async throws {
    let thread = try await restingThread(count: Self.jumpAnswerCount, test: "jumpsInView")
    let first = try #require(thread.session.transcript.first?.rowKey)
    let last = try #require(thread.session.transcript.last?.rowKey)
    var shown: [Bool] = []

    for key in [first, last, first] {
      await thread.jumpAtRest(to: key)
      shown.append(thread.rowKeysInView.contains(key))
    }

    #expect(
      shown == [true, true, true],
      "rows in view \(thread.rowKeysInView.sorted()), \(thread.textViewCount) editors, queue runs: \(frames.isRunning)")
  }

  /// A production change that fails this test: the rows that a jump at
  /// rest makes wait in the queue as the rows of a live motion, so they
  /// stay static until the queue turns.
  @Test func noRowOfAJumpAtRestWaitsInTheQueue() async throws {
    let thread = try await restingThread(count: Self.jumpAnswerCount, test: "jumpWaits")
    let key = try #require(thread.session.transcript.first?.rowKey)

    await thread.jumpAtRest(to: key)

    #expect(!frames.isRunning)
  }
}

/// The record of the EditorKit text views of a list over the steps of a
/// motion (card ^7625j1b).
///
/// The record keeps each text view that it sees, so no new text view can
/// get the identity of a text view that the list removed.
@MainActor final class EditorMountRecord {
  /// Each text view that the record saw, in the order of its arrival.
  private var seen: [NSTextView]

  /// The number of text views that the list had when the record started.
  private let startCount: Int

  /// Starts a record with the text views of the list before the motion.
  ///
  /// - Parameter editors: The text views of the list.
  init(_ editors: [NSTextView]) {
    seen = editors
    startCount = editors.count
  }

  /// Records the text views of the list after a step.
  ///
  /// - Parameter editors: The text views of the list.
  func note(_ editors: [NSTextView]) {
    seen += editors.filter { editor in !seen.contains { $0 === editor } }
  }

  /// The number of text views that came into the list after the start of
  /// the record: the editors that the rows mounted.
  var mountCount: Int {
    seen.count - startCount
  }
}
