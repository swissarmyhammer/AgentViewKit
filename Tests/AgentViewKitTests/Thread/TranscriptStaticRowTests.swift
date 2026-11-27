import AppKit
import EditorCommands
import FoundationModelsACP
import FoundationModelsACPClient
import SwiftUI
import Testing

@testable import AgentViewKit

/// The static form of the rows of a thread while the rows move, and the
/// real form at rest (card ^9ync5h3).
///
/// Each row shows in a ``StaticRowHost``: a borderless window that is never
/// ordered in. The tests read the EditorKit text views of the row, its
/// height, and the pixel rows of its text.
@MainActor @Suite struct TranscriptStaticRowTests {
  /// The widths of the frame check, in points.
  nonisolated static let widths: [CGFloat] = [320, 480, 720]

  /// The largest difference between the heights of the two forms of a row,
  /// in points.
  static let heightTolerance: CGFloat = 0.5

  /// The largest difference between the pixel rows of a text line in the
  /// two forms of a row, in pixels.
  static let pixelTolerance = 1

  /// The text of a plain agent answer: two paragraphs, the first of which
  /// wraps at the narrow widths.
  static let plainText =
    "The parser reads each line of the file, and it keeps the tokens of the line in order.\n\nIt stops at the first error."

  /// The text of an agent answer with headings of three levels.
  static let headingText =
    "# Parser\n\nThe parser reads each line.\n\n## Errors\n\nIt stops at the first error.\n\n### Next\n\nFix the lexer."

  /// A plain agent answer.
  static let plainAnswer = PreviewTranscriptItem.agent(plainText)


