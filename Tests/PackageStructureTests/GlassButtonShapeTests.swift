import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// The calls of one code line that the shape scan of
/// ``GlassButtonShapeTests`` counts.
struct GlassButtonShapeLine {
  /// The file that holds the line, relative to the base of the scan.
  let file: String

  /// The line number. The first line is line 1.
  let number: Int

  /// The number of glass button styles in a modifier chain, such as
  /// `.buttonStyle(.glass)`.
  let chainStyles: Int

  /// The number of glass button styles in a style helper, such as
  /// `self.buttonStyle(.glass)`.
  let helperStyles: Int

  /// The number of capsule or circle border shapes, such as
  /// `.buttonBorderShape(.capsule)`.
  let shapes: Int

  /// Tells if the line holds a glass button style.
  var hasStyle: Bool { chainStyles + helperStyles > 0 }
}

/// Holds a border shape on each glass button of the small floating controls
/// (D113 answer 3).
///
/// A small floating control, such as the scroll-to-bottom pill or a
/// suggestion chip, is a `.capsule`. An icon-only button, such as Send, Stop
/// or dictation, is a `.circle`: a capsule with equal sides.
///
/// The scan reads the code lines of each file of the composer directory
/// `Input/` and of the file of the pill. A line scan cannot follow one
/// modifier chain, so the scan counts: in each file, the number of border
/// shapes is at least the number of glass button styles. A style helper, a
/// function that writes `self.buttonStyle(` with a glass style, counts as one
/// style call, because its callers set the shape.
@Suite struct GlassButtonShapeTests {
  /// The file of the scroll-to-bottom pill, relative to the package root.
  static let pillFile = KitSourceFiles.kitFile("Thread/ScrollToBottomPill.swift")

  /// The fixture directory of the scan tests.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/GlassButtonShape") }
  }

  /// The fixture file with a glass button and no border shape, relative to
  /// ``fixtures``.
  static let violatingFixtureFile = "Violating/ChipWithoutShape.swift"

  /// The line of ``violatingFixtureFile`` that uses the glass button style.
  static let violatingFixtureLine = 9

  /// The pattern that finds a capsule or a circle border shape, such as
  /// `.buttonBorderShape(.capsule)`.
  static var borderShapePattern: Regex<Substring> {
    GlassForm.memberCallPattern(
      "buttonBorderShape",
      ChoiceOf {
        WordPattern.wholeWord("capsule")
        WordPattern.wholeWord("circle")
      })
  }

  /// The pattern that finds a glass button style in a style helper, such as
  /// `self.buttonStyle(.glass)`.
  static var helperStylePattern: Regex<Substring> {
    Regex {
      WordPattern.wholeWord("self")
      "."
      GlassForm.glassButtonStyle.pattern
    }
  }

  /// Counts the calls of one code line.
  ///
  /// - Parameter line: The code line.
  /// - Returns: The counts of the line.
  static func shapeLine(_ line: SourceLine) -> GlassButtonShapeLine {
    let helperStyles = line.text.matches(of: helperStylePattern).count
    return GlassButtonShapeLine(
      file: line.file, number: line.number,
      chainStyles: line.text.matches(of: GlassForm.glassButtonStyle.pattern).count - helperStyles,
      helperStyles: helperStyles, shapes: line.text.matches(of: borderShapePattern).count)
  }

  /// Tells if the glass button styles of one file have too few border
  /// shapes.
  ///
  /// - Parameter lines: The counted lines of one file.
  /// - Returns: `true` when the file has more style calls than border
  ///   shapes. All the lines of the style helpers count as one style call.
  static func lacksShapes(_ lines: [GlassButtonShapeLine]) -> Bool {
    let chainStyles = lines.reduce(0) { $0 + $1.chainStyles }
    let helperCalls = lines.contains { $0.helperStyles > 0 } ? 1 : 0
    return chainStyles + helperCalls > lines.reduce(0) { $0 + $1.shapes }
  }

  /// Finds the glass button styles without a border shape in the code of
  /// each Swift file below a directory. A call in a comment or in a string
  /// literal does not count.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  ///   - isInScope: Tells if the scan checks a file, relative to `base`.
  /// - Returns: `<file>:<line>` for each glass button style of each file with
  ///   too few border shapes, in the order of the file paths, then in line
  ///   order.
  /// - Throws: The error of
  ///   ``SourceLineScanner/codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)``.
  static func unshapedStyles(
    inSwiftFilesBelow directory: URL, relativeTo base: URL,
    isInScope: (String) -> Bool = { _ in true }
  ) throws -> [String] {
    let lines = try SourceLineScanner.codeMatches(inSwiftFilesBelow: directory, relativeTo: base) { line in
      isInScope(line.file) ? [shapeLine(line)] : []
    }
    return Dictionary(grouping: lines, by: \.file)
      .filter { lacksShapes($0.value) }
      .values.flatMap { $0 }
      .filter(\.hasStyle)
      .sorted { ($0.file, $0.number) < ($1.file, $1.number) }
      .map { "\($0.file):\($0.number)" }
  }

  /// Tells if a file is a small floating control: a file below the composer
  /// directory `Input/`, or the file of the pill.
  ///
  /// - Parameter file: The file, relative to the package root.
  /// - Returns: `true` when the scan checks the file.
  static func isSmallFloatingControl(_ file: String) -> Bool {
    file.hasPrefix("\(GlassPlacementTests.inputPath)/") || file == pillFile
  }

  @Test func eachGlassButtonOfTheSmallFloatingControlsHasACapsuleOrACircle() throws {
    let found = try Self.unshapedStyles(
      inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root,
      isInScope: Self.isSmallFloatingControl)

    #expect(found.isEmpty, "A glass button has no capsule or circle border shape: \(found)")
  }

  @Test func theScanReportsTheGlassButtonWithoutAShapeInTheViolatingFixture() throws {
    let found = try Self.unshapedStyles(
      inSwiftFilesBelow: Self.fixtures.appending(path: "Violating"), relativeTo: Self.fixtures)

    #expect(found == ["\(Self.violatingFixtureFile):\(Self.violatingFixtureLine)"])
  }

  @Test func theScanCountsAStyleHelperAsOneStyleCall() throws {
    let found = try Self.unshapedStyles(
      inSwiftFilesBelow: Self.fixtures.appending(path: "Clean"), relativeTo: Self.fixtures)

    #expect(found.isEmpty, "\(found)")
  }
}
