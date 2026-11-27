import AppKit
import EditorSwiftUI
import FoundationModelsACP
import FoundationModelsACPClient
import os
import SwiftUI
import Testing

@testable import AgentViewKit

/// The pictures of the static text of the rows of a thread (card ^9ync5h3).
///
/// While the rows move, a Markdown text slot of a static row shows a
/// picture that EditorKit drew off the main thread
/// (`EditorLayoutMeasure.render(markdown:width:style:imageSizes:)`), in
/// place of its SwiftUI `Text`. Each row shows in a ``StaticRowHost``: a
/// borderless window that is never ordered in.
@MainActor @Suite struct TranscriptStaticPictureTests {
  /// The width of the rows, in points.
  static let width: CGFloat = 480

  /// The text of a plain answer of this suite: two paragraphs, the first of
  /// which wraps. No other suite uses it, so the counters of its views count
  /// only the views of this suite.
  nonisolated static let plainText =
    "The picture of the static row shows each line of the text where the editor draws it, "
    + "so the row does not move.\n\nThe list moves on."

  /// The texts of the pixel checks: each kind of Markdown that the picture
  /// draws.
  nonisolated static let pixelTexts = [
    plainText,
    "# Picture\n\nThe first section of the text.\n\n## Lines\n\nThe lines of the second section.",
    "The **strong** words, the *emphasis*, the `inline code` and a [link](https://example.com) of the text.",
    "- The first item of the list.\n- The second item, which is long enough to wrap at the width of the row.\n\n"
      + "> A quote line of the text.\n\n1. One\n2. Two",
  ]

  /// The largest mean difference of a color component between the picture
  /// and the real row, from 0 to 255.
  ///
  /// The limits come from a first run of the pixel texts, light and dark,
  /// at a scale of 2 (2026-11-27): the largest mean was 0.62 and the
  /// largest part was 0.0055, at a row shift of one pixel. Each limit is a
  /// little more than that value. With EditorKit 21a8a01d, the baselines of
  /// the picture are on the pixel rows of the mounted editor, and the
  /// compare with no row shift stays in the same limits. The SwiftUI `Text` form of the plain
  /// text differs from the real row in 0.15 of its pixels.
  static let meanLimit = 0.75

  /// The largest part of the pixels with a large difference between the
  /// picture and the real row (``meanLimit`` tells where it comes from).
  static let largePartLimit = 0.0075

  /// The largest difference between the heights of the two forms of a row,
  /// in points.
  static let heightTolerance: CGFloat = 0.5

  /// The appearance of the pictures of the cache tests.
  static let lightAppearance = TranscriptTextAppearance(colorScheme: .light, scale: 2)

  /// The dark appearance of the cache tests.
  static let darkAppearance = TranscriptTextAppearance(colorScheme: .dark, scale: 2)

  // MARK: - The slot

  /// A production change that fails this test: the slot of a static row
  /// shows its SwiftUI `Text` while its picture is ready, so the list lays
  /// out the text on the main thread while it moves.
  @Test func aStaticSlotWithAReadyPictureBuildsNoText() async throws {
    let text = Self.plainText + " No text."
    _ = await StaticRowHost.makeCached(.agent(text), width: Self.width)
    try #require(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: text)) > 0)

    #expect(BodyEvaluationCounter.count(StaticMarkdownText.counterKey(for: text)) == 0)
  }

  /// A production change that fails this test: the slot of a static row
  /// shows no picture while its picture is ready.
  @Test func aStaticSlotWithAReadyPictureShowsThePicture() async {
    let text = Self.plainText + " A picture."
    _ = await StaticRowHost.makeCached(.agent(text), width: Self.width)

    #expect(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: text)) > 0)
  }

  /// A production change that fails this test: the view of a picture takes
  /// another size than the picture, so the row moves when its form
  /// changes.
  @Test func thePictureViewHasTheSizeOfThePicture() throws {
    let measure = EditorLayoutTranscriptTextMeasure()
    let part = TranscriptTextPart(text: Self.plainText, style: .markdown)
    let picture = try #require(measure.picture(of: part, width: Self.width, appearance: Self.lightAppearance))

    let size = NSHostingView(rootView: StaticPictureView(picture, text: part.text)).fittingSize

    #expect(size == picture.size, "\(size) \(picture.size)")
  }

