import AgentViewKitTestSupport
import CoreGraphics
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// Tests for the slot of the side cards of a thread (D205): the stack at the
/// trailing edge above the composer, and its full width in a narrow thread.
///
/// The layout tests read the frames that ``SideCardLayout`` gives, with no
/// view. The thread test lays out a thread view in an `NSHostingView` with
/// no window, so no test shows a window or takes the focus.
@MainActor struct SideCardsTests {
  /// The layout of the tests: a card width of 300 points, a narrow width of
  /// 600 points, and a spacing of 8 points.
  static let layout = SideCardLayout(cardWidth: 300, narrowWidth: 600, spacing: 8)

  /// The height of the newest card of the tests.
  static let newestHeight: CGFloat = 40

  /// The height of the older card of the tests.
  static let olderHeight: CGFloat = 60

  /// The bounds of a wide thread.
  static let wideBounds = CGRect(x: 0, y: 0, width: 900, height: 200)

  /// The bounds of a narrow thread.
  static let narrowBounds = CGRect(x: 0, y: 0, width: 400, height: 200)

  /// The frames of the two cards of the tests in `bounds`, newest first.
  ///
  /// - Parameter bounds: The bounds of the stack.
  /// - Returns: The frame of the newest card and the frame of the older card.
  static func frames(in bounds: CGRect) -> [CGRect] {
    layout.frames(heights: [newestHeight, olderHeight], in: bounds)
  }

  // MARK: - Layout

  @Test func theNewestCardIsAtTheTop() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.map(\.minY) == [0, Self.newestHeight + Self.layout.spacing])
  }

  @Test func inAWideThreadTheCardsAreAtTheTrailingEdgeAtTheCardWidth() {
    let frames = Self.frames(in: Self.wideBounds)

    #expect(frames.map(\.maxX) == [Self.wideBounds.maxX, Self.wideBounds.maxX])
    #expect(frames.map(\.width) == [Self.layout.cardWidth, Self.layout.cardWidth])
  }

  @Test func inANarrowThreadTheCardsHaveTheFullWidth() {
    let frames = Self.frames(in: Self.narrowBounds)

    #expect(frames.map(\.width) == [Self.narrowBounds.width, Self.narrowBounds.width])
  }

  @Test func theStackIsAsTallAsTheCardsAndTheSpacing() {
    let height = Self.layout.height(of: [Self.newestHeight, Self.olderHeight])

    #expect(height == Self.newestHeight + Self.layout.spacing + Self.olderHeight)
  }

  // MARK: - Thread

  @Test func theCardsDoNotChangeTheTranscriptOfTheThread() {
    let thread = SessionModel.preview(transcript: [.user("Fix the test."), .agent("Done.")])
    let fork = SessionModel.preview(sessionId: SessionId(rawValue: "fork"), transcript: [])
    let before = thread.transcript.map(\.rowKey)

    StyleViewHost.layOut(
      AgentThreadView(session: thread) { EmptyView() }
        .sideCards {
          SideQuestionCard(question: "Why?", session: fork, onOpen: {}, onClose: {})
        }
        .frame(width: Self.wideBounds.width, height: Self.wideBounds.height))

    #expect(thread.transcript.map(\.rowKey) == before)
  }
}
