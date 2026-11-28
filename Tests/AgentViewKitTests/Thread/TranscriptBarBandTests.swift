import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The virtual stack of a thread mounts the rows under the glass bars of
/// the thread (card ^6fax5yx).
///
/// In an ``AgentThreadView``, the list goes on under the header and under
/// the composer, and the glass of each bar shows the rows under it. The
/// scroll view gives the heights of the bars as its content insets, and the
/// bounds of the scroll view leave those parts out. The test shows a
/// ``MovingThread`` of one-line answers with clear bars of ``barHeight``,
/// scrolls it at rest to the middle, and finds a text view of a row in the
/// outer part of the band of each bar (``outerBandHeight``). A row that
/// meets the edge of the bounds of the scroll view is much shorter than
/// the bar, so it does not reach that part.
@MainActor @Suite(.serialized) struct TranscriptBarBandTests {
  /// The number of answers in the transcript: many more than the rows in
  /// view.
  static let answerCount = 60

  /// The height of each bar, in points: a quarter of the height of the
  /// list (600), taller than one row.
  static let barHeight: CGFloat = 150

  /// The height of the outer part of the band of each bar, in points: the
  /// part of the band at the edge of the window, a third of the bar.
  static let outerBandHeight: CGFloat = 50

  /// The band of a bar of the window, in window coordinates.
  enum Band {
    /// The band under the top bar.
    case top

    /// The band under the bottom bar.
    case bottom

    /// The rectangle of the outer part of the band in a window
    /// (``outerBandHeight``).
    ///
    /// - Parameter window: The window of the list.
    /// - Returns: The rectangle, in window coordinates (origin at the
    ///   bottom left).
    func outerRect(in window: NSWindow) -> CGRect {
      let size = window.frame.size
      let height = TranscriptBarBandTests.outerBandHeight
      let minY = self == .top ? size.height - height : .zero
      return CGRect(x: .zero, y: minY, width: size.width, height: height)
    }
  }

  /// The list with the bars, scrolled at rest to the middle of the
  /// transcript.
  ///
  /// - Returns: The list.
  static func scrolledThread() throws -> MovingThread {
    let thread = try MovingThread(
      session: .preview(transcript: (0..<answerCount).map { .agent("Band answer \($0).") }),
      frames: TranscriptDisplayLinkFrames(), barHeight: barHeight)
    thread.settle()
    thread.scrollAtRest(to: thread.scrollView.contentView.bounds.origin.y / 2)
    return thread
  }

  /// Whether a text view of a row of the list meets the outer part of a
  /// band of the window.
  ///
  /// - Parameters:
  ///   - band: The band.
  ///   - thread: The list.
  /// - Returns: `true` when the frame of a text view meets the outer part
  ///   of the band.
  static func aTextView(meets band: Band, in thread: MovingThread) -> Bool {
    let rect = band.outerRect(in: thread.window)
    return thread.textViews.contains { $0.convert($0.bounds, to: nil).intersects(rect) }
  }

  /// A production change that fails this test: the stack mounts only the
  /// rows in the bounds of the scroll view, which leave out the top
  /// content inset, so the glass of the header shows no row.
  @Test func aRowDrawsUnderTheTopBar() throws {
    let thread = try Self.scrolledThread()

    #expect(Self.aTextView(meets: .top, in: thread))
  }

  /// A production change that fails this test: the stack mounts only the
  /// rows in the bounds of the scroll view, which leave out the bottom
  /// content inset, so the glass of the composer shows no row.
  @Test func aRowDrawsUnderTheBottomBar() throws {
    let thread = try Self.scrolledThread()

    #expect(Self.aTextView(meets: .bottom, in: thread))
  }
}
