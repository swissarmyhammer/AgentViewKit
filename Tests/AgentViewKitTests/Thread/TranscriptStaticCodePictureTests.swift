import AppKit
import SwiftUI
import Testing

@testable import AgentViewKit

/// The pictures of the static code of the rows of a thread (card ^9ync5h3).
///
/// While the rows move, a code slot of a static row (``StaticCodeText``: a
/// code block, a command output or a terminal) shows a picture that
/// EditorKit drew off the main thread
/// (`EditorLayoutMeasure.render(code:width:style:grammar:gutter:)`), in
/// place of its SwiftUI `Text`. Each row shows in a ``StaticRowHost``: a
/// borderless window that is never ordered in.
@MainActor @Suite struct TranscriptStaticCodePictureTests {
  /// The width of the rows, in points.
  static let width: CGFloat = 480

  /// The rows of the pixel checks: a Swift fence (TextMate colors), a fence
  /// of twelve lines with a line that wraps (a gutter of two digits), a
  /// fence with no language, a JSON fence (tree-sitter colors), a command
  /// output and a terminal.
  nonisolated static let pixelRows: [TranscriptRowFixtures.Row] = [
    .agentFenced, .agentFencedLong, .agentFencedPlain, .agentFencedJSON, .commandOutput, .terminal,
  ]

  /// The code parts of the measure checks: code with a grammar, code with
  /// no language, and an output.
  nonisolated static let codeParts = [
    TranscriptTextPart(text: "let rows = heights.count\nprint(rows)", style: .code(language: "swift")),
    TranscriptTextPart(
      text: "let summary = rows.filter { $0.isVisible }.map { row in row.title + \": \" + row.detail }",
      style: .code(language: nil)),
    TranscriptTextPart(text: "Building...\nBuild complete.\n", style: .output),
  ]

  // MARK: - The measure

  /// A production change that fails this test: the measure draws no
  /// picture of code or of an output, so a static code slot lays out its
  /// SwiftUI `Text` on the main thread while the list moves.
  @Test(arguments: codeParts)
  func theMeasureDrawsAPictureOfCode(part: TranscriptTextPart) {
    let measure = EditorLayoutTranscriptTextMeasure()

    #expect(measure.picture(of: part, width: Self.width, appearance: TranscriptStaticPictureTests.lightAppearance) != nil)
  }

  /// A production change that fails this test: the picture of code has
  /// another height than the measure of the code, so the cache drops the
  /// picture, or the row moves when it changes form.
  @Test(arguments: codeParts)
  func thePictureOfCodeHasTheMeasuredHeight(part: TranscriptTextPart) throws {
    let measure = EditorLayoutTranscriptTextMeasure()
    let picture = try #require(
      measure.picture(of: part, width: Self.width, appearance: TranscriptStaticPictureTests.lightAppearance))

    #expect(picture.size.height == measure.height(of: part, width: Self.width))
  }

  // MARK: - The slot

  /// A production change that fails this test: the code slot of a static
  /// row shows its SwiftUI `Text` while the cache has its picture.
  @Test func aStaticCodeSlotWithAReadyPictureShowsThePicture() async {
    let code = "let picture = \"slot\""
    _ = await StaticRowHost.makeCached(.agent("The code:\n\n```swift\n" + code + "\n```"), width: Self.width)

    #expect(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: code)) > 0)
  }

  /// A production change that fails this test: the output slot of a static
  /// row shows its SwiftUI `Text` while the cache has its picture.
  @Test func aStaticOutputSlotWithAReadyPictureShowsThePicture() async {
    let output = "Picture of the output.\n"
    _ = await StaticRowHost.makeCached(TranscriptRowFixtures.run(output: output), width: Self.width, isExpanded: true)

    #expect(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: Self.shownText(of: output))) > 0)
  }

  /// A production change that fails this test: an output with ANSI colors
  /// shows the picture, which draws no color run, so the static row loses
  /// the colors of the output.
  @Test func anOutputWithColorsKeepsItsText() async {
    let output = "\u{1B}[31mA red line of the output.\u{1B}[0m\n"
    _ = await StaticRowHost.makeCached(TranscriptRowFixtures.run(output: output), width: Self.width, isExpanded: true)

    #expect(BodyEvaluationCounter.count(StaticPictureView.counterKey(for: Self.shownText(of: output))) == 0)
  }

  /// The text that a command output view shows of `output`: its rows, as
  /// the terminal rules parse them (``TerminalOutput``).
  ///
  /// - Parameter output: The output text, with its escape sequences.
  /// - Returns: The text of the rows that show.
  static func shownText(of output: String) -> String {
    TerminalOutput(
      output: output, palette: EnvironmentValues().editorTheme.terminalPalette,
      limit: CommandOutputView.defaultRowLimit
    ).rows.text
  }

  // MARK: - The pixels

  /// A production change that fails this test: the picture draws the code
  /// in other fonts, colors or places than the real EditorKit editor of
  /// the row, in light or in dark: the syntax colors, the line numbers and
  /// the lines that wrap. The compare reads each pixel at the same place in
  /// the two forms, with no vertical shift.
  @Test(arguments: pixelRows, [ColorScheme.light, .dark])
  func thePictureOfACodeRowIsNearTheRealRow(row: TranscriptRowFixtures.Row, colorScheme: ColorScheme) async throws {
    let host = await StaticRowHost.makeCached(row, width: Self.width, colorScheme: colorScheme)
    try #require(host.textViewCount == 0)
    let still = try host.bitmap()
    host.showAtRestAndSettle()
    await host.awaitSegmentParses()
    let real = try host.bitmap()

    let difference = try RowPixelDifference.between(
      still, and: real, over: RowPixelDifference.background(of: colorScheme))

    #expect(
      difference.isWithin(
        meanLimit: TranscriptStaticPictureTests.meanLimit, largePartLimit: TranscriptStaticPictureTests.largePartLimit),
      "\(difference)")
  }
}
