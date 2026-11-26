import CoreGraphics
import Testing

@testable import AgentViewKit

/// The cache with the default text measure gives the height of each mounted
/// row kind (card ^9h7bm9j).
///
/// These tests depend on the exact EditorKit measure, `EditorLayoutMeasure`
/// (EditorKit card ^ep9f55d). EditorKit main does not have it yet, and the
/// interim measure is not exact, so the suite is disabled. When the measure
/// lands, make it the default measure of ``TranscriptRowHeights`` and enable
/// the suite.
@MainActor @Suite(.disabled("EditorKit main has no EditorLayoutMeasure yet (EditorKit card ^ep9f55d)"))
struct TranscriptRowMeasureTests {
  @Test(arguments: TranscriptRowFixtures.Row.allCases, TranscriptRowHeightBed.widths)
  func theDefaultMeasureGivesTheMountedHeight(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded, measure: InterimTranscriptTextMeasure())
  }
}
