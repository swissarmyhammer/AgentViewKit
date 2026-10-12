import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the views of the kit and of the examples free of fixed code fonts.
///
/// The code font is the `editorFont` role of the EditorKit theme. A fixed
/// monospaced font, such as `.body.monospaced()`, does not follow the theme.
/// The digit form `.monospacedDigit()` keeps the current font, so the scan
/// does not find it. The scan reads each Swift file as text, one line at a
/// time.
@Suite struct FixedCodeFontTests {
  /// The pattern that finds a fixed code font: the monospaced design, the
  /// monospaced modifier, or a fixed-pitch system font of AppKit.
  static var fixedCodeFontPattern: some RegexComponent {
    Regex {
      "."
      ChoiceOf {
        "monospaced"
        "monospacedSystemFont"
        "userFixedPitchFont"
      }
      Anchor.wordBoundary
    }
  }

  /// Finds the lines of a source that use a fixed code font.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line uses a fixed code font, or no
  ///   result.
  static func fixedCodeFontUses(on line: SourceLine) -> [String] {
    line.text.contains(fixedCodeFontPattern) ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsTheMonospacedModifierTheDesignAndTheFixedPitchFont() {
    let source = """
      .font(.body.monospaced())
      .font(.system(size: size, design: .monospaced))
      NSFont.monospacedSystemFont(ofSize: size, weight: .regular)
      .monospacedDigit()
      .font(editorTheme.editorFont)
      """

    let found = SourceLineScanner.matches(
      inSource: source, file: "A.swift", match: Self.fixedCodeFontUses(on:))

    #expect(found == ["A.swift:1", "A.swift:2", "A.swift:3"])
  }

  @Test func noViewUsesAFixedCodeFont() throws {
    let found = try KitSourceFiles.scanViewFiles { directory in
      try SourceLineScanner.matches(
        inSwiftFilesBelow: directory, relativeTo: PackageFiles.root, match: Self.fixedCodeFontUses(on:))
    }

    #expect(found.isEmpty, "Use the editorFont role of the EditorKit theme: \(found)")
  }
}
