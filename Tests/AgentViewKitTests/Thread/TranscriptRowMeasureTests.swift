import CoreGraphics
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
}
