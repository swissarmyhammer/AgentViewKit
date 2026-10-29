import EditorTestSupport
import Foundation
import Testing

/// Checks that each control in the bars of a thread is an EditorKit jump
/// target (KanbanViewKit D109 (e), "the jump is necessary").
///
/// ``AgentThreadView`` shows its header and its banners in its top bar, and
/// its floating controls in its bottom bar. ``ConversationView`` alone shows
/// its state banner in its own bottom bar. Each `Button`, `Picker` and
/// `Toggle` that those bars show gets its scope through the one kit modifier
/// `agentControlScope(_:corners:)`, in the modifier chain of the control. The
/// composer gives the same scope to its editor slot.
///
/// The bar content is the bar blocks of the two views and the files of the
/// views in those blocks. The scan blanks the comments and the string
/// literals of each file, then reads the modifier chain of each control call
/// (``BarControlScan``).
@Suite struct ThreadBarControlScopeStructureTests {
  /// The name of the kit modifier that gives a bar control its scope.
  static let scopeModifier = "agentControlScope"

  /// The bar blocks of the two views that have bars: the top bar and the
  /// floating controls of ``AgentThreadView``, and the bottom bar of
  /// ``ConversationView``.
  static let barBlocks = [
    BarView(file: ComposerGlassStructureTests.threadFile, view: "top bar", barStart: ThreadTopBarStructureTests.topBarStart),
    BarView(
      file: ComposerGlassStructureTests.threadFile, view: "bottom bar",
      barStart: ThreadBottomBarStructureTests.floatingControlsStart),
    BarView(
      file: KitSourceFiles.kitFile("Thread/ConversationView.swift"), view: "bottom bar",
      barStart: ".safeAreaBar(edge: .bottom)"),
  ]

  /// The files of the bar controls: each file that builds a control that the
  /// bars show, at one place of the file.
  static let controlFiles = [
    KitSourceFiles.kitFile("Connections/AgentAuthView.swift"),
    KitSourceFiles.kitFile("Status/SessionNoticeBanner.swift"),
    GlassForm.scrollPillFile,
    GlassForm.sendButtonFile,
    KitSourceFiles.kitFile("Input/SpeechInputButton.swift"),
    GlassForm.suggestionsFile,
    KitSourceFiles.kitFile("Input/AttachmentChips.swift"),
    KitSourceFiles.kitFile("Config/PermissionModePicker.swift"),
  ]

  /// The files of the views in the bars, with the control files. A file that
  /// builds no control today is here too, so that a control it gets later
  /// needs its scope.
  static let barContentFiles =
    [
      KitSourceFiles.kitFile("Connections/AgentInfoHeader.swift"),
      KitSourceFiles.kitFile("Connections/AgentConnectionBanner.swift"),
      KitSourceFiles.kitFile("Connections/AgentLoginPrompt.swift"),
      KitSourceFiles.kitFile("Status/SessionStreamBanner.swift"),
      KitSourceFiles.kitFile("Status/StateBanner.swift"),
      GlassForm.statusBarActionStyleFile,
      ComposerGlassStructureTests.composerFile,
      ComposerGlassStructureTests.editorFile,
      KitSourceFiles.kitFile("Input/DefaultThreadComposer.swift"),
    ] + controlFiles

  /// The code text of the call of the editor slot in the composer.
  static let editorSlotCall = "editor(context)"

  /// The code text of the button of a status bar in the style of the kit.
  /// The status bar of the style library builds the button with no scope,
  /// and shows it through the style of the environment, so the kit style
  /// (``GlassForm/statusBarActionStyleFile``) gives the button its scope.
  static let statusBarButtonExpression = "configuration.button"

  /// The fixture directory of the scan tests.
  static var fixtures: URL {
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/BarControlScope") }
  }

  /// The fixture file with one control of each type with no scope, and one
  /// button with its scope, relative to ``fixtures``.
  static let fixtureFile = "UnscopedControls.swift"

  /// The lines of ``fixtureFile`` that call a control with no scope: a
  /// button with a labeled trailing closure, a picker and a toggle.
  static let fixtureUnscopedLines = [9, 15, 18]

  /// The calls of `calls` whose chain has no ``scopeModifier``.
  ///
  /// - Parameter calls: The control calls of some code.
  /// - Returns: The calls with no scope.
  static func unscoped(_ calls: [BarControlCall]) -> [BarControlCall] {
    calls.filter { !$0.modifiers.contains(scopeModifier) }
  }

  /// The calls of the control types in a file, with the modifier chain of
  /// each call.
  ///
  /// - Parameter file: The file, relative to the package root.
  /// - Returns: The calls, in source order.
  /// - Throws: An error when the file cannot be read.
  static func controlCalls(in file: String) throws -> [BarControlCall] {
    BarControlScan.controlCalls(in: try ThreadBottomBarStructureTests.code(of: file), file: file)
  }

