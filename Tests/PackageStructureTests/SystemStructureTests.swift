import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A form that puts a custom background or a visual-effect view on the system
/// structure, or that extends a view under the sidebar (D111 steps 2 and 6,
/// TestudoApp `features/style.md` rule 1).
///
/// The system gives the look of the bars, the sidebar and the inspector. A
/// view puts no custom background and no visual-effect view on them.
enum SystemStructureForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// A `.toolbarBackground(` call, which puts a background on a bar.
  case toolbarBackground

  /// A `.toolbarBackgroundVisibility(` call, which shows or hides the
  /// background of a bar.
  case toolbarBackgroundVisibility

  /// A `.containerBackground(` call, which puts a background on a container,
  /// such as the sidebar or the inspector.
  case containerBackground

  /// A `.presentationBackground(` call, which puts a background on a sheet or
  /// a popover.
  case presentationBackground

  /// An AppKit visual-effect view, `NSVisualEffectView`.
  case visualEffectView

  /// The `.ultraThinMaterial` fill style.
  case ultraThinMaterial

  /// The `.thinMaterial` fill style.
  case thinMaterial

  /// The `.regularMaterial` fill style.
  case regularMaterial

  /// The `.thickMaterial` fill style.
  case thickMaterial

  /// The `.ultraThickMaterial` fill style.
  case ultraThickMaterial

  /// The `.bar` material as a fill style, such as `.background(.bar)`,
  /// `.fill(.bar)` or `in: .bar`. A key path such as `\.bar`, a property
  /// `bar` after a name, and a case `.bar` of an enum of the kit are not a
  /// fill style.
  case barMaterial

  /// A `.backgroundExtensionEffect(` call, which extends an image under the
  /// sidebar (D111 step 6).
  case backgroundExtensionEffect

  var testDescription: String { rawValue }

  /// The files that can extend an image under the sidebar, relative to the
  /// package root, each with the reason.
  ///
  /// The list is empty: the kit has no image under the sidebar. A card that
  /// adds an image under the sidebar adds its file here, with the reason. Use
  /// `.backgroundExtensionEffect()` only on an image, never on text.
  static let backgroundExtensionFiles: [String: String] = [:]

  /// The files, relative to the package root, that can use the form, each
  /// with the reason. Only ``backgroundExtensionEffect`` can have an allowed
  /// file.
  var allowedFiles: [String: String] {
    self == .backgroundExtensionEffect ? Self.backgroundExtensionFiles : [:]
  }

  /// The pattern that finds the form in a line of code.
  var pattern: Regex<Substring> {
    switch self {
    case .toolbarBackground, .toolbarBackgroundVisibility, .containerBackground, .presentationBackground,
      .backgroundExtensionEffect:
      GlassForm.callPattern(rawValue)
    case .visualEffectView: WordPattern.wholeWord("NSVisualEffectView")
    case .ultraThinMaterial, .thinMaterial, .regularMaterial, .thickMaterial, .ultraThickMaterial:
      Regex {
        "."
        WordPattern.wholeWord(rawValue)
      }
    case .barMaterial: Self.barFillPattern
    }
  }

  /// The pattern that finds the `.bar` material as the argument of a fill:
  /// `.background(.bar`, `.fill(.bar`, `.backgroundStyle(.bar` or `in: .bar`.
  static var barFillPattern: Regex<Substring> {
    let bar = WordPattern.wholeWord("bar")
    let shapeLabel = Regex {
      WordPattern.wholeWord("in")
      ZeroOrMore(.whitespace)
      ":"
    }
    return Regex {
      ChoiceOf {
        GlassForm.memberCallPattern("background", bar)
        GlassForm.memberCallPattern("fill", bar)
        GlassForm.memberCallPattern("backgroundStyle", bar)
        WordPattern.memberPattern(after: shapeLabel, bar)
      }
    }
  }
}

/// The data of ``SystemStructureTests`` for the shared form checks.
extension SystemStructureForm: SampledCodeForm, FixtureCodeForm {
  static var sampleLines: [(form: SystemStructureForm, line: String)] { SystemStructureTests.sampleForms }

  static var lookAlikeLines: [String] { SystemStructureTests.lookAlikeLines }

  static var fixtures: URL {
    get throws { try SystemStructureTests.fixtures }
  }

  static var scan: CodeScan { .lines }
}

