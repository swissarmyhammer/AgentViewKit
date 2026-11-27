import AppKit
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The text layouts of the SwiftUI `Text` of the static rows of a thread
/// (card ^9ync5h3).
///
/// A static row shows the picture of each Markdown text and each code
/// block that EditorKit draws, and SwiftUI `Text` for each other text: a
/// Markdown text that the picture does not draw, and the code and the line
/// numbers of a code block before the cache has its picture. SwiftUI keeps
/// the measure of a `Text` for one proposal. Thus each
/// `Text` of a static row must get one proposal: each other query, such as
/// the minimum width or the spacing of a stack, lays the text out again.
/// The ``TextLayoutProbe`` counts each layout of a text of a test.
@MainActor @Suite struct StaticTextLayoutTests {
  /// The width of the rows, in points.
  static let width: CGFloat = 480

  /// The number of the code lines of the line number test: more than the
  /// code of each other test, so its last line numbers are its own.
  static let longCodeLineCount = 97

  /// The number of the turns of the flick test.
  static let flickTurns = 20

  /// The number of the steps of the flick test.
  static let flickSteps = 150

  /// The distance of one step of the flick test, in points: the step of
  /// the flick trace harness.
  static let flickStep: CGFloat = 40

  /// A production change that fails this test: a static row that comes
  /// into a moving thread shows a SwiftUI `Text` of its prose or its code
  /// while the cache has the picture of the text, so a flick lays out the
  /// text of each new row on the main thread.
  ///
  /// The thread has the height cache of an ``AgentThreadView``, and shows
  /// the turns of the flick trace harness (``FlickTranscript``). The test
  /// moves the thread up from the bottom in a live scroll.
  @Test func aFlickLaysOutNoTextOfTheStaticRows() async throws {
    let name = "flickTextLayout"
    TextLayoutProbe.watch(name)
    let session = SessionModel.preview(transcript: FlickTranscript.items(turns: Self.flickTurns, in: name))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
    }

    #expect(TextLayoutProbe.layouts(ofTextContaining: name).isEmpty)
  }

  /// A production change that fails this test: the static form of a code
  /// block with no picture lays out its code at more than one proposal,
  /// such as at the minimum width and the ideal width that a stack asks
  /// for. The cache of the row draws no picture.
  @Test func aStaticCodeBlockLaysOutItsCodeOneTime() async throws {
    let code = "let staticCodeLayoutOne = 1"
    TextLayoutProbe.watch(code)

    _ = await StaticRowHost.makeCached(
      .agent("A code block.\n\n```swift\n\(code)\n```\n"), width: Self.width, drawsPictures: false)

    try #require(!TextLayoutProbe.layouts(ofTextContaining: code).isEmpty)
    #expect(TextLayoutProbe.repeatedLayouts(ofTextContaining: code) == 0)
  }

  /// A production change that fails this test: the static form of a code
  /// block with no picture lays out its line numbers at more than one
  /// proposal. The cache of the row draws no picture.
  @Test func aStaticCodeBlockLaysOutItsLineNumbersOneTime() async throws {
    let lines = (0..<Self.longCodeLineCount).map { "let staticLineNumbers\($0) = \($0)" }
    let numbers = "\n\(Self.longCodeLineCount - 1)\n\(Self.longCodeLineCount)"
    TextLayoutProbe.watch(numbers)
    let answer = "Line numbers.\n\n```swift\n\(lines.joined(separator: "\n"))\n```\n"

    _ = await StaticRowHost.makeCached(.agent(answer), width: Self.width, drawsPictures: false)

    try #require(!TextLayoutProbe.layouts(ofTextContaining: numbers).isEmpty)
    #expect(TextLayoutProbe.repeatedLayouts(ofTextContaining: numbers) == 0)
  }

  /// The number of the answers of the test of the Markdown texts with no
  /// picture: more than the rows in view.
  static let unpicturedAnswerCount = 40

  /// A production change that fails this test: the static form of a
  /// Markdown text with no picture lays out its `Text` at more than one
  /// proposal, such as for the spacing query of a stack, when its row comes
  /// into a moving thread. Each answer has a code fence after its text, as
  /// an answer of the flick trace harness has, so the text is one piece of
  /// a stack of pieces.
  @Test func aFlickLaysOutEachMarkdownTextWithNoPictureOneTime() async throws {
    let name = "unpicturedTextLayout"
    TextLayoutProbe.watch(name)
    let texts = (0..<Self.unpicturedAnswerCount).map { "Some ~~struck~~ words of \(name) \($0).\n\n```swift\nlet x\($0) = \($0)\n```\n" }
    try #require(texts.allSatisfy { !StaticMarkdownPicture.draws($0) })
    let session = SessionModel.preview(transcript: texts.map(PreviewTranscriptItem.agent))
    let thread = try await MovingThread.makeCached(session: session, frames: ManualFrames())
    thread.startMoving()

    for _ in 0..<Self.flickSteps {
      thread.step(by: Self.flickStep, isLive: true)
    }

    try #require(!TextLayoutProbe.layouts(ofTextContaining: name).isEmpty)
    #expect(TextLayoutProbe.repeatedLayouts(ofTextContaining: name) == 0)
  }
}
