import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A glass form of the kit, and the files of the kit that can use it
/// (D110 (b), (c)).
///
/// Glass is only on the floating controls and on the action buttons of the
/// request cards and the notices. Content uses no glass, and no glass is on
/// glass.
enum GlassForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// A direct `.glassEffect(` call. Only `agentFloatingGlass()` makes one.
  case glassEffect

  /// The floating glass modifier of the kit, `agentFloatingGlass()`. The
  /// field and the menu of the composer use it.
  case floatingGlass

  /// A `GlassEffectContainer`. Only the shared container of the floating
  /// controls makes one.
  case glassEffectContainer

  /// The shared container of the floating controls, `FloatingGlassContainer`.
  /// The composer and the thread view, which holds the scroll-to-bottom pill
  /// and the composer slot, use it.
  case floatingGlassContainer

  /// The `.glass` or the `.glassProminent` button style. The floating
  /// controls and the action buttons of the request cards and the notices use
  /// it.
  case glassButtonStyle

  var testDescription: String { rawValue }

  /// The pattern that finds the form in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .glassEffect: GlassForm.callPattern("glassEffect")
    case .floatingGlass: GlassForm.callPattern("agentFloatingGlass")
    case .glassEffectContainer: WordPattern.wholeWord("GlassEffectContainer")
    case .floatingGlassContainer: WordPattern.wholeWord("FloatingGlassContainer")
    case .glassButtonStyle:
      GlassForm.buttonStylePattern(
        ChoiceOf {
          WordPattern.wholeWord(GlassForm.prominentStyle)
          WordPattern.wholeWord("glass")
        })
    }
  }

  /// The files that can use the form, relative to the package root.
  var allowedFiles: Set<String> {
    switch self {
    case .glassEffect: [GlassForm.surfacesFile]
    case .floatingGlass: [GlassForm.surfacesFile, ComposerGlassStructureTests.composerFile]
    case .glassEffectContainer: [GlassForm.sharedContainerFile]
    case .floatingGlassContainer:
      [GlassForm.sharedContainerFile, ComposerGlassStructureTests.composerFile, ComposerGlassStructureTests.threadFile]
    case .glassButtonStyle: GlassForm.glassButtonFiles
    }
  }

  /// The file of the surfaces of the kit, which holds `agentFloatingGlass()`.
  static let surfacesFile = KitSourceFiles.kitFile("Theme/AgentSurfaces.swift")

  /// The file of the shared container of the floating controls.
  static let sharedContainerFile = KitSourceFiles.kitFile("Theme/FloatingGlassContainer.swift")

  /// The file of the accessory of the composer, which holds the Send button.
  static let sendButtonFile = KitSourceFiles.kitFile("Input/DefaultPromptAccessory.swift")

  /// The files that can use a glass button style: the floating controls, and
  /// the action buttons of the request cards and the notices.
  static let glassButtonFiles: Set<String> = [
    sendButtonFile,
    KitSourceFiles.kitFile("Input/SuggestionsView.swift"),
    KitSourceFiles.kitFile("Input/SpeechInputButton.swift"),
    KitSourceFiles.kitFile("Thread/ScrollToBottomPill.swift"),
    KitSourceFiles.kitFile("HumanInTheLoop/PermissionView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationURLConsentView.swift"),
    KitSourceFiles.kitFile("Connections/AgentAuthView.swift"),
    KitSourceFiles.kitFile("Status/SessionNoticeBanner.swift"),
    KitSourceFiles.kitFile("Status/StatusBar.swift"),
  ]

  /// The name of the prominent glass button style.
  static let prominentStyle = "glassProminent"

  /// The pattern that finds a call of a function: the name as a whole word,
  /// then `(`.
  ///
  /// - Parameter name: The name of the function.
  /// - Returns: The pattern.
  static func callPattern(_ name: String) -> Regex<Substring> {
    Regex {
      WordPattern.wholeWord(name)
      ZeroOrMore(.whitespace)
      "("
    }
  }

  /// The pattern that finds a call of a function with a member as its
  /// argument, such as `.foregroundStyle(.tint)`: the
  /// ``callPattern(_:)`` of `call`, then the member, from
  /// ``WordPattern/memberPattern(after:_:)``.
  ///
  /// - Parameters:
  ///   - call: The name of the function.
  ///   - member: The pattern of the name of the member.
  /// - Returns: The pattern.
  static func memberCallPattern(_ call: String, _ member: some RegexComponent<Substring>) -> Regex<Substring> {
    WordPattern.memberPattern(after: callPattern(call), member)
  }

  /// The pattern that finds a `buttonStyle` modifier with a style of
  /// `style`, such as `.buttonStyle(.glass)`.
  ///
  /// - Parameter style: The pattern of the name of the style.
  /// - Returns: The pattern, from ``memberCallPattern(_:_:)``.
  static func buttonStylePattern(_ style: some RegexComponent<Substring>) -> Regex<Substring> {
    memberCallPattern("buttonStyle", style)
  }
}

