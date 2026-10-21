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
///
/// A second scan finds the system background colors of AppKit (D111 step 1)
/// in the kit, the demo support and the demo (``SystemStructureTests/scanPaths``).
/// ``ContentFillTests`` holds the custom fills behind content.
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
      WordPattern.memberPattern(
        after: ChoiceOf {
          "Color"
          "foregroundStyle("
          "tint("
          "background("
          "fill("
          "stroke("
        },
        namedColor)
      Anchor.wordBoundary
    }
  }

  /// The pattern of the name of a named system color, such as `red`.
  static var namedColor: some RegexComponent<Substring> {
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
  }

  /// The pattern that finds a system background color (D111 step 1): the
  /// names `windowBackgroundColor`, `controlBackgroundColor`,
  /// `textBackgroundColor` and `underPageBackgroundColor` as whole words, or a
  /// color from a platform color, `Color(nsColor:` or `Color(.`.
  ///
  /// A system background is an opaque fill. It does not let the content and
  /// the glass behind it show, and it does not follow the theme.
  static var systemBackgroundPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        WordPattern.wholeWord("windowBackgroundColor")
        WordPattern.wholeWord("controlBackgroundColor")
        WordPattern.wholeWord("textBackgroundColor")
        WordPattern.wholeWord("underPageBackgroundColor")
        platformColorConversionPattern
      }
    }
  }

  /// The pattern that finds a SwiftUI color from a platform color:
  /// `Color(nsColor:` or `Color(.`.
  static var platformColorConversionPattern: Regex<Substring> {
    Regex {
      WordPattern.wholeWord("Color")
      "("
      ZeroOrMore(.whitespace)
      ChoiceOf {
        Regex {
          "nsColor"
          ZeroOrMore(.whitespace)
          ":"
        }
        "."
      }
    }
  }

  /// A sample line of each system background form, with only that form on
  /// the line.
  static let systemBackgroundSamples = [
    "let window = windowBackgroundColor",
    "let control = controlBackgroundColor",
    "let text = textBackgroundColor",
    "let page = underPageBackgroundColor",
    ".background(Color(nsColor: panelColor))",
    ".background(Color( .quaternarySystemFill))",
  ]

  /// Lines that look like a system background form, but use none.
  static let systemBackgroundLookAlikes = [
    "let windowBackgroundColorName = name",
    ".background(editorTheme.background)",
    ".foregroundStyle(Color.primary)",
    ".background(ThemeColor(.accent))",
    ".background(Color(white: Channel.half))",
  ]

  /// Each line of the violating fixtures that uses a system background form,
  /// as `<file>:<line>` relative to ``fixtures``.
  ///
  /// `SystemBackgrounds.swift` uses one form on each line. The `NSColor.`
  /// line of ``violatingFixtureFile`` also makes a color with
  /// `Color(nsColor:`.
  static let systemBackgroundFixtureUses = [
    "Violating/FixedColors.swift:13",
    "Violating/SystemBackgrounds.swift:12",
    "Violating/SystemBackgrounds.swift:13",
    "Violating/SystemBackgrounds.swift:14",
    "Violating/SystemBackgrounds.swift:15",
    "Violating/SystemBackgrounds.swift:16",
    "Violating/SystemBackgrounds.swift:17",
  ]

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
  /// - Throws: The error of
  ///   ``SourceLineScanner/codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)``.
  static func fixedColorUses(
    inSwiftFilesBelow directory: URL, relativeTo base: URL, allowing allowed: Set<String> = allowedFiles
  ) throws -> [String] {
    try SourceLineScanner.codeMatches(
      inSwiftFilesBelow: directory, relativeTo: base, skipping: allowed, match: fixedColorUses(on:))
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

  @Test func theNamedColorPatternDoesNotFindAStyleModifierInsideALongerName() {
    #expect(!"outfill(.red)".contains(Self.namedColorPattern))
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

  @Test(arguments: systemBackgroundSamples)
  func theSystemBackgroundPatternFindsTheForm(line: String) {
    #expect(line.contains(Self.systemBackgroundPattern))
  }

  @Test(arguments: systemBackgroundLookAlikes)
  func theSystemBackgroundPatternDoesNotFindALookAlikeLine(line: String) {
    #expect(!line.contains(Self.systemBackgroundPattern))
  }

  @Test func theSystemBackgroundScanReportsEachFormOfTheViolatingFixture() throws {
    let found = try GlassPlacementTests.uses(
      of: Self.systemBackgroundPattern, inSwiftFilesBelow: Self.fixtures.appending(path: "Violating"),
      relativeTo: Self.fixtures)

    #expect(found == Self.systemBackgroundFixtureUses)
  }

  @Test func theSystemBackgroundScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture() throws {
    let found = try GlassPlacementTests.uses(
      of: Self.systemBackgroundPattern, inSwiftFilesBelow: Self.fixtures.appending(path: "Clean"),
      relativeTo: Self.fixtures)

    #expect(found.isEmpty, "\(found)")
  }

  /// A scan root that moved would give no files, and the scan would pass with
  /// no files. Thus each root must hold Swift files.
  @Test(arguments: SystemStructureTests.scanPaths)
  func eachSystemBackgroundScanRootHoldsSwiftFiles(path: String) throws {
    let files = try PackageFiles.swiftFiles(in: PackageFiles.file(path))

    #expect(!files.isEmpty, "\(path)")
  }

  @Test(arguments: SystemStructureTests.scanPaths)
  func noViewUsesASystemBackground(path: String) throws {
    let found = try GlassPlacementTests.uses(
      of: Self.systemBackgroundPattern, inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
      allowing: Self.allowedFiles)

    #expect(found.isEmpty, "Remove the hard-coded background (D111 step 1): \(found)")
  }
}