  /// One item of each row kind.
  static func itemOfEachKind() throws -> [PreviewTranscriptItem] {
    [
      .user("Read the parser file."),
      plainAnswer,
      .thought("I read the file first, and then the tests."),
      .toolCall(title: "Read parser.swift", kind: .read, status: .completed),
      .plan([PlanEntry(content: "Fix the lexer", priority: .high, status: .inProgress)]),
      .terminal(command: "swift build", output: "Building for debugging\nBuild complete.", exitCode: 0),
      .error(code: .internalError, message: "The agent stopped before it sent an answer."),
      try PreviewTranscriptItem.decodedUpdate(
        #"""
        {"sessionUpdate": "compaction_update", "compactionId": "static-row-compaction", "status": "completed",
         "summary": [{"type": "text", "text": "The parser work so far."}]}
        """#),
      try PreviewTranscriptItem.decodedUpdate(
        #"""
        {"sessionUpdate": "session_message", "messageId": "static-row-mail", "senderSessionId": "child-1",
         "content": [{"type": "text", "text": "The lexer change is ready."}]}
        """#),
      try PreviewTranscriptItem.decodedUpdate(#"{"sessionUpdate": "x_static_row_update", "note": "first"}"#),
    ]
  }

  // MARK: - The motion signal

  /// A production change that fails this test: an idle phase moves the
  /// rows, so the rows never show their real forms.
  @Test func anIdlePhaseDoesNotMove() {
    #expect(!TranscriptRowMotion.isMoving(.idle))
  }

  /// A production change that fails this test: a flick that decelerates
  /// does not move the rows, so each row mounts its editors in the flick.
  @Test func eachPhaseThatIsNotIdleMoves() {
    let phases: [ScrollPhase] = [.tracking, .interacting, .decelerating, .animating]

    #expect(phases.allSatisfy(TranscriptRowMotion.isMoving))
  }

  /// A production change that fails this test: an open jump session does
  /// not stop the motion, so the jump labels stand on static rows.
  @Test func anOpenJumpSessionStopsTheMotion() {
    #expect(!TranscriptRowMotion.rowsMove(isMoving: true, isJumping: true))
  }

  // MARK: - The form of a row

  /// A production change that fails this test: a row that comes into the
  /// list while the rows move mounts its editors.
  @Test func aRowThatEntersWhileTheRowsMoveIsStatic() {
    let host = StaticRowHost(Self.plainAnswer, width: Self.widths[1])

    host.enterWhileMoving()

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: a row in view at rest takes
  /// its static form when the rows start to move, so the start of a flick
  /// swaps the editors of each row in view.
  @Test func aRowThatIsRealWhenTheRowsStartToMoveStaysReal() async {
    let host = StaticRowHost(Self.plainAnswer, width: Self.widths[1])
    await host.showAtRestAndSettle()

    host.show(rowsMove: true)

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: the hold of a row that was
  /// real at rest does not keep the row real.
  @Test func aRowThatWasRealAtRestHoldsItsRealForm() {
    let holds = TranscriptRowHolds(wasRealAtRest: true)

    #expect(!TranscriptRowForm.isStatic(rowsMove: true, waitsToMount: false, holds: holds, knowsHeight: true))
  }

  /// A production change that fails this test: the row keeps its static
  /// form after the rows stop.
  @Test func aRowShowsItsRealFormAtRest() {
    let host = StaticRowHost(Self.plainAnswer, width: Self.widths[1])
    host.enterWhileMoving()

    host.show(rowsMove: false)

    #expect(host.textViewCount > 0)
  }

  /// A production change that fails this test: the focus does not hold the
  /// row, so the row that holds the keyboard focus shows its static form.
  @Test func aRowWithTheFocusStaysReal() {
    let holds = TranscriptRowHolds(hasFocus: true)

    #expect(!TranscriptRowForm.isStatic(rowsMove: true, waitsToMount: false, holds: holds, knowsHeight: true))
  }

  /// A production change that fails this test: the focus check does not
  /// look through the scopes in the item scope of the row, so a focused
  /// code block of an answer does not hold the row.
  @Test func theFocusInAScopeOfTheItemScopeIsTheFocusOfTheRow() {
    let segment = AgentScopeKind.message(rowKey: "agent-message-static")
    let path = FocusPath([FocusSegment(kind: "thread", id: "t"), segment, FocusSegment(kind: "codeBlock", id: "0")])

    #expect(TranscriptRowHolds.hasFocus(itemScope: segment, focusedPath: path))
  }

  /// A production change that fails this test: the focus in a different
  /// row holds this row.
  @Test func theFocusInADifferentRowIsNotTheFocusOfTheRow() {
    let segment = AgentScopeKind.message(rowKey: "agent-message-static")
    let path = FocusPath([AgentScopeKind.message(rowKey: "agent-message-other")])

    #expect(!TranscriptRowHolds.hasFocus(itemScope: segment, focusedPath: path))
  }

  /// A production change that fails this test: a row with no known height
  /// shows its static form, which then has no height of the real row and
  /// jumps.
  @Test func aRowWithNoKnownHeightStaysReal() {
    #expect(!TranscriptRowForm.isStatic(rowsMove: true, waitsToMount: false, holds: TranscriptRowHolds(), knowsHeight: false))
  }

  /// A production change that fails this test: each hold keeps the row
  /// real, but a row with no hold is not static either.
  @Test func aRowWithNoHoldAndAKnownHeightIsStaticWhileTheRowsMove() {
    #expect(TranscriptRowForm.isStatic(rowsMove: true, waitsToMount: false, holds: TranscriptRowHolds(), knowsHeight: true))
  }

  /// A production change that fails this test: the hover, the selection or
  /// the stream does not hold the row.
  @Test func eachOtherHoldKeepsTheRowReal() {
    let holds = [
      TranscriptRowHolds(isHovered: true), TranscriptRowHolds(hasSelection: true),
      TranscriptRowHolds(streams: true),
    ]

    #expect(holds.allSatisfy { !TranscriptRowForm.isStatic(rowsMove: true, waitsToMount: false, holds: $0, knowsHeight: true) })
  }

  // MARK: - The height of the static form

  /// A production change that fails this test: the static form of a row
  /// kind has its own height, so the row jumps when it changes form.
  @Test(arguments: widths)
  func theStaticFormOfEachRowKindHasTheHeightOfTheRealRow(width: CGFloat) throws {
    let results = try Self.itemOfEachKind().map { item in
      let host = StaticRowHost(item, width: width)
      let real = host.rowHeight
      host.enterWhileMoving()
      return (kind: String(describing: host.entry).prefix(while: { $0 != "(" }), real: real, still: host.rowHeight)
    }

    let differing = results.filter { abs($0.real - $0.still) > Self.heightTolerance }
    #expect(differing.isEmpty, "\(results)")
  }

  /// A production change that fails this test: the record of the real row
  /// gives the height of a different width, so the static form of a row
  /// after a resize keeps the old height.
  @Test func theRecordGivesNoHeightAtADifferentWidth() {
    let id = TranscriptEntry.ID.local(UUID())
    let heights = TranscriptMeasuredRowHeights()
    heights.record(CGSize(width: Self.widths[0], height: Self.widths[1]), for: id)

    #expect(heights.height(of: id, width: Self.widths[2]) == nil)
  }

  // MARK: - The height cache of the static form

  /// The row kinds whose text parts are each exact with the default text
  /// measure (``EditorLayoutTranscriptTextMeasure``): a row of these kinds
  /// is static from its first frame. The rows with a code block, a command
  /// output or a diff (``TranscriptRowFixtures/Row/codeRows``) are exact
  /// with the EditorKit measure of code.
  nonisolated static let exactRows: [TranscriptRowFixtures.Row] =
    [.userMessage, .agentProse, .thought, .toolCall, .terminal, .plan, .notice, .compaction, .sessionMessage]
    + TranscriptRowFixtures.Row.codeRows

  /// A production change that fails this test: the rows do not take the
  /// heights of the cache, so a row seen for the first time stays real
  /// while the rows move.
  @Test func anExactRowSeenForTheFirstTimeIsStaticWhileTheRowsMove() async {
    let host = await StaticRowHost.makeCached(.agentProse, width: Self.widths[1])

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the cache gives no height
  /// of a row kind whose text parts are each exact.
  @Test(arguments: exactRows)
  func theCacheKnowsTheHeightOfAnExactRowSeenForTheFirstTime(row: TranscriptRowFixtures.Row) async {
    let host = await StaticRowHost.makeCached(row, width: Self.widths[1])

    #expect(host.cacheKnowsHeight)
  }

  /// A production change that fails this test: the measure of a code block,
  /// a command output or a diff is not exact, so a row with one of them
  /// mounts its EditorKit views in its first frame of a live motion.
  @Test(arguments: TranscriptRowFixtures.Row.codeRows)
  func aCodeRowSeenForTheFirstTimeIsStaticInALiveMotion(row: TranscriptRowFixtures.Row) async {
    let host = await StaticRowHost.makeCached(row, width: Self.widths[1])

    #expect(host.textViewCount == 0)
  }

  /// A production change that fails this test: the text of a row with math
  /// shows its still form (``StaticMarkdownText``) in a live motion. The
  /// still form has no math, so it shows the TeX source, such as
  /// `$\frac{a}{b}$`, in place of each formula (card ^hh39bp4).
  @Test(arguments: TranscriptRowFixtures.Row.mathRows)
  func theTextOfAMathRowSeenForTheFirstTimeKeepsItsEditorInALiveMotion(row: TranscriptRowFixtures.Row) async {
    let host = await StaticRowHost.makeCached(row, width: Self.widths[1])

    #expect(host.textViewCount == 1)
  }

  /// A production change that fails this test: the cache height of an
  /// exact row kind is not the height of the real row, so the row jumps
  /// when it changes from static to real.
  @Test(arguments: exactRows, widths)
  func aCachedRowKeepsItsFrameHeightWhenItChangesFromStaticToReal(
    row: TranscriptRowFixtures.Row, width: CGFloat
  ) async throws {
    let host = await StaticRowHost.makeCached(row, width: width)
    try #require(host.cacheKnowsHeight)
    let still = host.rowHeight

    await host.showAtRestAndSettle()

    #expect(abs(host.rowHeight - still) <= Self.heightTolerance, "static \(still), real \(host.rowHeight)")
  }

  // MARK: - The pixels of the text

  /// The bands of the text lines of a row in its real form and in its
  /// static form.
  ///
  /// The test waits until the parse of the real text lands, so the real
  /// text shows the styles of the parse.
  ///
  /// - Parameter text: The Markdown text of an agent answer.
  /// - Returns: The bands of each form, from the top.
  static func inkBands(of text: String) async throws -> (real: [ClosedRange<Int>], still: [ClosedRange<Int>]) {
    let host = StaticRowHost(.agent(text), width: widths[1])
    try await host.awaitParse(of: text)
    let real = InkBands.bands(in: try host.bitmap())
    host.enterWhileMoving()
    try #require(host.textViewCount == 0)
    return (real, InkBands.bands(in: try host.bitmap()))
  }

  /// A production change that fails this test: the static text of a plain
  /// answer has another line height or another top inset than the
  /// EditorKit text, so its lines jump when the row changes form.
  @Test func theLinesOfAPlainAnswerStandAtTheSamePixelRowsInEachForm() async throws {
    let bands = try await Self.inkBands(of: Self.plainText)

    #expect(InkBands.match(bands.real, bands.still, tolerance: Self.pixelTolerance), "\(bands)")
  }

  /// A production change that fails this test: the static text gives a
  /// heading one row, or puts the glyphs of a heading at the top of its
  /// rows, so the heading and the lines below it jump when the row changes
  /// form.
  ///
  /// EditorKit draws the glyphs of a level 1 heading one pixel taller than
  /// SwiftUI does, so the top edges of that line differ by two pixels. The
  /// test thus compares the baselines of the lines.
  @Test func theLinesOfAnAnswerWithHeadingsHaveTheSameBaselinesInEachForm() async throws {
    let bands = try await Self.inkBands(of: Self.headingText)

    #expect(InkBands.matchBaselines(bands.real, bands.still, tolerance: Self.pixelTolerance), "\(bands)")
  }

  // MARK: - The selection of a row

  /// A production change that fails this test: a claim in the row does not
  /// hold the row.
  @Test func aClaimInTheRowHoldsTheSelection() {
    let thread = ThreadTextSelection()
    let row = TranscriptRowSelection()
    _ = row.forwarding(to: thread)

    row.claim(NSObject()) {}

    #expect(row.holdsSelection)
  }

  /// A production change that fails this test: the row keeps its hold after
  /// a text area of a different row claims the selection.
  @Test func aClaimInADifferentRowEndsTheHold() {
    let thread = ThreadTextSelection()
    let row = TranscriptRowSelection()
    _ = row.forwarding(to: thread)
    let area = NSObject()

    withExtendedLifetime(area) {
      row.claim(area) {}
      thread.claim(NSObject()) {}
    }

    #expect(!row.holdsSelection)
  }

  // MARK: - The lines of the static Markdown

  /// A production change that fails this test: a level 2 heading takes one
  /// row, as EditorKit gives it two.
  @Test func aLevelTwoHeadingTakesTwoRows() {
    #expect(StaticMarkdownLine.line("## Errors").rowScale == StaticMarkdownLine.headingRowScale)
  }

  /// A production change that fails this test: a level 3 heading takes two
  /// rows.
  @Test func aLevelThreeHeadingTakesOneRow() {
    #expect(StaticMarkdownLine.line("### Next").rowScale == 1)
  }

  /// A production change that fails this test: the static text shows the
  /// marker of a heading, which EditorKit conceals.
  @Test func aHeadingConcealsItsMarker() {
    #expect(String(StaticMarkdownLine.line("# Parser").text.characters) == "Parser")
  }

  /// A production change that fails this test: the static text shows the
  /// dash of a bullet item, which EditorKit shows as a bullet.
  @Test func aBulletItemShowsABullet() {
    #expect(String(StaticMarkdownLine.line("- Fix the lexer").text.characters) == "•\tFix the lexer")
  }

  /// A production change that fails this test: a blank line takes no row.
  @Test func aBlankLineIsOneLine() {
    #expect(StaticMarkdownLine.lines(in: "One\n\nTwo").count == 3)
  }
  /// A production change that fails this test: the static text shows each
  /// line of a plain answer in its own `Text`, so a row draws one text
  /// layer for each line.
  @Test func thePlainLinesOfAnAnswerAreOneBlock() {
    #expect(StaticMarkdownLine.blocks(in: Self.plainText).count == 1)
  }

  /// A production change that fails this test: a block joins the lines
  /// with no line break, or drops the blank line, so the lines of the block
  /// stand in other rows.
  @Test func aBlockKeepsTheLineBreaksOfItsLines() {
    let block = StaticMarkdownLine.blocks(in: "One\n\n- Two")

    #expect(block.map { String($0.text.characters) } == ["One\n \n•\tTwo"])
  }

  /// A production change that fails this test: a heading joins the block of
  /// the lines around it, so it takes the font and the rows of the body.
  @Test func eachHeadingIsABlockOfItsOwn() {
    let levels = StaticMarkdownLine.blocks(in: Self.headingText).map(\.headingLevel)

    #expect(levels == [1, nil, 2, nil, 3, nil])
  }
}
