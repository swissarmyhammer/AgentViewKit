import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// A glass form of the kit, and the files of the kit that can use it
/// (D110 (b), (c)).
///
/// Glass is only on the floating controls and on the action buttons of the
/// request cards and the notices. Content uses no glass, and no glass is on
/// glass.
///
/// The floating glass, its glass id and its container come from the EditorKit
/// `EditorStyle` target, so the kit makes no `.glassEffect(`, no
/// `.glassEffectID(` and no `GlassEffectContainer` of its own: EditorKit's
/// `glassPlacement` engine holds that (``StyleRuleEngineTests``). These forms
/// place the floating glass of EditorStyle and the glass button style in the
/// files of the kit.
enum GlassForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The glass id modifier of EditorStyle, `floatingGlassID(_:)`. It puts a
  /// glass in the glass namespace of its container (D113 answer 2). The
  /// scroll-to-bottom pill and the suggestion chips use it on their glass
  /// buttons.
  case glassID

  /// The floating glass modifier of EditorStyle, `floatingGlass()` or
  /// `floatingGlass(id:)`. The field and the menu of the composer use it
  /// with a glass id, the request deck uses it in a bar of floating
  /// controls, and the thread view uses it on the `AgentInfoHeader` in its
  /// top bar, a floating surface (``ThreadTopBarStructureTests``).
  case floatingGlass

  /// The shared container of the floating controls of EditorStyle,
  /// `FloatingGlassContainer`. The composer and the thread view use it. The
  /// thread view has one for the header in its top bar, and one for the
  /// scroll-to-bottom pill and the composer slot in its bottom bar.
  case floatingGlassContainer

  /// The `.glass` button style. The floating controls and the action buttons
  /// of the request cards and the notices use it. EditorKit's
  /// `themeInjection` engine forbids each prominent button style in each
  /// file (``StyleRuleEngineTests``).
  case glassButtonStyle

  var testDescription: String { rawValue }

  /// The pattern that finds the form in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .glassID: GlassForm.callPattern("floatingGlassID")
    case .floatingGlass: GlassForm.callPattern("floatingGlass")
    case .floatingGlassContainer: WordPattern.wholeWord("FloatingGlassContainer")
    case .glassButtonStyle: GlassForm.buttonStylePattern(WordPattern.wholeWord("glass"))
    }
  }

  /// The files that can use the form, relative to the package root.
  var allowedFiles: Set<String> {
    switch self {
    case .glassID: [GlassForm.scrollPillFile, GlassForm.suggestionsFile]
    case .floatingGlass:
      [ComposerGlassStructureTests.composerFile, GlassForm.requestDeckFile, ComposerGlassStructureTests.threadFile]
    case .floatingGlassContainer: [ComposerGlassStructureTests.composerFile, ComposerGlassStructureTests.threadFile]
    case .glassButtonStyle: GlassForm.glassButtonFiles
    }
  }

  /// The file of the request deck. In a bar of floating controls, the deck is
  /// user input, and it is on the floating glass of the kit.
  static let requestDeckFile = KitSourceFiles.kitFile("HumanInTheLoop/RequestDeck.swift")

  /// The file of the accessory of the composer, which holds the Send button.
  static let sendButtonFile = KitSourceFiles.kitFile("Input/DefaultPromptAccessory.swift")

  /// The file of the scroll-to-bottom pill, a glass button that shows and
  /// hides next to the composer.
  static let scrollPillFile = KitSourceFiles.kitFile("Thread/ScrollToBottomPill.swift")

  /// The file of the suggestion chips, glass buttons that hide while the agent
  /// runs.
  static let suggestionsFile = KitSourceFiles.kitFile("Input/SuggestionsView.swift")

  /// The file of the button style of the actions of the request cards and the
  /// notices. It selects the style from the place of the buttons: glass in
  /// content and in a bar with no glass surface, and bordered on the glass of
  /// the deck in a bar.
  static let requestActionStyleFile = KitSourceFiles.kitFile("HumanInTheLoop/RequestActionStyle.swift")

  /// The file of the style of the button of each status bar of the kit
  /// (``KitSourceFiles/statusBarFile``). The status bar of the style library
  /// shows its button through the style of the environment, and the kit sets
  /// this style where it shows a bar, so the button takes the button style of
  /// its place here.
  static let statusBarActionStyleFile = KitSourceFiles.kitFile("Status/AgentStatusBarActionStyle.swift")

  /// The file of the default style of the button of a status bar in the style
  /// library: the `.glass` button style, for a bar of a view kit that sets no
  /// style of its own.
  static let defaultStatusBarActionStyleFile = KitSourceFiles.styleFile("Status/StatusBarActionStyle.swift")

  /// The files of the request cards, the notices, the style of the status bar
  /// buttons and the login card. Their action buttons take the button style
  /// of ``requestActionStyleFile``, and have no glass button style of their
  /// own. Only on the glass of the request deck in a bar do the buttons use
  /// the bordered styles (EditorKit `style.md`, "Buttons on glass").
  static let requestCardFiles: Set<String> = [
    KitSourceFiles.kitFile("HumanInTheLoop/PermissionView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationURLConsentView.swift"),
    KitSourceFiles.kitFile("Status/SessionNoticeBanner.swift"),
    statusBarActionStyleFile,
    KitSourceFiles.kitFile("Connections/AgentAuthView.swift"),
  ]

  /// The files of the views in a bar with no glass surface: the state banner
  /// and the login prompt in the bottom bar of a thread. The content scrolls
  /// under the bar, so each view declares the place of a bar with no glass,
  /// and its buttons keep the glass styles (EditorKit `style.md`,
  /// rule 4). They are in the glass container of the bar, so with no
  /// declaration they would get the bordered styles of the deck glass.
  static let barWithoutGlassFiles: Set<String> = [
    KitSourceFiles.kitFile("Status/StateBanner.swift"),
    KitSourceFiles.kitFile("Connections/AgentLoginPrompt.swift"),
  ]

  /// The pattern that finds the declaration of the place of a bar with no
  /// glass surface, `.requestActionPlace(.barWithoutGlass)`.
  static var barWithoutGlassPlacePattern: Regex<Substring> {
    memberCallPattern("requestActionPlace", WordPattern.wholeWord("barWithoutGlass"))
  }

  /// The files that can use a glass button style: the floating controls, the
  /// button style of the actions of the request cards and the notices, and
  /// the default style of the button of a status bar of the style library.
  static let glassButtonFiles: Set<String> = [
    sendButtonFile,
    suggestionsFile,
    KitSourceFiles.kitFile("Input/SpeechInputButton.swift"),
    scrollPillFile,
    requestActionStyleFile,
    defaultStatusBarActionStyleFile,
  ]

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

