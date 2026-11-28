import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The SwiftUI work on the main thread while a live flick moves a thread
/// (card ^9ync5h3).
///
/// The thread has the height cache of an ``AgentThreadView``, and shows the
/// turns of the flick trace harness (``FlickTranscript``). The test moves
/// the thread up from the bottom in a live scroll, and lays the host out
/// after each step. The frames of the queue of the rows are steps by hand
/// (``ManualFrames``), and no frame comes, so the motion does not end.
@MainActor @Suite struct TranscriptFlickWorkTests {
  /// The number of the turns of the flick.
  static let flickTurns = 50

  /// The number of the steps of the flick.
  static let flickSteps = 150

  /// The distance of one step of the flick, in points: the step of the
  /// flick trace harness.
  static let flickStep: CGFloat = 40

  /// A production change that fails this test: the list of the rows reads
  /// the scroll position in its body. SwiftUI writes the position each time
  /// a new row comes to the top edge of the list, so each such write in the
  /// flick evaluates the list again.
  @Test func aFlickEvaluatesNoListOfTheRows() async throws {
    let name = "flickListWork"
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()
    let key = ConversationLayout.listCounterKey(for: thread.anchors)
    BodyEvaluationCounter.reset(key)

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
    }

    #expect(BodyEvaluationCounter.count(key) == 0)
  }

  /// A production change that fails this test: the virtual stack of the
  /// rows computes its geometry in each body, so each change of the rows in
  /// view reads the height of each shown row again, also when no height
  /// changes (card ^kr7cx7b).
  @Test func aFlickReadsNoRowHeightWhenNoHeightChanges() async throws {
    let name = "flickHeightReads"
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()
    let key = TranscriptRowStack.heightReadCounterKey(for: session)
    BodyEvaluationCounter.reset(key)

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
    }

    #expect(BodyEvaluationCounter.count(key) == 0)
  }

  /// A production change that fails this test: the window of the virtual
  /// stack of the rows evaluates its body on each change of the rows in
  /// view, and not only when it must mount a row that comes into view
  /// (card ^kr7cx7b). Each body makes the `ForEach` of the mounted rows
  /// again. In a flick, a row leaves the view at one edge for each row that
  /// comes into it at the other edge, so that window evaluates its body
  /// about two times for each row that it makes.
  @Test func aFlickEvaluatesTheWindowOnlyToMountARow() async throws {
    let name = "flickWindowWork"
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()
    let windowKey = TranscriptRowWindow.counterKey(for: session)
    let rowKeys = session.transcript.map { ItemRow.counterKey(for: $0.rowKey) }
    BodyEvaluationCounter.reset([windowKey] + rowKeys)

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
    }

    let madeRows = rowKeys.map(BodyEvaluationCounter.count).reduce(0, +)
    #expect(BodyEvaluationCounter.count(windowKey) <= madeRows)
  }

  /// The number of the first steps of a flick in which the stack does not
  /// know the direction of the motion yet: the steps before the steady
  /// flick.
  static let warmUpSteps = 10

  /// A production change that fails this test: the window of the virtual
  /// stack mounts a row only when the row comes into view, so the first
  /// frame of each new row (its make, its layout and its draw) is a frame
  /// in which the row is in view.
  ///
  /// The test lays the host out and runs one pass of the main run loop
  /// after each step, so the list reports its rows in view. A row counts
  /// when the step that first shows it also made it (``ItemRow`` evaluates
  /// its body only when the stack makes it).
  @Test func aSteadyFlickMountsNoRowInTheStepThatShowsIt() async throws {
    let name = "flickLeadRow"
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()
    let rowKeys = session.transcript.map(\.rowKey)
    let makes = { (key: String) in BodyEvaluationCounter.count(ItemRow.counterKey(for: key)) }
    var shown = thread.rowKeysInView
    var steadyRows: [String] = []
    var madeInView: [String] = []

    for step in 0..<Self.flickSteps {
      let before = Dictionary(uniqueKeysWithValues: rowKeys.map { ($0, makes($0)) })
      thread.step(by: Self.flickStep, isLive: true)
      thread.settle()
      let new = thread.rowKeysInView.subtracting(shown)
      shown.formUnion(new)
      if step >= Self.warmUpSteps {
        steadyRows.append(contentsOf: new)
        madeInView.append(contentsOf: new.filter { makes($0) > before[$0, default: .zero] })
      }
    }

    try #require(!steadyRows.isEmpty, "no row came into view in the steady flick")
    #expect(madeInView.count == 0)
  }
}
