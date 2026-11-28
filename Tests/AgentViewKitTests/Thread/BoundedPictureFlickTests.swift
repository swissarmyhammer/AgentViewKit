import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The text layouts of the static rows of a flick when the pictures of the
/// whole transcript do not fit in the byte bound of the height cache
/// (card ^9ync5h3).
///
/// The bound of the cache holds a few screens of pictures, so the cache
/// cannot keep a picture of each row. The test waits for the worker of the
/// cache after each step (``TranscriptRowHeights/finishPendingHeights()``),
/// as a worker that keeps up with the flick does.
@MainActor @Suite struct BoundedPictureFlickTests {
  /// The number of the turns of the flick.
  static let flickTurns = 50

  /// The number of the steps of the flick.
  static let flickSteps = 150

  /// The distance of one step of the flick, in points: the step of the
  /// flick trace harness.
  static let flickStep: CGFloat = 40

  /// The number of screens of pictures that the bound of the cache holds.
  static let boundScreens: CGFloat = 8

  /// The bytes of one pixel of a picture.
  static let bytesPerPixel: CGFloat = 4

  /// The byte bound of the pictures of the cache: ``boundScreens`` screens
  /// of the list at the scale of its window.
  ///
  /// - Parameter scale: The backing scale of the window.
  /// - Returns: The bound, in bytes.
  static func pictureByteLimit(scale: CGFloat) -> Int {
    let size = AnswerTextHitTests.size
    return Int(boundScreens * size.width * size.height * bytesPerPixel * scale * scale)
  }

  /// A production change that fails this test: the cache drops the
  /// pictures of the rows that it drew first when its bound is full, so a
  /// flick from the bottom reaches rows with no picture, and lays out their
  /// SwiftUI `Text` on the main thread. The same fails when the cache does
  /// not draw again the dropped pictures of the rows that come near the
  /// view.
  @Test func aFlickPastTheBoundOfThePicturesLaysOutNoText() async throws {
    let name = "boundedPictureFlick"
    TextLayoutProbe.watch(name)
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let scale = NSScreen.main?.backingScaleFactor ?? 1
    let thread = try await MovingThread.makeCached(
      session: session, frames: ManualFrames(), pictureByteLimit: Self.pictureByteLimit(scale: scale))
    let cache = try #require(thread.heights.cache)
    try #require(
      session.transcript.contains { $0.kindName == "agent-message" && !cache.hasPictures(ofRow: $0.rowKey) },
      "the bound holds the picture of each answer")
    thread.startMoving()

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
      thread.settle()
      await cache.finishPendingHeights()
    }

    #expect(TextLayoutProbe.layouts(ofTextContaining: name).count == 0)
  }
}