/// The data of ``GlassPlacementTests`` for the shared form checks.
extension GlassForm: FixtureCodeForm {
  static var fixtures: URL {
    get throws { try GlassPlacementTests.fixtures }
  }

  static var scan: CodeScan { .lines }
}

/// Holds the floating glass of the kit on the floating controls, and the
/// glass button style on the floating controls and on the action buttons of
/// the request cards and the notices (D110 (b), (c)).
///
/// The scan reads each Swift file of the kit as text. It blanks the comments
/// and the string literals, then reads the file one line at a time. Each
/// ``GlassForm`` can show only in its allowed files.
///
/// EditorKit's engines (``StyleRuleEngineTests``) forbid the custom glass of
/// SwiftUI (`glassPlacement`), and each prominent button style, each tint
/// and each read of the accent outside its allowed files (`themeInjection`),
/// so this suite does not check them again. Send and Stop use the `.glass`
/// style, because the accent is only for the selection and the focus (the
/// user decision of 2026-10-24, card ^k06v4gt).
@Suite struct GlassPlacementTests {
  /// The composer directory, relative to the package root.
  static let inputPath = KitSourceFiles.kitFile("Input")

  /// The fixture directory of the scan tests.
  static var fixtures: URL {
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/GlassPlacement") }
  }

  /// The fixture file that uses each glass form outside its allowed files,
  /// relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/Placement/ContentView.swift"

