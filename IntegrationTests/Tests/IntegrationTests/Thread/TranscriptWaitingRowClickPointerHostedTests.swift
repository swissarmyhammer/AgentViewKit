import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// A click on a thread row that waits at rest in the
/// ``TranscriptRowMountQueue`` (card ^9ync5h3, card ^7625j1b).
///
/// The mouse does not hold a row that waits in the queue
/// (``TranscriptRowHolds/keepsRealRow(waitsToMount:)``): at the end of a
/// live motion, the row under the mouse takes its turns as each other row
/// does. A press of the mouse on such a row makes the row real at once, so a
/// click does not stay on its static form until its turn.
///
/// A SwiftUI gesture reads a click only from a window that is ordered in, so
/// this test is hosted. The test shows one answer row at rest, so the row
/// records the height of its real form. Then the row comes into the list
/// again as a new row in a live motion, and the rows come to rest: the row
/// waits in the queue and shows its static form. The frames of the queue
/// never step (``StillFrames``), so only the click can make the row real.
@Suite(.serialized, .hostedSerially) @MainActor struct TranscriptWaitingRowClickPointerHostedTests {
  /// The size of the window of the harness.
  static let size = CGSize(width: 480, height: 480)

  /// The text of the answer: a paragraph of a few lines that no other test
  /// shows.
  static let answer = """
    The waiting row click answer: the parser reads each line of the file, \
    keeps the tokens of each line, and gives the tokens to the checker, \
    which reads them in order and reports each error that it finds.
    """

  /// The number of passes of the run loop and the render after the click:
  /// the update of the gesture, and the update that the new form of the
  /// row queues.
  static let settlePasses = 2

  /// A production change that fails this test: a press on a row that waits
  /// at rest does not make the row real, so the click reaches no editor
  /// until the turn of the row.
  @Test func aClickOnARowThatWaitsAtRestMakesTheRowReal() async throws {
    let bed = WaitingRowBed(session: .preview(transcript: [.agent(Self.answer)]))
    let harness = HostedViewHarness(size: Self.size) { WaitingRowBedView(bed: bed) }
    defer { harness.close() }
    bed.enterInALiveMotion()
    harness.render()
    bed.rest()
    harness.render()
    try #require(harness.textViewCount == 0, "the row is real before the click")

    try await harness.sendClick(identifier: ItemRow.identifier(for: bed.entry.rowKey))
    await harness.settle(passes: Self.settlePasses)

    #expect(harness.textViewCount > 0)
  }
}

/// The model of a ``WaitingRowBedView``: one row of a thread, with the
/// queue, the heights and the motion signal of a thread.
@MainActor @Observable final class WaitingRowBed {
  /// The session whose one entry the bed shows.
  @ObservationIgnored let session: SessionModel

  /// The heights of the static row: the record of the real row.
  @ObservationIgnored let heights = TranscriptStaticRowHeights()

  /// The queue of the row, whose frames never step.
  @ObservationIgnored let mounts = TranscriptRowMountQueue(frames: StillFrames())

  /// The cache of the EditorKit models of the row, as a thread gives it.
  @ObservationIgnored let cache = CodeBlockModelCache(limit: CodeBlockModelCache.threadLimit)

  /// The identity of the row. A new identity is a new row, as the list
  /// makes for a row that comes into it.
  private(set) var rowIdentity = 0

  /// Whether the rows move in a live motion of the user.
  private(set) var rowsMoveLive = false

  /// Makes the bed of the one entry of `session`, at rest.
  ///
  /// - Parameter session: The session.
  init(session: SessionModel) {
    self.session = session
  }

  /// The entry of the row.
  var entry: TranscriptEntry {
    session.transcript[0]
  }

  /// Brings the row into the list again as a new row in a live motion. The
  /// row shows its static form, and its mount waits from its start.
  func enterInALiveMotion() {
    mounts.noteRowsMove(true)
    mounts.noteRowsMoveLive(true)
    rowIdentity += 1
    rowsMoveLive = true
  }

  /// Brings the rows to rest after a live motion.
  func rest() {
    mounts.noteRowsMove(false)
    rowsMoveLive = false
  }
}

/// The row of a ``WaitingRowBed``, with the environment of a thread, at the
/// top of the window.
struct WaitingRowBedView: View {
  /// The bed of the row.
  let bed: WaitingRowBed

  var body: some View {
    let rowsMoveLive = bed.rowsMoveLive
    TranscriptRowElement(
      slot: TranscriptRowSlot(position: 0, entry: bed.entry), isLast: false, lines: [],
      entersWhileMoving: rowsMoveLive)
      .id(bed.rowIdentity)
      .modifier(TranscriptRowsHitTest(rowsMoveLive: rowsMoveLive))
      .fixedSize(horizontal: false, vertical: true)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
      .environment(\.transcriptRowsMove, rowsMoveLive)
      .environment(\.transcriptRowsMoveLive, rowsMoveLive)
      .environment(\.staticRowHeights, bed.heights)
      .environment(\.transcriptRowMounts, bed.mounts)
      .environment(\.sessionModel, bed.session)
      .environment(\.codeBlockModelCache, bed.cache)
      .threadTextSelection()
      .transaction { $0.disablesAnimations = true }
  }
}

/// The frames of a queue that never step: a source that records no step.
@MainActor final class StillFrames: TranscriptFrameSource {
  func start(_ step: @escaping @MainActor () -> Void) {}

  func stop() {}

  func attach(to view: NSView) {}
}

extension HostedViewHarness {
  /// The number of EditorKit text views in the host.
  var textViewCount: Int {
    views(ofType: NSTextView.self, in: hostingView).count
  }
}
