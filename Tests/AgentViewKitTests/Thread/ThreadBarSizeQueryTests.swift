import AgentViewKitTestSupport
import AppKit
import EditorCommandsUI
import EditorTestSupport
import FoundationModelsACPClient
import Observation
import SwiftUI
import Testing

@testable import AgentViewKit

/// The height of the probe rows of a ``ThreadBarSizeQueryTests`` thread.
///
/// A row changes its height on each scroll step, as a row of a real thread
/// does when its text gets its layout. The change makes SwiftUI measure the
/// scroll view again.
@MainActor @Observable final class ProbeRowHeight {
  /// The height of a row, in points.
  var points: CGFloat

  /// Makes the height of the rows.
  ///
  /// - Parameter points: The first height of a row, in points.
  init(points: CGFloat) {
    self.points = points
  }
}

/// A row of a ``ThreadBarSizeQueryTests`` thread: a ``SizeQueryProbe`` with
/// the height of ``ProbeRowHeight``.
struct ProbeRow: View {
  /// The record of the probe.
  let record: SizeQueryRecord

  /// The height of the row.
  let height: ProbeRowHeight

  var body: some View {
    SizeQueryProbe(record: record, height: height.points) {}
  }
}

/// A scroll of the thread asks the rows for no size from the safe-area bars
/// (task ^7q5zdsj, #perf).
///
/// The layout of `.safeAreaBar` asks its content for its minimum size. With
/// the scroll view as the content, that query measures the lazy stack and
/// its rows on each frame of a scroll. The test counts only the queries
/// that a bar makes, by the call stack of each query; the lazy stack asks
/// the rows for their sizes when it places them, and the test does not
/// count those queries. SwiftUI does the layout of a hosting view in a
/// window, so the thread is in a borderless window that is never ordered
/// in: no window shows, and no window takes the focus.
@MainActor @Suite struct ThreadBarSizeQueryTests {
  /// The size of the window of the thread.
  static let size = CGSize(width: 480, height: 600)

  /// The number of the prompts and the number of the answers of the
  /// transcript.
  static let turnCount = 40

  /// The first height of a probe row, in points.
  static let rowHeight: CGFloat = 80

  /// The height that a probe row adds on each scroll step, in points.
  static let rowGrowth: CGFloat = 10

  /// The number of the scroll steps.
  static let stepCount = 5

  /// The distance of one scroll step to the top, in points.
  static let stepDistance: CGFloat = 400

  /// A session with ``turnCount`` prompts and answers. The prompts have the
  /// default view and the answers have the probe rows, so the rows do not
  /// all have one height.
  ///
  /// - Returns: The session model.
  static func session() -> SessionModel {
    .preview(transcript: (0..<turnCount).flatMap { [.user("Question \($0)?"), .agent("Answer \($0).")] })
  }

  /// A thread with a header in its top bar and a composer in its bottom
  /// bar, with a probe row for each answer, laid out one time in a
  /// borderless window that is never ordered in.
  ///
  /// - Parameters:
  ///   - session: The session model of the thread.
  ///   - anchors: The manager of the scroll position of the thread.
  ///   - record: The record of the probes.
  ///   - height: The height of the probe rows.
  /// - Returns: The window. Its content view is the host of the thread.
  static func mount(
    _ session: SessionModel, anchors: ScrollAnchorManager, record: SizeQueryRecord, height: ProbeRowHeight
  ) -> NSWindow {
    let thread = AgentThreadView(session: session, anchors: anchors) { Text(verbatim: "Composer") }
      .threadHeader { Text(verbatim: "Header") }
      .assistantMessageView { _ in ProbeRow(record: record, height: height) }
      .commandSystem(CommandSystem())
      .transaction { $0.disablesAnimations = true }
    let hosting = NSHostingView(rootView: thread)
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    return window
  }

  /// A production change that fails this test: the scroll view of the
  /// conversation, or the content of the thread, is the direct content of
  /// a `.safeAreaBar`, so the bar asks the rows for their sizes on each
  /// layout of a scroll.
  @Test func aScrollAsksTheRowsForNoSizeFromTheBars() throws {
    let session = Self.session()
    let anchors = ScrollAnchorManager()
    let record = SizeQueryRecord()
    let height = ProbeRowHeight(points: Self.rowHeight)
    let window = Self.mount(session, anchors: anchors, record: record, height: height)
    let hosting = try #require(window.contentView)
    let scrollView = try #require(views(ofType: NSScrollView.self, in: hosting).first)
    let clip = scrollView.contentView
    ConversationPillMountTests.unpin(anchors, rowKeys: session.transcript.map(\.rowKey))
    hosting.layoutSubtreeIfNeeded()
    record.reset()

    for _ in 0..<Self.stepCount {
      clip.scroll(to: NSPoint(x: clip.bounds.origin.x, y: clip.bounds.origin.y - Self.stepDistance))
      scrollView.reflectScrolledClipView(clip)
      height.points += Self.rowGrowth
      hosting.layoutSubtreeIfNeeded()
    }

    try #require(record.queryCount > 0)
    #expect(record.barQueryCount == 0)
  }
}