  /// Each glass form of ``violatingFixtureFile``, and the line that uses it.
  static let violatingFixtureForms: [(form: GlassForm, line: Int)] = [
    (.floatingGlass, 9),
    (.floatingGlassContainer, 10),
    (.glassButtonStyle, 11),
    (.glassID, 12),
  ]

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

  /// Finds the lines that use a pattern in the code of the kit and of its
  /// style library: a rule of the glass of the kit views is a rule of the
  /// style views too.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - allowed: The files, relative to the package root, that the scan
  ///     skips.
  /// - Returns: `<file>:<line>` for each line that uses the pattern, in the
  ///   order of ``KitSourceFiles/libraryPaths``, then of the file paths, then
  ///   in line order.
  /// - Throws: The error of ``uses(of:inSwiftFilesBelow:relativeTo:allowing:)``.
  static func libraryUses(of pattern: Regex<Substring>, allowing allowed: Set<String> = []) throws -> [String] {
    try KitSourceFiles.scanLibraryFiles { directory in
      try uses(of: pattern, inSwiftFilesBelow: directory, relativeTo: PackageFiles().root, allowing: allowed)
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
    let found = try Self.libraryUses(of: form.pattern, allowing: form.allowedFiles)

    #expect(found.isEmpty, "\(form) shows outside its allowed files: \(found)")
  }

  @Test func eachRequestCardTakesTheButtonStylesOfItsActionsFromThePlaceOfTheDeck() throws {
    let found = try Self.libraryUses(of: GlassForm.callPattern("requestActionStyle"))
    let files = Set(found.compactMap { $0.split(separator: ":").first.map(String.init) })

    #expect(GlassForm.requestCardFiles.isSubset(of: files), "\(GlassForm.requestCardFiles.subtracting(files))")
  }

  @Test func eachViewInABarWithNoGlassDeclaresThePlaceOfABarWithNoGlassOneTime() throws {
    let found = try KitSourceFiles.scanLibraryFiles { directory in
      try CodeScan.lines.uses(
        of: GlassForm.barWithoutGlassPlacePattern, inSwiftFilesBelow: directory, relativeTo: PackageFiles().root)
    }
    let files = found.compactMap { $0.split(separator: ":").first.map(String.init) }

    #expect(files.sorted() == GlassForm.barWithoutGlassFiles.sorted(), "\(found)")
  }

  @Test func theBarWithoutGlassPatternFindsOnlyTheDeclarationOfThatPlace() {
    let pattern = GlassForm.barWithoutGlassPlacePattern

    #expect("StatusBar(message: m).requestActionPlace(.barWithoutGlass)".contains(pattern))
    #expect(!"StatusBar(message: m).requestActionPlace(.bar)".contains(pattern))
    #expect(!"case .barWithoutGlass: content".contains(pattern))
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

  @Test(arguments: GlassForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: GlassForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }

  @Test(arguments: GlassForm.allCases)
  func theScanSkipsAnAllowedFile(form: GlassForm) throws {
    let found = try Self.fixtureUses(of: form.pattern, in: "Violating/Placement", allowing: [Self.violatingFixtureFile])

    #expect(found.isEmpty, "\(found)")
  }

  @Test func theFloatingGlassPatternDoesNotFindTheGlassIDModifier() {
    #expect("menu.floatingGlass(id: FloatingGlassID.editorMenu)".contains(GlassForm.floatingGlass.pattern))
    #expect(!"pill.floatingGlassID(FloatingGlassID.scrollPill)".contains(GlassForm.floatingGlass.pattern))
  }

  @Test(arguments: allowedFiles)
  func eachAllowedFileIsInThePackage(path: String) throws {
    let file = try PackageFiles().file(path)

    #expect(FileManager.default.fileExists(atPath: file.path(percentEncoded: false)), "\(path)")
  }
}