  @Test(arguments: barContentFiles)
  func eachButtonPickerAndToggleOfAFileInTheBarsHasItsScope(_ file: String) throws {
    let unscoped = Self.unscoped(try Self.controlCalls(in: file))

    #expect(unscoped.isEmpty, "A bar control has no \(Self.scopeModifier): \(unscoped)")
  }

  @Test(arguments: barBlocks)
  func eachButtonPickerAndToggleInABarBlockHasItsScope(_ bar: BarView) throws {
    let code = try ThreadBottomBarStructureTests.code(of: bar.file)
    let block = try #require(ThreadBottomBarStructureTests.block(after: bar.barStart, in: code))

    let unscoped = Self.unscoped(BarControlScan.controlCalls(in: String(block), file: bar.testDescription))

    #expect(unscoped.isEmpty, "A control in \(bar.barStart) has no \(Self.scopeModifier): \(unscoped)")
  }

  /// Each control file builds a control that the scan finds, so the scope
  /// check of the file does not pass with no control to check.
  @Test(arguments: controlFiles)
  func theScanFindsTheControlOfEachControlFile(_ file: String) throws {
    #expect(try !Self.controlCalls(in: file).isEmpty)
  }

  /// Checks that the modifier chain of an expression in a file has
  /// ``scopeModifier``.
  ///
  /// - Parameters:
  ///   - expression: The code text of the expression. The check reads the
  ///     chain of its first occurrence in the file.
  ///   - file: The file, relative to the package root.
  /// - Throws: An error when the file cannot be read, or when the file does
  ///   not hold `expression`.
  static func expectScope(after expression: String, inFile file: String) throws {
    let code = try ThreadBottomBarStructureTests.code(of: file)
    let match = try #require(code.range(of: expression), "\(file) has no \(expression)")

    let modifiers = BarControlScan.modifierNames(
      after: BarControlScan.expressionEnd(from: match.upperBound, in: code), in: code)

    #expect(modifiers.contains(scopeModifier), "\(file): \(expression) has \(modifiers)")
  }

  @Test func theEditorSlotOfTheComposerHasItsScope() throws {
    try Self.expectScope(after: Self.editorSlotCall, inFile: ComposerGlassStructureTests.composerFile)
  }

  /// The status bar of the style library draws its button with no control
  /// of its own: the button comes from the style of the environment, which
  /// the kit sets in each view that shows a bar.
  @Test func theStatusBarBuildsNoControlOutsideItsActionStyle() throws {
    #expect(try Self.controlCalls(in: KitSourceFiles.statusBarFile).isEmpty)
  }

  /// The kit style of the status bar button gives the button its scope, so
  /// the button of each bar of a thread is an EditorKit jump target.
  @Test func theButtonOfTheStatusBarHasItsScopeInTheStyleOfTheKit() throws {
    try Self.expectScope(after: Self.statusBarButtonExpression, inFile: GlassForm.statusBarActionStyleFile)
  }

  /// The code text that sets the kit style of the status bar button.
  static let kitStatusBarStyleCall = "statusBarActionStyle(AgentStatusBarActionStyle())"

  /// Each file of the kit that shows a status bar sets the kit style of its
  /// button, so the button has its scope and the button style of its place.
  @Test func eachKitFileThatShowsAStatusBarSetsTheKitStyleOfItsButton() throws {
    let files = try PackageFiles().swiftFileTexts(
      under: PackageFiles().file(KitSourceFiles.kitPath))
    let codes = try files.map { file in (path: file.path, code: try ThreadBottomBarStructureTests.code(of: file.path)) }
    let barFiles = codes.filter { $0.code.contains(GlassForm.callPattern("StatusBar")) }
    let unstyled = barFiles.filter { !$0.code.contains(Self.kitStatusBarStyleCall) }.map(\.path)

    #expect(!barFiles.isEmpty)
    #expect(unstyled.isEmpty, "Set .\(Self.kitStatusBarStyleCall) on the bar: \(unstyled)")
  }

  @Test func theScanReportsEachUnscopedControlOfTheFixture() throws {
    let text = try String(contentsOf: Self.fixtures.appending(path: Self.fixtureFile), encoding: .utf8)
    let code = String(decoding: SwiftLiteralLexer.blankingCommentsAndLiterals(in: Array(text.utf8)), as: UTF8.self)

    let unscoped = Self.unscoped(BarControlScan.controlCalls(in: code, file: Self.fixtureFile))

    #expect(unscoped.map(\.line) == Self.fixtureUnscopedLines)
  }
}