/// Holds the kit on the system structure (D111 steps 2 and 6, D113 answer 7).
///
/// - The kit, the demo support and the demo put no custom background and no
///   visual-effect view on a bar, the sidebar or the inspector (TestudoApp
///   `features/style.md` rule 1), and extend no view under the sidebar. The
///   scan reads the code lines of each Swift file: it blanks the comments and
///   the string literals, then reads the file one line at a time.
/// - The side panel of the kit is the system `.inspector`.
/// - ``AgentThreadView`` has one top bar and one bottom bar
///   (`.safeAreaBar(edge:)`), and its list scrolls under them ("Scroll under
///   the bars"). The content of the two bars has no `.background(` fill
///   (D112 (e)). ``ThreadTopBarStructureTests`` (AVK-8am) and
///   ``ThreadBottomBarStructureTests`` (AVK-8al) hold the place of each header,
///   banner and prompt in its bar, so this suite does not check them again.
@Suite struct SystemStructureTests {
  /// The directories that the scan reads, relative to the package root: the
  /// kit, the demo support and the demo.
  static let scanPaths = [KitSourceFiles.kitPath, "Sources/DemoSupport", "Examples/AgentViewKitDemo"]

  /// The file of the side panel of the kit, which shows an attachment in the
  /// system inspector.
  static let inspectorFile = KitSourceFiles.kitFile("Attachments/AttachmentInspector.swift")

  /// The edges of the two bars of a thread.
  static let threadBarEdges = ["top", "bottom"]

  /// The code text before the content of each bar of a thread: the top bar
  /// block, and the floating controls of the bottom bar.
  static let threadBarStarts = [
    ThreadTopBarStructureTests.topBarStart, ThreadBottomBarStructureTests.floatingControlsStart,
  ]

  /// The fixture file with a fill in each bar, relative to the package root.
  static let filledBarsFixtureFile = "Tests/PackageStructureTests/Fixtures/SystemStructure/Bars/FilledBars.swift"

  /// The number of the fills in each bar of ``filledBarsFixtureFile``.
  static let filledBarsFixtureFillCount = 1

  /// A sample line of each form.
  static let sampleForms: [(form: SystemStructureForm, line: String)] = [
    (.toolbarBackground, ".toolbarBackground(.hidden, for: .windowToolbar)"),
    (.toolbarBackgroundVisibility, ".toolbarBackgroundVisibility(.visible, for: .windowToolbar)"),
    (.containerBackground, ".containerBackground(Color.clear, for: .navigation)"),
    (.presentationBackground, ".presentationBackground(Color.clear)"),
    (.visualEffectView, "let effect = NSVisualEffectView()"),
    (.ultraThinMaterial, ".background(.ultraThinMaterial)"),
    (.thinMaterial, ".background(.thinMaterial)"),
    (.regularMaterial, ".background(.regularMaterial, in: .capsule)"),
    (.thickMaterial, "Rectangle().fill(.thickMaterial)"),
    (.ultraThickMaterial, ".background(.ultraThickMaterial)"),
    (.barMaterial, ".background(.bar)"),
    (.barMaterial, "Rectangle().fill( .bar)"),
    (.barMaterial, ".backgroundStyle(.bar)"),
    (.barMaterial, ".background(Color.clear, in: .bar)"),
    (.backgroundExtensionEffect, "Image(\"hero\").backgroundExtensionEffect()"),
  ]

  /// Lines that look like a form, but put no background on the system
  /// structure.
  static let lookAlikeLines = [
    #"rows.map(\.bar)"#,
    "case (.bar, .primary), (.bar, .secondary), (.bar, .standard): .bordered",
    "self = isInFloatingGlassContainer ? .bar : .content",
    "case .bar: content.floatingGlass()",
    "let height = toolbar.bar",
    ".background(.quaternary, in: .capsule)",
    ".toolbar { Button(\"Run\") {} }",
    ".inspector(isPresented: $isShown) { Text(\"File\") }",
  ]