/// Holds the glass of the kit on the floating controls and on the action
/// buttons of the request cards and the notices (D110 (b), (c)).
///
/// The scan reads each Swift file of the kit as text. It blanks the comments
/// and the string literals, then reads the file one line at a time. Each
/// ``GlassForm`` can show only in its allowed files. In the composer
/// directory `Input/`, one `.buttonStyle(.glassProminent)` gives the style to
/// the one prominent action: Send, or Stop while the agent runs.
@Suite struct GlassPlacementTests {
  /// The composer directory, relative to the package root.
  static let inputPath = KitSourceFiles.kitFile("Input")

  /// The pattern that finds the prominent glass button style.
  static var prominentButtonStylePattern: Regex<Substring> {
    GlassForm.buttonStylePattern(WordPattern.wholeWord(GlassForm.prominentStyle))
  }

  /// The pattern that finds the tint as a foreground style, such as
  /// `.foregroundStyle(.tint)`.
  ///
  /// Only the primary action of an area has a tint (D113 answer 5). In the
  /// composer, the primary action is Send, and it gets its tint from the
  /// prominent glass button style. Thus no other control of the composer
  /// uses the tint as a foreground style.
  static var tintForegroundStylePattern: Regex<Substring> {
    GlassForm.memberCallPattern("foregroundStyle", WordPattern.wholeWord("tint"))
  }

