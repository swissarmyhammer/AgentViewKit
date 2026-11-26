import AgentViewKitTestSupport
import EditorTheme
import Testing

@testable import AgentViewKit

/// The parts for which the interim text measure gives the height of the
/// mounted view (card ^9ync5h3).
///
/// A static row takes the height of the cache only when each text part of
/// the row is exact. An exact part has a measure height within 0.5 pt of
/// the mounted EditorKit view at each test width.
@Suite struct InterimTranscriptTextMeasureTests {
  /// Plain prose with no Markdown markup.
  static let prose = "The parser reads each line of the file.\n\nIt stops at the first error."

  /// A part of the default measure.
  ///
  /// - Parameters:
  ///   - text: The text.
  ///   - style: The style of the part.
  /// - Returns: Whether the default measure is exact for the part.
  static func isExact(_ text: String, _ style: TranscriptTextPart.Style) -> Bool {
    InterimTranscriptTextMeasure().isExact(TranscriptTextPart(text: text, style: style))
  }

  /// A production change that fails this test: plain prose is not exact,
  /// so an agent answer never shows its static form from its first frame.
  @Test func plainProseIsExact() {
    #expect(Self.isExact(Self.prose, .markdown))
  }

  /// A production change that fails this test: the label of a plan step is
  /// not exact, so a plan never shows its static form from its first frame.
  @Test func theInheritedLabelOfAPlanStepIsExact() {
    #expect(Self.isExact("Fix the lexer", .label(.inherited)))
  }

  /// A production change that fails this test: the measure takes code for
  /// exact, and a code block row jumps when it changes form.
  @Test func codeIsNotExact() {
    #expect(!Self.isExact("let rows = 2", .code(language: "swift")))
  }

  /// A production change that fails this test: the measure takes the output
  /// of a command for exact.
  @Test func outputIsNotExact() {
    #expect(!Self.isExact("Build complete.", .output))
  }

  /// A production change that fails this test: the measure takes a diff
  /// for exact.
  @Test func aDiffIsNotExact() {
    #expect(!Self.isExact("+let name = \"new\"", .diff))
  }

  /// A production change that fails this test: the measure takes the
  /// explanation label of a notice for exact.
  @Test func theCalloutLabelOfANoticeIsNotExact() {
    #expect(!Self.isExact(Self.prose, .label(.ui(.callout))))
  }

  /// A production change that fails this test: Markdown with a heading
  /// marker is exact, but the measure lays out the marker at the body font.
  @Test func markdownWithAHeadingIsNotExact() {
    #expect(!Self.isExact("# Parser\n\n" + Self.prose, .markdown))
  }

  /// A production change that fails this test: Markdown with inline code is
  /// exact, but the measure lays out the code at the body font.
  @Test func markdownWithInlineCodeIsNotExact() {
    #expect(!Self.isExact("Read `parser.swift` first.", .markdown))
  }

  /// A production change that fails this test: Markdown with a list item is
  /// exact, but the measure lays out no list indent.
  @Test func markdownWithAListItemIsNotExact() {
    #expect(!Self.isExact("- Fix the lexer", .markdown))
  }

  /// A production change that fails this test: the measure is exact for a
  /// theme whose display font is not the system font, which the measure
  /// does not lay out.
  @Test func proseIsNotExactInAThemeWithAnotherDisplayFont() {
    let measure = InterimTranscriptTextMeasure(theme: DistinctRolesTheme())

    #expect(!measure.isExact(TranscriptTextPart(text: Self.prose, style: .markdown)))
  }

  /// A production change that fails this test: the measure is not exact for
  /// the system theme, whose fonts are the system fonts of the measure.
  @Test func proseIsExactInTheSystemTheme() {
    let measure = InterimTranscriptTextMeasure(theme: SystemTheme())

    #expect(measure.isExact(TranscriptTextPart(text: Self.prose, style: .markdown)))
  }
}
