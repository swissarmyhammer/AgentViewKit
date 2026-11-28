import CoreGraphics
import SwiftUI
import Testing

@testable import AgentViewKit

/// The chrome rule of each row kind gives the height of the mounted row,
/// when the text parts have the heights of the mounted EditorKit views
/// (card ^9h7bm9j).
///
/// Each test case mounts one row kind at one width: a user message, an agent
/// message of prose, an agent message with a code fence, a collapsed
/// thought, a collapsed tool call card, an expanded call with a diff, an
/// expanded call with command output, a terminal, a plan, an error notice,
/// a compaction notice and a message from another session.
@MainActor @Suite struct TranscriptRowChromeTests {
  @Test(arguments: TranscriptRowFixtures.Row.allCases, TranscriptRowHeightBed.widths)
  func theChromeRuleGivesTheMountedHeight(row: TranscriptRowFixtures.Row, width: CGFloat) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, expanded: row.isExpanded)
  }

  // MARK: - The footer of a message (card ^grwk69d)

  /// A production change that fails this test: the chrome rule of a message
  /// row gives no height to its footer of ``MessageActions``, or another
  /// height than the mounted footer, so the row jumps when it becomes real.
  @Test(arguments: TranscriptRowFixtures.messageRows, TranscriptRowHeightBed.widths)
  func theChromeRuleGivesTheMountedHeightOfAMessageWithActions(
    row: TranscriptRowFixtures.Row, width: CGFloat
  ) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, tolerance: TranscriptRowHeightBed.exactTolerance,
      messageFooter: TranscriptRowFixtures.messageActions)
  }

  /// A production change that fails this test: after a resize, the cache
  /// gives a message row with a footer of ``MessageActions`` the height of
  /// the old width, or a height with no footer.
  @Test(arguments: TranscriptRowFixtures.messageRows, TranscriptRowHeightBed.widths)
  func theChromeRuleGivesTheMountedHeightOfAMessageWithActionsAfterAResize(
    row: TranscriptRowFixtures.Row, width: CGFloat
  ) async throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    try await TranscriptRowHeightBed.expectCachedHeightMatchesTheMountedRow(
      entry, width: width, tolerance: TranscriptRowHeightBed.exactTolerance,
      widthBefore: TranscriptRowHeightBed.widthBeforeResize, messageFooter: TranscriptRowFixtures.messageActions)
  }

  /// A production change that fails this test: a message row with a
  /// custom footer, whose height no rule knows, gets a height from a rule,
  /// so the row jumps when it becomes real.
  @Test(arguments: TranscriptRowFixtures.messageRows)
  func noChromeRuleCoversAMessageWithACustomFooter(row: TranscriptRowFixtures.Row) throws {
    let entry = try TranscriptRowHeightBed.entry([row.item])
    let content = TranscriptRowContent(entry: entry, isExpanded: false, footer: .custom)

    #expect(TranscriptRowChrome.layout(of: content, metrics: TranscriptRowMetrics.probe()) == nil)
  }

  /// A production change that fails this test: the footer of a function
  /// that makes ``MessageActions`` is not a footer of the message actions,
  /// so the height cache of the thread does not cover its message rows.
  @Test func aFooterOfMessageActionsHasTheKindOfTheMessageActions() {
    #expect(TranscriptRowFixtures.messageActions.kind == .messageActions)
  }

  /// A production change that fails this test: a footer of another view is
  /// a footer of the message actions, so the cache gives its message rows
  /// the height of the actions.
  @Test func aFooterOfAnotherViewIsCustom() {
    #expect(MessageFooter { _ in Text(verbatim: "Custom") }.kind == .custom)
  }
}
