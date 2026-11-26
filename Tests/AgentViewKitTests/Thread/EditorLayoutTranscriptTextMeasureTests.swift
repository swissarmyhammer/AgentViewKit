import AgentViewKitTestSupport
import EditorTheme
import Testing

@testable import AgentViewKit

/// The parts for which the EditorKit text measure gives the height of the
/// mounted view (card ^9h7bm9j).
///
/// A static row takes the height of the cache only when each text part of
/// the row is exact. The parity tests (`TranscriptRowMeasureTests`) compare
/// the heights with the mounted rows.
@MainActor @Suite struct EditorLayoutTranscriptTextMeasureTests {
  /// Plain prose with no Markdown markup.
  static let prose = "The parser reads each line of the file.\n\nIt stops at the first error."

  /// Tells if the measure of the default theme is exact for a part.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - style: The style of the part.
  /// - Returns: Whether the measure is exact for the part.
  static func isExact(_ text: String, _ style: TranscriptTextPart.Style) -> Bool {
    EditorLayoutTranscriptTextMeasure().isExact(TranscriptTextPart(text: text, style: style))
  }

  /// A production change that fails this test: plain prose is not exact,
  /// so an agent answer never shows its static form from its first frame.
  @Test func plainProseIsExact() {
    #expect(Self.isExact(Self.prose, .markdown))
  }

  /// A production change that fails this test: the measure takes a heading
  /// for not exact, but EditorKit measures the rows of a heading.
  @Test func markdownWithAHeadingIsExact() {
    #expect(Self.isExact("# Parser\n\n" + Self.prose, .markdown))
  }

  /// A production change that fails this test: the measure takes a list
  /// for not exact, but EditorKit measures the hanging indent of a list.
  @Test func markdownWithAListItemIsExact() {
    #expect(Self.isExact("- Fix the lexer\n- Fix the parser", .markdown))
  }

  /// A production change that fails this test: the measure takes an image
  /// for exact, but the height of an image comes from its view.
  @Test func markdownWithAnImageIsNotExact() {
    #expect(!Self.isExact("![The parser](parser.png)", .markdown))
  }

  /// A production change that fails this test: the measure takes math for
  /// exact, but the height of a formula comes from its view.
  @Test func markdownWithMathIsNotExact() {
    #expect(!Self.isExact("The cost is $n^2$ for each row.", .markdown))
  }

  /// A production change that fails this test: the measure takes code with
  /// a line number gutter for exact, but EditorKit has no measure of the
  /// gutter (EditorKit ^v8t0pka), and a code block row jumps when it changes
  /// form.
  @Test func codeWithALineNumberGutterIsNotExact() {
    #expect(!Self.isExact("let rows = 2", .code(language: "swift")))
  }

  /// A production change that fails this test: the output of a command is
  /// not exact, so a terminal never shows its static form from its first
  /// frame.
  @Test func outputIsExact() {
    #expect(Self.isExact("Build complete.", .output))
  }

  /// A production change that fails this test: the measure takes a diff
  /// for exact, but EditorKit has no measure of the gutters of a diff.
  @Test func aDiffIsNotExact() {
    #expect(!Self.isExact("+let name = \"new\"", .diff))
  }

  /// A production change that fails this test: the explanation label of a
  /// notice is not exact, so a notice never shows its static form from its
  /// first frame.
  @Test func theCalloutLabelOfANoticeIsExact() {
    #expect(Self.isExact(Self.prose, .label(.ui(.callout))))
  }

  /// A production change that fails this test: the command label of a
  /// terminal is not exact.
  @Test func theCodeLabelOfATerminalIsExact() {
    #expect(Self.isExact("swift test", .label(.code)))
  }

  /// A production change that fails this test: the measure is exact only
  /// in the system fonts, but it lays out the fonts of the theme.
  @Test func proseIsExactInAThemeWithAnotherDisplayFont() {
    let measure = EditorLayoutTranscriptTextMeasure(theme: DistinctRolesTheme())

    #expect(measure.isExact(TranscriptTextPart(text: Self.prose, style: .markdown)))
  }

  /// A production change that fails this test: the height of a part and
  /// its exact state come from two different measures.
  @Test func theMeasurementOfAPartIsItsHeightAndItsExactState() {
    let measure = EditorLayoutTranscriptTextMeasure()
    let part = TranscriptTextPart(text: "# Parser\n\n" + Self.prose, style: .markdown)

    #expect(
      measure.measurement(of: part, width: TranscriptRowHeightBed.narrowWidth)
        == TranscriptTextMeasurement(
          height: measure.height(of: part, width: TranscriptRowHeightBed.narrowWidth),
          isExact: measure.isExact(part)))
  }
}
