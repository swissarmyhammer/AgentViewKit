import AgentViewKitTestSupport
import AppKit
import EditorTestSupport
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The list of a ``ConversationView`` keeps the bottom edge of a scroll to
/// the bottom only until the scroll is at the bottom (task ^48x2jb7).
///
/// SwiftUI applies an edge that the scroll position keeps again in each
/// later layout pass of the list. The offset of the list then follows the
/// estimated height of the lazy stack, and that height follows the rows
/// that the stack lays out at that offset. In the hosted window of
/// `ThreadFloatingControlsHostedTests`, this cycle did not stop: each pass
/// laid out other rows and queued one more update. When the list is at the
/// bottom, the view sets the position to positioned by the user, so the
/// position keeps no edge, and a later layout pass does not move the list.
///
/// The list is in a borderless window that is never ordered in: no window
/// shows, and no window takes the focus. Each step is one synchronous
/// layout pass; the test has no clock and no wait.
@MainActor @Suite struct ConversationKeptEdgeTests {
  /// The size of the window of the list.
  static let size = CGSize(width: 480, height: 480)

  /// The number of the agent answers after the one user message.
  static let answerCount = 30

  /// The number of the lines of the answer that the test appends. The
  /// answer is taller than a few points, so a move of the list to the new
  /// bottom is clear.
  static let appendedLineCount = 12

  /// The message id of the answer that the test appends.
  static let appendedMessageID = "kept-edge-appended"

  /// The largest move of the clip view, in points, that the test counts as
  /// no move.
  static let moveTolerance: CGFloat = 0.5

  /// A session with one user message and then ``answerCount`` answers.
  ///
  /// - Returns: The session model.
  static func session() -> SessionModel {
    .preview(transcript: [.user("Question?")] + (0..<answerCount).map { .agent("Answer \($0).") })
  }

  /// Shows the list of `session` in a borderless window that is never
  /// ordered in, and lays it out one time.
  ///
  /// - Parameters:
  ///   - session: The session model of the list.
  ///   - anchors: The manager of the scroll position of the list.
  /// - Returns: The window. Its content view is the host of the list.
  static func mount(_ session: SessionModel, anchors: ScrollAnchorManager) -> NSWindow {
    let list = ConversationView(session: session, anchors: anchors)
      .transaction { $0.disablesAnimations = true }
    let hosting = NSHostingView(rootView: list)
    let window = NSWindow(
      contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: true)
    window.isReleasedWhenClosed = false
    window.contentView = hosting
    hosting.layoutSubtreeIfNeeded()
    return window
  }

  /// Lays out `hosting` one time.
  ///
  /// - Parameter hosting: The host of the list.
  static func layOut(_ hosting: NSView) {
    hosting.needsLayout = true
    hosting.layoutSubtreeIfNeeded()
  }

  /// A production change that fails this test: the scroll position keeps the
  /// bottom edge after the scroll to the bottom is at the bottom, so SwiftUI
  /// applies the edge again in a later layout pass, and the list moves to the
  /// new end of its content although it does not follow the bottom.
  @Test func aLaterPassDoesNotMoveTheListToTheEdgeOfAScrollThatEnded() async throws {
    let session = Self.session()
    let anchors = ScrollAnchorManager()
    let window = Self.mount(session, anchors: anchors)
    let hosting = try #require(window.contentView)
    let clip = try #require(views(ofType: NSScrollView.self, in: hosting).first).contentView
    let firstKey = try #require(session.transcript.first?.rowKey)
    let lastKey = try #require(session.transcript.last?.rowKey)

    // Up to the first row, and then the scroll to the bottom edge.
    anchors.onScroll(.item(firstKey))
    Self.layOut(hosting)
    anchors.onScroll(.bottom)
    Self.layOut(hosting)
    // SwiftUI reports the visible rows after the layout pass, on the main
    // run loop. The test waits for that report: the change of the visible
    // rows of the manager, which is observable.
    await ObservationWait.until { anchors.visibleIDs.last == lastKey }
    try #require(anchors.visibleIDs.last == lastKey)

    // The list stops to follow the bottom: the manager keeps a jump anchor,
    // so the list has no bottom anchor for a change of its size.
    anchors.noteJump(to: lastKey)
    Self.layOut(hosting)
    let origin = clip.bounds.origin.y

    let lines = (0..<Self.appendedLineCount).map { "Line \($0)." }.joined(separator: "\n\n")
    session.apply(.agentMessageChunk(TranscriptSearchTests.chunk(lines, id: Self.appendedMessageID)))
    Self.layOut(hosting)
    Self.layOut(hosting)

    #expect(
      abs(clip.bounds.origin.y - origin) <= Self.moveTolerance,
      "the clip origin moved from \(origin) to \(clip.bounds.origin.y)")
    withExtendedLifetime(window) {}
  }
}
