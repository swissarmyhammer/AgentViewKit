import CoreGraphics
import EditorTheme
import Testing

@testable import AgentViewKit

/// The cache with the default text measure, EditorKit's
/// `EditorLayoutMeasure` (``EditorLayoutTranscriptTextMeasure``), gives the
/// height of each mounted row kind (card ^9h7bm9j).
///
/// Each test case mounts one row kind at one width, computes its height in a
/// cache with the default measure, and compares the two heights. The chrome
/// tests (`TranscriptRowChromeTests`) check the chrome alone, with the
/// heights of the mounted text views. These tests also check the text.
@MainActor @Suite
struct TranscriptRowMeasureTests {
  @Test(arguments: TranscriptRowFixtures.Row.allCases, TranscriptRowHeightBed.widths)
  func theDefaultMeasureGivesTheMountedHeight(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded, measure: EditorLayoutTranscriptTextMeasure())
  }

  /// A production change that fails this test: the measure of a code block,
  /// a command output or a diff does not use the grammar, the gutter or the
  /// font of the mounted EditorKit view, so the height of the cache differs
  /// from the height of the mounted row (card ^9ync5h3).
  @Test(arguments: TranscriptRowFixtures.Row.codeRows, TranscriptRowHeightBed.widths)
  func theMeasureOfACodeRowIsTheMountedHeightExactly(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded, measure: EditorLayoutTranscriptTextMeasure(),
      tolerance: TranscriptRowHeightBed.exactTolerance)
  }

  /// A production change that fails this test: the measure takes a code
  /// block, a command output or a diff for not exact, so the cache gives no
  /// height to the static form of the row (card ^9ync5h3).
  @Test(arguments: TranscriptRowFixtures.Row.codeRows)
  func theCacheTakesTheHeightOfACodeRowForExact(row: TranscriptRowFixtures.Row) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    let heights = TranscriptRowHeights(
      metrics: TranscriptRowMetrics.probe(), expandedBlocks: ExpandedBlocksStore { _ in row.isExpanded })
    _ = try await TranscriptRowHeightBed.cachedHeight(
      of: entry, in: heights, width: TranscriptRowHeightBed.regularWidth)

    #expect(heights.knowsHeight(of: entry.id))
  }

  /// A production change that fails this test: the measure of a Markdown
  /// part does not give the height of the EditorKit layout of inline math,
  /// block math or a wrapped line with inline code, so the height of the
  /// cache differs from the height of the mounted row (card ^v2nh2hq).
  @Test(arguments: TranscriptRowFixtures.Row.measuredMarkdownRows, TranscriptRowHeightBed.widths)
  func theMeasureOfAMeasuredMarkdownRowIsTheMountedHeightExactly(
    row: TranscriptRowFixtures.Row, width: CGFloat
  ) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded, measure: EditorLayoutTranscriptTextMeasure(),
      tolerance: TranscriptRowHeightBed.exactTolerance)
  }

  /// A production change that fails this test: the measure takes inline
  /// math, block math or a wrapped line with inline code for not exact, so
  /// the cache gives no height to the static form of the row (card
  /// ^v2nh2hq).
  @Test(arguments: TranscriptRowFixtures.Row.measuredMarkdownRows)
  func theCacheTakesTheHeightOfAMeasuredMarkdownRowForExact(row: TranscriptRowFixtures.Row) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    let heights = TranscriptRowHeights(
      metrics: TranscriptRowMetrics.probe(), expandedBlocks: ExpandedBlocksStore { _ in row.isExpanded })
    _ = try await TranscriptRowHeightBed.cachedHeight(
      of: entry, in: heights, width: TranscriptRowHeightBed.regularWidth)

    #expect(heights.knowsHeight(of: entry.id))
  }

  /// A production change that fails this test: the measure gives EditorKit
  /// no natural size of the image of an answer, or another size than the
  /// size of the loaded image, so the height of the cache differs from the
  /// height of the row with the loaded image (card ^9ync5h3).
  @Test(arguments: TranscriptRowHeightBed.widths)
  func theMeasureOfAnAnswerWithAnImageIsTheMountedHeightExactly(width: CGFloat) async throws {
    let images = try TranscriptImageFixtures()
    defer { images.folder.remove() }
    let session = images.session()
    let entry = try #require(session.transcript.first)
    let metrics = TranscriptRowMetrics.probe()
    let loading = try await TranscriptRowHeightBed.cachedHeight(
      of: entry, in: TranscriptRowHeights(metrics: metrics), width: width)
    let withImage = TranscriptRowHeights(
      measure: EditorLayoutTranscriptTextMeasure(imageFolder: images.folder.url), metrics: metrics)
    let cached = try await TranscriptRowHeightBed.cachedHeight(of: entry, in: withImage, width: width)

    let mounted = await TranscriptRowHeightBed.mountAfterImageLoad(
      entry, session: session, width: width, loadingHeight: loading)

    #expect(withImage.knowsHeight(of: entry.id))
    #expect(cached == mounted, "cached \(cached), mounted \(mounted)")
  }

  /// A production change that fails this test: the cache of a thread does
  /// not give its text measure the image folder of the session, so an
  /// answer with an image never shows its static form from its first frame.
  @Test func theCacheOfAThreadMeasuresTheImagesOfTheFolderOfTheSession() async throws {
    let images = try TranscriptImageFixtures()
    defer { images.folder.remove() }
    let session = images.session()
    let entry = try #require(session.transcript.first)
    let cache = try #require(
      TranscriptStaticRowHeights.makeCache(
        theme: SystemTheme(), expandedBlocks: ExpandedBlocksStore(), hasDefaultLook: true,
        imageFolder: RenderedMarkdownView.imageFolder(of: session)))
    _ = try await TranscriptRowHeightBed.cachedHeight(of: entry, in: cache, width: TranscriptRowHeightBed.regularWidth)

    #expect(cache.knowsHeight(of: entry.id))
  }
}