  /// A production change that fails this test: a static row with a
  /// picture has another height than its real row, so the row jumps when
  /// it changes form.
  @Test func aRowWithAPictureKeepsItsHeightWhenItChangesFromStaticToReal() async throws {
    let text = Self.plainText + " The height."
    let host = await StaticRowHost.makeCached(.agent(text), width: Self.width)
    try #require(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: text)) > 0)
    let still = host.rowHeight

    host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - still) <= Self.heightTolerance, "static \(still), real \(host.rowHeight)")
  }

  // MARK: - The pixels

  /// A production change that fails this test: the picture draws the text
  /// in other fonts, colors or places than the real EditorKit editor of
  /// the row, in light or in dark.
  ///
  /// The compare reads each pixel at the same place in the two forms, with
  /// no vertical shift: EditorKit puts each baseline of the picture on the
  /// pixel row where TextKit 2 puts it in the mounted editor.
  @Test(arguments: pixelTexts, [ColorScheme.light, .dark])
  func thePictureOfARowIsNearTheRealRow(text: String, colorScheme: ColorScheme) async throws {
    let host = await StaticRowHost.makeCached(.agent(text), width: Self.width, colorScheme: colorScheme)
    try #require(host.textViewCount == 0)
    try #require(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: text)) > 0)
    let still = try host.bitmap()
    host.showAtRestAndSettle()
    try await host.awaitParse(of: text)
    let real = try host.bitmap()

    let difference = try RowPixelDifference.between(
      still, and: real, over: RowPixelDifference.background(of: colorScheme))

    #expect(difference.isWithin(meanLimit: Self.meanLimit, largePartLimit: Self.largePartLimit), "\(difference)")
  }

  // MARK: - The cache

  /// A production change that fails this test: the worker of the cache
  /// draws no picture of a Markdown text part, or draws it on the main
  /// thread.
  @Test func theWorkerDrawsThePictureOffTheMainThread() async throws {
    let measure = PictureThreadMeasure(measure: EditorLayoutTranscriptTextMeasure())
    let (cache, rowKey) = try Self.cache(measure: measure, text: Self.plainText + " Off main.")
    cache.noteAppearance(Self.lightAppearance)

    await cache.computeHeights(of: [rowKey])

    #expect(measure.pictureThreads == [false])
  }

  /// A production change that fails this test: the cache publishes no
  /// picture of the Markdown text of a row with its height.
  @Test func theCachePublishesThePictureOfARowWithItsHeight() async throws {
    let text = Self.plainText + " Published."
    let (cache, rowKey) = try Self.cache(measure: EditorLayoutTranscriptTextMeasure(), text: text)
    cache.noteAppearance(Self.lightAppearance)

    await cache.computeHeights(of: [rowKey])

    #expect(cache.picture(of: Self.markdown(text), inRow: rowKey, appearance: Self.lightAppearance) != nil)
  }

  /// A production change that fails this test: a new color scheme keeps
  /// the pictures of the old one, so a static row shows the text in the
  /// colors of the old appearance.
  @Test func aNewColorSchemeDrawsThePicturesAgain() async throws {
    let text = Self.plainText + " Dark."
    let (cache, rowKey) = try Self.cache(measure: EditorLayoutTranscriptTextMeasure(), text: text)
    cache.noteAppearance(Self.lightAppearance)
    await cache.computeHeights(of: [rowKey])
    let light = try #require(cache.picture(of: Self.markdown(text), inRow: rowKey, appearance: Self.lightAppearance)?.image)

    cache.noteAppearance(Self.darkAppearance)
    await cache.computeHeights(of: [rowKey])
    let dark = try #require(cache.picture(of: Self.markdown(text), inRow: rowKey, appearance: Self.darkAppearance)?.image)

    #expect(dark.dataProvider?.data as Data? != light.dataProvider?.data as Data?)
  }

  /// A production change that fails this test: the cache gives a picture
  /// of one appearance to a slot in another appearance.
  @Test func theCacheGivesNoPictureOfAnotherAppearance() async throws {
    let text = Self.plainText + " Scale."
    let (cache, rowKey) = try Self.cache(measure: EditorLayoutTranscriptTextMeasure(), text: text)
    cache.noteAppearance(Self.lightAppearance)
    await cache.computeHeights(of: [rowKey])

    #expect(cache.picture(of: Self.markdown(text), inRow: rowKey, appearance: Self.darkAppearance) == nil)
  }

  // MARK: - What the picture draws

  /// A production change that fails this test: the picture is drawn for a
  /// text with a part that EditorKit does not draw in a picture, so the
  /// static row loses that part.
  @Test(arguments: [
    "A table:\n\n| a | b |\n|---|---|\n| 1 | 2 |",
    "Some ~~struck~~ words.",
    "An image: ![chart](chart.png)",
    "```swift\nlet x = 1\n```",
    "Text.\n\n    indented code",
    "> [!NOTE]\n> A note.",
    "- [ ] A task.",
    "A footnote.[^1]\n\n[^1]: The note.",
    "Inline math $x^2$.",
  ])
  func thePictureIsNotDrawnForAPartThatEditorKitDoesNotDraw(text: String) {
    #expect(!StaticMarkdownPicture.draws(text))
  }

  /// A production change that fails this test: the picture is not drawn
  /// for a text with only the parts that EditorKit draws.
  @Test(arguments: pixelTexts)
  func thePictureIsDrawnForAPartThatEditorKitDraws(text: String) {
    #expect(StaticMarkdownPicture.draws(text))
  }

  /// The Markdown text part of `text`, as the slot of an answer names it.
  ///
  /// - Parameter text: The Markdown text.
  /// - Returns: The text part.
  static func markdown(_ text: String) -> TranscriptTextPart {
    TranscriptTextPart(text: text, style: .markdown)
  }

  /// A height cache of the one agent answer `text`, with the probe metrics,
  /// and the row key of the answer. The cache knows the row.
  ///
  /// - Parameters:
  ///   - measure: The text measure of the cache.
  ///   - text: The Markdown text of the answer.
  /// - Returns: The cache and the row key.
  static func cache(
    measure: any TranscriptTextMeasure, text: String
  ) throws -> (cache: TranscriptRowHeights, rowKey: String) {
    let session = SessionModel.preview(transcript: [.agent(text)])
    let entry = try #require(session.transcript.first)
    let cache = TranscriptRowHeights(measure: measure, metrics: TranscriptRowMetrics.probe())
    _ = cache.register([entry], width: width)
    return (cache, entry.rowKey)
  }
}

