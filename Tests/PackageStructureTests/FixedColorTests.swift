import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the views of the kit and of the examples free of fixed system
/// colors.
///
/// The colors come from the EditorKit theme, such as the status roles of
/// `Theme+StatusRoles.swift`. A fixed system color, such as `.red`, does not
/// follow the theme. The scan reads each Swift file as text, one line at a
/// time.
@Suite struct FixedColorTests {
  /// The directories of the Swift files that the scan reads: the kit, its
  /// support targets and the examples.
  static let scannedPaths = ["Sources", "Examples"]

  /// The pattern that finds a fixed system color: a named color after
  /// `Color`, or as the argument of a style modifier.
  static var fixedColorPattern: some RegexComponent {
    Regex {
      ChoiceOf {
        "Color"
        "foregroundStyle("
        "foregroundColor("
        "tint("
        "background("
        "fill("
        "stroke("
      }
      ZeroOrMore(.whitespace)
      "."
      ChoiceOf {
        "red"
        "orange"
        "yellow"
        "green"
        "mint"
        "teal"
        "cyan"
        "blue"
        "indigo"
        "purple"
        "pink"
        "brown"
        "gray"
        "black"
        "white"
      }
      Anchor.wordBoundary
    }
  }

  /// Finds the lines of a source that use a fixed system color.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line uses a fixed system color, or no
  ///   result.
  static func fixedColorUses(on line: SourceLine) -> [String] {
    line.text.contains(fixedColorPattern) ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsANamedColorAfterColorAndInAStyleModifier() {
    let source = """
      .foregroundStyle(.red)
      .tint(Color.blue)
      .foregroundStyle(editorTheme.severityError)
      .background(.quaternary)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fixedColorUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2"])
  }

  @Test func noViewUsesAFixedSystemColor() throws {
    let found = try Self.scannedPaths.flatMap { path in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
        match: Self.fixedColorUses(on:))
    }

    #expect(found.isEmpty, "Use a color of the EditorKit theme: \(found)")
  }
}
