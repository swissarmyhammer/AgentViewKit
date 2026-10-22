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
  /// A direct `.glassEffect(` call. Only the floating glass modifier of the
  /// kit makes one.
  case glassEffect

  /// A `.glassEffectID(` call, which lets a glass morph (D113 answer 2). Only
  /// the glass id modifier of the kit, in the surfaces file, makes one.
  case glassEffectID

  /// The glass id modifier of the kit, `agentGlassID(_:)`. It puts a glass in
  /// the glass namespace of its container (D113 answer 2). The
  /// scroll-to-bottom pill and the suggestion chips use it on their glass
  /// buttons.
  case glassID

  /// The floating glass modifier of the kit, `agentFloatingGlass()` or
  /// `agentFloatingGlass(id:)`. The field and the menu of the composer use it
  /// with a glass id, and the request deck uses it in a bar of floating
  /// controls.
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
    case .glassEffectID: GlassForm.callPattern("glassEffectID")
    case .glassID: GlassForm.callPattern("agentGlassID")
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
    case .glassEffect, .glassEffectID: [GlassForm.surfacesFile]
    case .glassID: [GlassForm.surfacesFile, GlassForm.scrollPillFile, GlassForm.suggestionsFile]
    case .floatingGlass: [GlassForm.surfacesFile, ComposerGlassStructureTests.composerFile, GlassForm.requestDeckFile]
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

  /// The files of the request cards, the notices, the status bars and the
  /// login card. Their action buttons take the button style of
  /// ``requestActionStyleFile``, and have no glass button style of their own.
  /// Only on the glass of the request deck in a bar do the buttons use the
  /// bordered styles (TestudoApp `features/style.md`, "Buttons on glass").
  static let requestCardFiles: Set<String> = [
    KitSourceFiles.kitFile("HumanInTheLoop/PermissionView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationView.swift"),
    KitSourceFiles.kitFile("Elicitation/ElicitationURLConsentView.swift"),
    KitSourceFiles.kitFile("Status/SessionNoticeBanner.swift"),
    KitSourceFiles.statusBarFile,
    KitSourceFiles.kitFile("Connections/AgentAuthView.swift"),
  ]

  /// The files of the views in a bar with no glass surface: the state banner
  /// and the login prompt in the bottom bar of a thread. The content scrolls
  /// under the bar, so each view declares the place of a bar with no glass,
  /// and its buttons keep the glass styles (TestudoApp `features/style.md`,
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

  /// The files that can use a glass button style: the floating controls, and
  /// the button style of the actions of the request cards and the notices.
  static let glassButtonFiles: Set<String> = [
    sendButtonFile,
    suggestionsFile,
    KitSourceFiles.kitFile("Input/SpeechInputButton.swift"),
    scrollPillFile,
    requestActionStyleFile,
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

/// The data of ``GlassPlacementTests`` for the shared form checks.
extension GlassForm: FixtureCodeForm {
  static var fixtures: URL {
    get throws { try GlassPlacementTests.fixtures }
  }

  static var scan: CodeScan { .lines }
}

/// Holds the glass of the kit on the floating controls and on the action
/// buttons of the request cards and the notices (D110 (b), (c)).
///
/// The scan reads each Swift file of the kit as text. It blanks the comments
/// and the string literals, then reads the file one line at a time. Each
/// ``GlassForm`` can show only in its allowed files. In the composer
/// directory `Input/`, one `.buttonStyle(.glassProminent)` gives the style to
/// the one prominent action: Send, or Stop while the agent runs.
///
/// Only that action has a tint (D113 answer 5). ``ThemeInjectionTests``
/// holds the tint and the accent of each other view of the kit, so this suite
/// does not check them again.
@Suite struct GlassPlacementTests {
  /// The composer directory, relative to the package root.
  static let inputPath = KitSourceFiles.kitFile("Input")

  /// The pattern that finds the prominent glass button style.
  static var prominentButtonStylePattern: Regex<Substring> {
    GlassForm.buttonStylePattern(WordPattern.wholeWord(GlassForm.prominentStyle))
  }

  /// The pattern that finds a `.glassEffect` call that names the `.regular`
  /// glass, such as `.glassEffect(.regular, in: shape)`.
  ///
  /// The floating glass is always `.regular` (D113 answer 3). The Clear look
  /// and the Tinted look are system settings, and the system applies them to
  /// `.regular` glass. Thus no theme token selects the glass variant.
  static var regularGlassEffectPattern: Regex<Substring> {
    GlassForm.memberCallPattern("glassEffect", WordPattern.wholeWord("regular"))
  }

  /// The fixture file with a glass of each variant, relative to ``fixtures``.
  static let variantFixtureFile = "Violating/Variant/GlassVariants.swift"

  /// The lines of ``variantFixtureFile`` with a glass that does not name the
  /// `.regular` glass: a `.clear` glass, and a glass with no variant.
  static let variantFixtureLines = [11, 12]

  /// Finds the lines below a directory with a `.glassEffect` call that does
  /// not name the `.regular` glass on the same line. A use in a comment or in
  /// a string literal does not count.
  ///
  /// - Parameters:
  ///   - directory: The directory to scan. The scan includes subdirectories.
  ///   - base: The directory that the file name of each line is relative to.
  /// - Returns: `<file>:<line>` for each line, in the order of the file paths,
  ///   then in line order.
  /// - Throws: The error of
  ///   ``SourceLineScanner/codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)``.
  static func glassEffectsThatAreNotRegular(
    inSwiftFilesBelow directory: URL, relativeTo base: URL
  ) throws -> [String] {
    try SourceLineScanner.codeMatches(inSwiftFilesBelow: directory, relativeTo: base) { line in
      let isNotRegular =
        line.text.contains(GlassForm.glassEffect.pattern) && !line.text.contains(regularGlassEffectPattern)
      return isNotRegular ? ["\(line.file):\(line.number)"] : []
    }
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
    (.glassEffectID, 14),
    (.glassID, 15),
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

  @Test func eachRequestCardTakesTheButtonStylesOfItsActionsFromThePlaceOfTheDeck() throws {
    let found = try Self.uses(
      of: GlassForm.callPattern("requestActionStyle"), inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath),
      relativeTo: PackageFiles.root)
    let files = Set(found.compactMap { $0.split(separator: ":").first.map(String.init) })

    #expect(GlassForm.requestCardFiles.isSubset(of: files), "\(GlassForm.requestCardFiles.subtracting(files))")
  }

  @Test func eachViewInABarWithNoGlassDeclaresThePlaceOfABarWithNoGlassOneTime() throws {
    let found = try CodeScan.lines.uses(
      of: GlassForm.barWithoutGlassPlacePattern, inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath),
      relativeTo: PackageFiles.root)
    let files = found.compactMap { $0.split(separator: ":").first.map(String.init) }

    #expect(files.sorted() == GlassForm.barWithoutGlassFiles.sorted(), "\(found)")
  }

  @Test func theBarWithoutGlassPatternFindsOnlyTheDeclarationOfThatPlace() {
    let pattern = GlassForm.barWithoutGlassPlacePattern

    #expect("StatusBar(message: m).requestActionPlace(.barWithoutGlass)".contains(pattern))
    #expect(!"StatusBar(message: m).requestActionPlace(.bar)".contains(pattern))
    #expect(!"case .barWithoutGlass: content".contains(pattern))
  }

  @Test func theInputUsesTheProminentGlassButtonStyleOneTimeForTheSendButton() throws {
    let found = try Self.uses(
      of: Self.prominentButtonStylePattern, inSwiftFilesBelow: PackageFiles.file(Self.inputPath),
      relativeTo: PackageFiles.root)

    #expect(found.count == 1, "\(found)")
    #expect(found.allSatisfy { $0.hasPrefix("\(GlassForm.sendButtonFile):") }, "\(found)")
  }

  /// The kit makes a glass only with an explicit `.regular` variant, so no
  /// theme value selects the variant of the floating glass (D113 answer 3).
  @Test func eachGlassEffectOfTheKitNamesTheRegularGlass() throws {
    let kit = try PackageFiles.file(KitSourceFiles.kitPath)
    let effects = try Self.uses(of: GlassForm.glassEffect.pattern, inSwiftFilesBelow: kit, relativeTo: PackageFiles.root)
    let found = try Self.glassEffectsThatAreNotRegular(inSwiftFilesBelow: kit, relativeTo: PackageFiles.root)

    #expect(!effects.isEmpty)
    #expect(found.isEmpty, "Use .glassEffect(.regular, in:). A theme does not select the glass variant: \(found)")
  }

  @Test func theVariantScanReportsEachGlassThatIsNotRegularInTheFixture() throws {
    let found = try Self.glassEffectsThatAreNotRegular(
      inSwiftFilesBelow: Self.fixtures.appending(path: "Violating/Variant"), relativeTo: Self.fixtures)

    #expect(found == Self.variantFixtureLines.map { "\(Self.variantFixtureFile):\($0)" })
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
    try form.expectNoUseInTheCleanFixture()
  }

  @Test func theProminentScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture() throws {
    let found = try Self.fixtureUses(of: Self.prominentButtonStylePattern, in: CodeFormFixtures.clean)

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
