import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Holds the views of the kit and of the examples free of fixed colors.
///
/// The colors come from the EditorKit theme (`\.editorTheme`), such as the
/// status roles of `Theme+StatusRoles.swift`. Text on glass uses the vibrant
/// foreground styles `.primary`, `.secondary` and `.tertiary`. A fixed color,
/// such as `.red`, `Color(red:green:blue:)` or an `NSColor`, does not follow
/// the theme. The scan reads each Swift file as text. It blanks the comments
/// and the string literals, then reads the file one line at a time.
@Suite struct FixedColorTests {
  /// The pattern that finds a fixed color: a named color, a color from fixed
  /// values, a platform color, or the `foregroundColor` modifier.
  static var fixedColorPattern: some RegexComponent {
    ChoiceOf {
      namedColorPattern
      fixedValueColorPattern
      platformColorPattern
      foregroundColorPattern
    }
  }

  /// The pattern that finds a color from fixed values: `Color(red:`,
  /// `Color(white:` or `Color(hue:`.
  static var fixedValueColorPattern: some RegexComponent {
    Regex {
      WordPattern.wholeWord("Color")
      "("
      ZeroOrMore(.whitespace)
      ChoiceOf {
        "red"
        "white"
        "hue"
      }
      ZeroOrMore(.whitespace)
      ":"
    }
  }

  /// The pattern that finds a platform color: `NSColor.` or `UIColor.`.
  static var platformColorPattern: some RegexComponent {
    Regex {
      ChoiceOf {
        WordPattern.wholeWord("NSColor")
        WordPattern.wholeWord("UIColor")
      }
      "."
    }
  }

  /// The pattern that finds the `foregroundColor` modifier. It sets a color
  /// and not a style, so it cannot take a vibrant foreground style.
  static var foregroundColorPattern: some RegexComponent {
    Regex {
      WordPattern.wholeWord("foregroundColor")
      "("
    }
  }

  /// The pattern that finds a named system color: a named color after
  /// `Color`, or as the argument of a style modifier.
  static var namedColorPattern: some RegexComponent {
    Regex {
      ChoiceOf {
        "Color"
        "foregroundStyle("
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

  /// Finds the lines of a source that use a fixed color.
  ///
  /// - Parameter line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line uses a fixed color, or no
  ///   result.
  static func fixedColorUses(on line: SourceLine) -> [String] {
    line.text.contains(fixedColorPattern) ? ["\(line.file):\(line.number)"] : []
  }

  /// The files that can make a color from fixed values, relative to the
  /// package root.
  ///
  /// The computed 256-color table of `ANSIText.swift` is terminal data, not a
  /// theme color.
  static let allowedFiles: Set<String> = [KitSourceFiles.kitFile("Terminal/ANSIText.swift")]

  /// The fixture directory of the scan tests.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ThemeColors") }
  }

  /// The fixture file that uses each fixed color form, relative to
  /// ``fixtures``.
  static let violatingFixtureFile = "Violating/FixedColors.swift"

  /// Each fixed color form of ``violatingFixtureFile``, and the line that
  /// uses it.
  static let violatingFixtureForms: [(form: String, line: Int)] = [
    ("Color.<named color>", 9),
    ("Color(red:", 10),
    ("Color(white:", 11),
    ("Color(hue:", 12),
    ("NSColor.", 13),
    ("UIColor.", 14),
    (".foregroundColor(", 15),
    (".foregroundStyle(.<named color>)", 16),
  ]

  /// Finds the lines that use a fixed color in each Swift file below a
  /// directory. A fixed color in a comment or in a string literal does not
  /// count.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  ///   - allowed: The files, relative to `base`, that the scan skips.
  /// - Returns: `<file>:<line>` for each line that uses a fixed color, in the
  ///   order of the file paths, then in line order.
  /// - Throws: The error of `PackageFiles.swiftFileTexts(below:relativeTo:)`.
  static func fixedColorUses(
    inSwiftFilesBelow directory: URL, relativeTo base: URL, allowing allowed: Set<String> = allowedFiles
  ) throws -> [String] {
    try PackageFiles.swiftFileTexts(below: directory, relativeTo: base)
      .filter { !allowed.contains($0.path) }
      .flatMap { file in
        let code = SwiftLiteralLexer.blankingCommentsAndLiterals(in: Array(file.text.utf8))
        return SourceLineScanner.matches(
          inSource: String(decoding: code, as: UTF8.self), file: file.path, match: fixedColorUses(on:))
      }
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

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: String, line: Int) throws {
    let found = try Self.fixedColorUses(inSwiftFilesBelow: Self.fixtures.appending(path: "Violating"), relativeTo: Self.fixtures)

    #expect(found.contains("\(Self.violatingFixtureFile):\(line)"), "The scan did not find \(form): \(found)")
  }

  @Test func theScanReportsOnlyTheFixedColorLinesOfTheViolatingFixture() throws {
    let found = try Self.fixedColorUses(inSwiftFilesBelow: Self.fixtures.appending(path: "Violating"), relativeTo: Self.fixtures)

    #expect(found == Self.violatingFixtureForms.map { "\(Self.violatingFixtureFile):\($0.line)" })
  }

  @Test func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture() throws {
    let found = try Self.fixedColorUses(inSwiftFilesBelow: Self.fixtures.appending(path: "Clean"), relativeTo: Self.fixtures)

    #expect(found.isEmpty, "\(found)")
  }

  @Test func theScanSkipsAnAllowedFile() throws {
    let found = try Self.fixedColorUses(
      inSwiftFilesBelow: Self.fixtures.appending(path: "Violating"), relativeTo: Self.fixtures,
      allowing: [Self.violatingFixtureFile])

    #expect(found.isEmpty, "\(found)")
  }

  @Test(arguments: allowedFiles)
  func eachAllowedFileIsInThePackage(path: String) throws {
    let file = try PackageFiles.file(path)

    #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)), "\(path)")
  }

  @Test func noViewUsesAFixedColor() throws {
    let found = try KitSourceFiles.scanViewFiles { directory in
      try Self.fixedColorUses(inSwiftFilesBelow: directory, relativeTo: PackageFiles.root)
    }

    #expect(found.isEmpty, "Use a color of the EditorKit theme: \(found)")
  }
}
