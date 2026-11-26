import CoreGraphics
import Testing

@testable import AgentViewKit

/// The chrome rule of each row kind gives the height of the mounted row,
/// when the text parts have the heights of the mounted EditorKit views
/// (card ^9h7bm9j).
///
/// Each test case mounts one row kind at one width: a user message, an agent
/// message of prose, an agent message with a code fence, a collapsed
/// thought, a collapsed tool call card, an expanded call with a diff, an
/// expanded call with command output, a terminal, a plan and an error
/// notice.
@MainActor @Suite struct TranscriptRowChromeTests {
  @Test(arguments: TranscriptRowFixtures.Row.allCases, TranscriptRowHeightBed.widths)
  func theChromeRuleGivesTheMountedHeight(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded)
  }
}
