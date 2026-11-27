import AgentViewKitTestSupport
import EditorTheme
import Foundation
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

  /// Tells if the measure of the default theme, with the folder of the
  /// image fixture as its image folder, is exact for a Markdown text.
  ///
  /// - Parameters:
  ///   - markdown: The Markdown text.
  ///   - subfolder: The folder in the fixture folder that the measure takes
  ///     as its image folder, or `nil` for the fixture folder.
  /// - Returns: Whether the measure is exact for the text.
  static func isExactWithTheImageFolder(_ markdown: String, subfolder: String? = nil) throws -> Bool {
    let images = try TranscriptImageFixtures()
    defer { images.folder.remove() }
    var folder = images.folder.url
    if let subfolder {
      folder = images.folder.url(subfolder)
      try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    }
    return EditorLayoutTranscriptTextMeasure(imageFolder: folder)
      .isExact(TranscriptTextPart(text: markdown, style: .markdown))
  }

  /// A production change that fails this test: the measure gives EditorKit
  /// no natural size of an image file of the folder, so an answer with an
  /// image never shows its static form from its first frame.
  @Test func markdownWithAnImageOfTheFolderIsExact() throws {
    #expect(try Self.isExactWithTheImageFolder(TranscriptImageFixtures.markdown))
  }

  /// A production change that fails this test: the measure takes an image
  /// that is not in the folder for exact, but its view shows the failure
  /// state, whose height EditorKit does not measure.
  @Test func markdownWithAMissingImageIsNotExact() throws {
    #expect(try !Self.isExactWithTheImageFolder(TranscriptImageFixtures.missingMarkdown))
  }

  /// A production change that fails this test: the measure reads a file
  /// out of the folder, which the image source of the view never reads.
  @Test func markdownWithAnImageOutOfTheFolderIsNotExact() throws {
    #expect(
      try !Self.isExactWithTheImageFolder(
        TranscriptImageFixtures.outsideMarkdown, subfolder: TranscriptImageFixtures.subfolderName))
  }

  /// A production change that fails this test: the measure follows a
  /// symbolic link in the folder, which the image source of the view never
  /// follows.
  @Test func markdownWithAnImageBehindASymbolicLinkIsNotExact() throws {
    let images = try TranscriptImageFixtures()
    defer { images.folder.remove() }
    try FileManager.default.createSymbolicLink(
      at: images.folder.url(TranscriptImageFixtures.linkName),
      withDestinationURL: images.folder.url(TranscriptImageFixtures.fileName))
    let measure = EditorLayoutTranscriptTextMeasure(imageFolder: images.folder.url)

    #expect(!measure.isExact(TranscriptTextPart(text: TranscriptImageFixtures.linkMarkdown, style: .markdown)))
  }

  /// A production change that fails this test: the measure takes inline
  /// math for not exact, but EditorKit typesets and measures a formula off
  /// the main actor (EditorKit ^tg1hnz7).
  @Test func markdownWithInlineMathIsExact() {
    #expect(Self.isExact("The cost is $n^2$ for each row.", .markdown))
  }

  /// A production change that fails this test: the measure takes block
  /// math for not exact, but EditorKit typesets and measures a block
  /// formula off the main actor (EditorKit ^tg1hnz7).
  @Test func markdownWithBlockMathIsExact() {
    #expect(Self.isExact("The cost:\n\n$$\\frac{n^2}{2}$$\n\nFor each row.", .markdown))
  }

  /// A production change that fails this test: the measure takes code with
  /// a line number gutter for not exact, but EditorKit measures the gutter
  /// and the grammar of a code block (EditorKit ^v8t0pka).
  @Test func codeWithALineNumberGutterIsExact() {
    #expect(Self.isExact("let rows = 2", .code(language: "swift")))
  }

  /// A production change that fails this test: the output of a command is
  /// not exact, so a terminal never shows its static form from its first
  /// frame.
  @Test func outputIsExact() {
    #expect(Self.isExact("Build complete.", .output))
  }

  /// A production change that fails this test: the measure takes a diff
  /// for not exact, but the gutters of a diff have fixed widths and one
  /// column of digits, and EditorKit measures its code.
  @Test func aDiffIsExact() {
    #expect(Self.isExact(TranscriptRowFixtures.patch, .diff))
  }

  /// A production change that fails this test: the measure takes a diff
  /// with a long run of context for not exact, but the EditorKit measure of
  /// a diff (`EditorLayoutMeasure.prepare(diff:style:language:contextLines:gutterGap:)`)
  /// folds that context as the diff view folds it on mount.
  @Test func aDiffWithContextToFoldIsExact() {
    #expect(Self.isExact(TranscriptRowFixtures.foldedPatch, .diff))
  }

  /// A production change that fails this test: the measure takes a text
  /// that EditorKit cannot read as a patch for exact, but the preview of
  /// such a text shows its failure state.
  @Test func aTextThatIsNotAPatchIsNotExact() {
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