  /// The fixture directory of the form scan.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/SystemStructure") }
  }

  /// The fixture file that uses each form, relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/CustomBackgrounds.swift"

  /// Each form of ``violatingFixtureFile``, and the line that uses it.
  static let violatingFixtureForms: [(form: SystemStructureForm, line: Int)] = [
    (.toolbarBackground, 11),
    (.toolbarBackgroundVisibility, 12),
    (.containerBackground, 13),
    (.presentationBackground, 14),
    (.visualEffectView, 15),
    (.ultraThinMaterial, 16),
    (.thinMaterial, 17),
    (.regularMaterial, 18),
    (.thickMaterial, 19),
    (.ultraThickMaterial, 20),
    (.barMaterial, 21),
    (.backgroundExtensionEffect, 22),
  ]

  /// The pattern that finds a bar of a view at one edge, such as
  /// `.safeAreaBar(edge: .top)`.
  ///
  /// - Parameter edge: The name of the edge, such as `top`.
  /// - Returns: The pattern, from ``WordPattern/memberPattern(after:_:)``.
  static func safeAreaBarPattern(edge: String) -> Regex<Substring> {
    let receiver = Regex {
      GlassForm.callPattern("safeAreaBar")
      ZeroOrMore(.whitespace)
      "edge:"
    }
    return WordPattern.memberPattern(after: receiver, WordPattern.wholeWord(edge))
  }

  /// The number of the `.background(` calls in the content of a bar of a
  /// file. A call in a comment or in a string literal does not count.
  ///
  /// - Parameters:
  ///   - start: The code text before the opening brace of the bar content.
  ///   - file: The file, relative to the package root.
  /// - Returns: The number of the calls in the block after `start`.
  /// - Throws: An error when the file cannot be read, or an issue when the
  ///   file has no block after `start`.
  static func backgroundCalls(inBarAfter start: String, of file: String) throws -> Int {
    let code = try ThreadBottomBarStructureTests.code(of: file)
    let bar = try #require(ThreadBottomBarStructureTests.block(after: start, in: code))
    return bar.matches(of: GlassForm.callPattern("background")).count
  }

  @Test func eachPatternFindsOnlyItsOwnForm() {
    SystemStructureForm.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    SystemStructureForm.expectNoFormFindsALookAlikeLine()
  }

  @Test(arguments: SystemStructureForm.allCases)
  func noSourcePutsACustomBackgroundOnTheSystemStructure(form: SystemStructureForm) throws {
    let found = try Self.scanPaths.flatMap { path in
      try GlassPlacementTests.uses(
        of: form.pattern, inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
        allowing: Set(form.allowedFiles.keys))
    }

    #expect(found.isEmpty, "The system gives the look of the bars, the sidebar and the inspector. \(form) is in: \(found)")
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: SystemStructureForm, line: Int) throws {
    let found = try SystemStructureForm.fixtureUses(of: form, in: "Violating")

    #expect(found == ["\(Self.violatingFixtureFile):\(line)"])
  }

  @Test(arguments: SystemStructureForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: SystemStructureForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }

  @Test func eachAllowedFileIsInThePackage() throws {
    let allowed = SystemStructureForm.allCases.flatMap { $0.allowedFiles.keys }
    let missing = try allowed.filter { path in
      try !FileManager.default.fileExists(atPath: PackageFiles.file(path).path(percentEncoded: false))
    }

    #expect(missing.isEmpty, "\(missing)")
  }

  @Test func theSidePanelOfTheKitIsTheSystemInspector() throws {
    let inspectors = try ComposerGlassStructureTests.codeLineCount(
      of: GlassForm.callPattern("inspector"), in: Self.inspectorFile)

    #expect(inspectors == 1)
  }

  @Test(arguments: threadBarEdges)
  func theThreadHasOneBarAtTheEdge(edge: String) throws {
    let bars = try ComposerGlassStructureTests.codeLineCount(
      of: Self.safeAreaBarPattern(edge: edge), in: ComposerGlassStructureTests.threadFile)

    #expect(bars == 1)
  }

  @Test(arguments: threadBarStarts)
  func theContentOfEachBarOfTheThreadHasNoBackground(start: String) throws {
    let fills = try Self.backgroundCalls(inBarAfter: start, of: ComposerGlassStructureTests.threadFile)

    #expect(fills == 0, "The content of a bar is content with no fill (D112 (e)): \(start)")
  }

  @Test(arguments: threadBarStarts)
  func theBarScanCountsTheFillInEachBarOfTheFixture(start: String) throws {
    let fills = try Self.backgroundCalls(inBarAfter: start, of: Self.filledBarsFixtureFile)

    #expect(fills == Self.filledBarsFixtureFillCount)
  }
}