/// A text measure that records, for each picture that it draws, whether the
/// call ran on the main thread. The heights come from EditorKit's measure.
nonisolated final class PictureThreadMeasure: TranscriptTextMeasure {
  /// The measure of the heights and the pictures.
  private let measure: EditorLayoutTranscriptTextMeasure

  /// Makes a measure that records the threads of the pictures of
  /// `measure`.
  ///
  /// - Parameter measure: The measure of the heights and the pictures.
  init(measure: EditorLayoutTranscriptTextMeasure) {
    self.measure = measure
  }

  /// Whether each picture call ran on the main thread, in the order of the
  /// calls.
  private let threads = OSAllocatedUnfairLock<[Bool]>(initialState: [])

  func height(of part: TranscriptTextPart, width: CGFloat) -> CGFloat {
    measure.height(of: part, width: width)
  }

  func isExact(_ part: TranscriptTextPart) -> Bool {
    measure.isExact(part)
  }

  func picture(
    of part: TranscriptTextPart, width: CGFloat, appearance: TranscriptTextAppearance
  ) -> EditorStaticRendering? {
    threads.withLock { $0.append(Thread.isMainThread) }
    return measure.picture(of: part, width: width, appearance: appearance)
  }

  /// Whether each picture call ran on the main thread, in the order of the
  /// calls.
  var pictureThreads: [Bool] {
    threads.withLock { $0 }
  }
}