  /// The fixture directory of the scan tests.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/GlassPlacement") }
  }

  /// The fixture file that uses each glass form outside its allowed files,
  /// relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/Placement/ContentView.swift"

  /// Each glass form of ``violatingFixtureFile``, and the line that uses it.
  static let violatingFixtureForms: [(form: GlassForm, line: Int)] = [
    (.glassEffect, 9),
    (.floatingGlass, 10),
    (.glassEffectContainer, 11),
    (.floatingGlassContainer, 12),
    (.glassButtonStyle, 13),
  ]

  /// The fixture file with two prominent glass button styles, relative to
  /// ``fixtures``.
  static let prominentFixtureFile = "Violating/Input/TwoProminentActions.swift"

  /// The lines of ``prominentFixtureFile`` that use the prominent style.
  static let prominentFixtureLines = [9, 10]

  /// Each file of each allow list, relative to the package root.
  static let allowedFiles = GlassForm.allCases.reduce(into: Set<String>()) { files, form in
    files.formUnion(form.allowedFiles)
  }

  /// Finds the lines that use a pattern in the code of each Swift file below
  /// a directory. A use in a comment or in a string literal does not count.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  ///   - allowed: The files, relative to `base`, that the scan skips.
  /// - Returns: `<file>:<line>` for each line that uses the pattern, in the
  ///   order of the file paths, then in line order.
  /// - Throws: The error of
  ///   ``SourceLineScanner/codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)``.
  static func uses(
    of pattern: Regex<Substring>, inSwiftFilesBelow directory: URL, relativeTo base: URL,
    allowing allowed: Set<String> = []
  ) throws -> [String] {
    try SourceLineScanner.codeMatches(inSwiftFilesBelow: directory, relativeTo: base, skipping: allowed) { line in
      line.text.contains(pattern) ? ["\(line.file):\(line.number)"] : []
    }
  }

  /// Finds the lines that use a pattern in the code of a fixture directory.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - directory: The fixture directory, relative to ``fixtures``.
  ///   - allowed: The files, relative to ``fixtures``, that the scan skips.
  /// - Returns: `<file>:<line>` for each use, with the file relative to
  ///   ``fixtures``.
  /// - Throws: The error of ``uses(of:inSwiftFilesBelow:relativeTo:allowing:)``.
  static func fixtureUses(
    of pattern: Regex<Substring>, in directory: String, allowing allowed: Set<String> = []
  ) throws -> [String] {
    try uses(of: pattern, inSwiftFilesBelow: fixtures.appending(path: directory), relativeTo: fixtures, allowing: allowed)
  }

  @Test(arguments: GlassForm.allCases)
  func eachGlassFormShowsOnlyInItsAllowedFiles(form: GlassForm) throws {
    let found = try Self.uses(
      of: form.pattern, inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath), relativeTo: PackageFiles.root,
      allowing: form.allowedFiles)

    #expect(found.isEmpty, "\(form) shows outside its allowed files: \(found)")
  }

  @Test func theInputUsesTheProminentGlassButtonStyleOneTimeForTheSendButton() throws {
    let found = try Self.uses(
      of: Self.prominentButtonStylePattern, inSwiftFilesBelow: PackageFiles.file(Self.inputPath),
      relativeTo: PackageFiles.root)

    #expect(found.count == 1, "\(found)")
    #expect(found.allSatisfy { $0.hasPrefix("\(GlassForm.sendButtonFile):") }, "\(found)")
  }

  @Test func noControlOfTheInputUsesTheTintAsAForegroundStyle() throws {
    let found = try Self.uses(
      of: Self.tintForegroundStylePattern, inSwiftFilesBelow: PackageFiles.file(Self.inputPath),
      relativeTo: PackageFiles.root)

    #expect(found.isEmpty, "Use .primary or .secondary. Only Send has a tint: \(found)")
  }

  @Test func memberCallPatternFindsTheMemberInTheArgumentOfTheCall() {
    let pattern = GlassForm.memberCallPattern("foregroundStyle", WordPattern.wholeWord("tint"))

    #expect("symbol.foregroundStyle (.tint)".contains(pattern))
    #expect(!"symbol.myforegroundStyle(.tint)".contains(pattern))
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: GlassForm, line: Int) throws {
    let found = try Self.fixtureUses(of: form.pattern, in: "Violating/Placement")

    #expect(found == ["\(Self.violatingFixtureFile):\(line)"])
  }

  @Test func theScanReportsEachProminentGlassButtonStyleOfTheInputFixture() throws {
    let found = try Self.fixtureUses(of: Self.prominentButtonStylePattern, in: "Violating/Input")

    #expect(found == Self.prominentFixtureLines.map { "\(Self.prominentFixtureFile):\($0)" })
  }

  @Test(arguments: GlassForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: GlassForm) throws {
    let found = try Self.fixtureUses(of: form.pattern, in: "Clean")

    #expect(found.isEmpty, "\(found)")
  }

  @Test func theProminentScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture() throws {
    let found = try Self.fixtureUses(of: Self.prominentButtonStylePattern, in: "Clean")

    #expect(found.isEmpty, "\(found)")
  }

  @Test(arguments: GlassForm.allCases)
  func theScanSkipsAnAllowedFile(form: GlassForm) throws {
    let found = try Self.fixtureUses(of: form.pattern, in: "Violating/Placement", allowing: [Self.violatingFixtureFile])

    #expect(found.isEmpty, "\(found)")
  }

  @Test(arguments: allowedFiles)
  func eachAllowedFileIsInThePackage(path: String) throws {
    let file = try PackageFiles.file(path)

    #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)), "\(path)")
  }
}
