import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A form that puts a tint or the theme accent on a view, or that gives the
/// kit a theme of its own (D111 step 7, D112 (d), D113 answers 5 and 6).
///
/// Only the primary action of an area has a tint, and it gets the tint from
/// the prominent glass button style. The Tinted look is a system setting, so
/// no glass gets a tint of its own. In content, the theme accent marks only a
/// link, the selection or the current item. The app injects the theme one
/// time, at the root of each window. A view kit sets no theme, and has no
/// theme or color constant of its own (TestudoApp `features/style.md`
/// "Procedure", "Rules" and "Themes").
enum ThemeInjectionForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// A view modifier that sets the tint: `.tint(`, `.accentColor(`, or a
  /// modifier whose name ends in `Tint`, such as `.listItemTint(`. Nothing
  /// is directly before the dot of the modifier, or a character that is not
  /// part of a name, such as `)` or a line break.
  case tintModifier

  /// A `.tint(` call with no argument label directly after a name, such as
  /// `.regular.tint(accent)` or `glass.tint(`: the tint of a glass,
  /// `Glass.tint(_:)` (D113 answer 6).
  case glassTint

  /// The tint or the accent color of the app as a shape style, such as
  /// `.foregroundStyle(.tint)` or `.fill(.tint)` (D113 answer 5).
  case tintShapeStyle

  /// A read of the theme accent, such as `editorTheme.accent` (D113
  /// answer 5).
  case themeAccent

  /// A call that injects a theme, such as `.editorTheme(.system)` (D112 (d)).
  case themeInjection

  /// A theme value or a theme color constant of EditorKit, such as
  /// `DefaultTheme.dark` (D112 (d)).
  case themeValue

  /// A type that conforms to the EditorKit `Theme` protocol, such as
  /// `struct OwnTheme: Theme`: a theme of the kit's own (D112 (d)).
  case themeType

  var testDescription: String { rawValue }

  /// The directories that the scan of the form reads, relative to the
  /// package root.
  ///
  /// The tint and the accent forms are rules of the look, so the scan reads
  /// the kit, the demo support and the demo (``SystemStructureTests/scanPaths``).
  /// The theme forms are rules of the view kit only: the demo is the app,
  /// and the app injects the theme at the root of each window.
  var scanPaths: [String] {
    switch self {
    case .tintModifier, .glassTint, .tintShapeStyle, .themeAccent: SystemStructureTests.scanPaths
    case .themeInjection, .themeValue, .themeType: [KitSourceFiles.kitPath]
    }
  }

  /// The files that can use the form, relative to the package root, each with
  /// the permitted uses in the file. Each use is the reason for one match of
  /// the form in the file.
  ///
  /// Only ``themeAccent`` has allowed files: the permitted uses of the accent
  /// of AVK-8ak (D113 answer 5). Each other list is empty. The Tinted look is
  /// a system setting, so no glass has a tint (D113 answer 6).
  ///
  /// The list holds files, not lines, so a change to a line does not break
  /// it. The permitted uses hold each file to its number of matches: a new
  /// use of the accent in an allowed file changes the number.
  var allowedFiles: [String: [String]] {
    self == .themeAccent ? Self.accentFiles : [:]
  }

  /// The files that can read the theme accent, relative to the package root,
  /// each with the permitted uses in the file.
  ///
  /// The minimap draws the accent only in the band of the rows in view. Its
  /// ticks, which mark the user and the agent rows, do not use the accent.
  static let accentFiles: [String: [String]] = [
    KitSourceFiles.kitFile("Citations/InlineCitation.swift"): [
      "The text of a citation pill: a link.",
      "The capsule fill of a citation pill: a link.",
    ],
    KitSourceFiles.kitFile("Citations/SourcesView.swift"): ["The highlight of the current source: the current item."],
    KitSourceFiles.kitFile("Elicitation/ElicitationLayout.swift"): ["The fill of the selected tab: the selection."],
    KitSourceFiles.kitFile("Thread/ThreadMinimapView.swift"): [
      "The band of the rows in view: the current item. The ticks do not use the accent."
    ],
  ]

  /// The pattern that finds the form in the code of a file. A match can
  /// continue on the next lines.
  var pattern: Regex<Substring> {
    switch self {
    case .tintModifier: Self.tintModifierPattern
    case .glassTint: Self.glassTintPattern
    case .tintShapeStyle: Self.tintShapeStylePattern
    case .themeAccent: Self.themeAccentPattern
    case .themeInjection: Self.themeInjectionPattern
    case .themeValue: Self.themeValuePattern
    case .themeType: Self.themeTypePattern
    }
  }

  /// The pattern of an open parenthesis whose first argument has no label,
  /// such as `(.blue)`, but not `(for: severity)`.
  ///
  /// Each `tint` call of the SDK has no argument label. The `tint` functions
  /// of the kit have a label: `Theme.tint(for:)` and
  /// `ThreadMinimapView.tint(of:in:)`. Thus the label separates them.
  static var unlabeledArguments: Regex<Substring> {
    Regex {
      "("
      NegativeLookahead {
        ZeroOrMore(.whitespace)
        OneOrMore(.word)
        ZeroOrMore(.whitespace)
        ":"
      }
    }
  }

  /// The pattern of a dot with no name directly before it: the dot of a
  /// modifier or of an implicit member, such as `.tint(` after `)`.
  static var dotAfterNoName: Regex<Substring> {
    Regex {
      Anchor.wordBoundary.inverted
      "."
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds a view modifier that sets the tint.
  ///
  /// The list of names is complete for the SwiftUI and the SwiftUICore
  /// interfaces of the macOS SDK (`xcrun --show-sdk-path`). The view
  /// modifiers that set a tint are `tint(_:)` (two overloads),
  /// `accentColor(_:)`, `listItemTint(_:)`, `listRowSeparatorTint(_:edges:)`
  /// and `listSectionSeparatorTint(_:edges:)`. The suffix `Tint` finds each
  /// name of the last three, and each modifier that a later SDK adds with
  /// this suffix. The first argument of each one has no label.
  static var tintModifierPattern: Regex<Substring> {
    Regex {
      dotAfterNoName
      ChoiceOf {
        "tint"
        "accentColor"
        Regex {
          ZeroOrMore(.word)
          "Tint"
        }
      }
      Anchor.wordBoundary
      ZeroOrMore(.whitespace)
      unlabeledArguments
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds a `.tint(` call with no argument label directly
  /// after a name.
  ///
  /// `Glass.tint(_:)` is the one tint of a glass in the SwiftUICore interface
  /// of the macOS SDK. The pattern does not need the name of the glass, so it
  /// finds a tint after `.regular`, `.clear`, `.identity`, `glass`, `Glass`
  /// and each other name of a glass value. A view in a variable, such as
  /// `content.tint(.red)`, also matches: that call is the tint modifier, so
  /// the report is correct. A tint after `)`, such as
  /// `.regular.interactive().tint(`, is a ``tintModifier``.
  static var glassTintPattern: Regex<Substring> {
    Regex {
      Anchor.wordBoundary
      "."
      WordPattern.wholeWord("tint")
      ZeroOrMore(.whitespace)
      unlabeledArguments
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds the tint or the accent color of the app as a
  /// shape style.
  ///
  /// The SwiftUICore interface of the macOS SDK declares the tint style as
  /// `ShapeStyle.tint`, of the type `TintShapeStyle`, and the accent color
  /// of the app as `Color.accentColor`. The pattern finds the style itself,
  /// not a list of calls that take it. Thus it finds the style in each call
  /// that takes a shape style, such as `.foregroundStyle(`, `.fill(`,
  /// `.stroke(`, `.background(` and `AnyShapeStyle(`. The implicit member
  /// `.tint` or `.accentColor` with `(` after it is a ``tintModifier``.
  static var tintShapeStylePattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        Regex {
          dotAfterNoName
          ChoiceOf {
            "tint"
            "accentColor"
          }
          Anchor.wordBoundary
          NegativeLookahead {
            ZeroOrMore(.whitespace)
            "("
          }
        }
        WordPattern.memberPattern(after: WordPattern.wholeWord("Color"), WordPattern.wholeWord("accentColor"))
        WordPattern.wholeWord("TintShapeStyle")
      }
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds a read of the theme accent: a member `.accent`,
  /// `.tokenTint` or `.selectedTokenTint`, as a whole word.
  ///
  /// The list is complete for the `Theme` protocol of EditorKit
  /// (`EditorTheme/Theme.swift`). It names the accent `accent`, and two
  /// members whose default is the accent: `tokenTint` and
  /// `selectedTokenTint`. The pattern finds the member after each receiver,
  /// such as `editorTheme`, `theme` or a key path `\.accent`.
  /// `statusRunning` also has the accent as its default, but it is a status
  /// role of the theme, not the accent.
  static var themeAccentPattern: Regex<Substring> {
    Regex {
      "."
      ChoiceOf {
        WordPattern.wholeWord("accent")
        WordPattern.wholeWord("tokenTint")
        WordPattern.wholeWord("selectedTokenTint")
      }
    }
  }

  /// The pattern that finds a call that injects a theme.
  ///
  /// The list is complete for the environment value of EditorKit
  /// (`EditorSwiftUI/EditorThemeEnvironment.swift`): the theme is the
  /// environment value `editorTheme`, and `.editorTheme(_:)` sets it with
  /// `environment(\.editorTheme, _)`. Thus the pattern finds each way to
  /// write the value:
  /// - a call `editorTheme(`, such as `.editorTheme(.system)`.
  /// - the key path `\.editorTheme` in `.environment(` or
  ///   `.transformEnvironment(`.
  /// - an assignment `editorTheme =`, such as `values.editorTheme = theme`.
  ///
  /// A read with `@Environment(\.editorTheme)` is not one of these forms.
  static var themeInjectionPattern: Regex<Substring> {
    let environmentKeyPath = Regex {
      ChoiceOf {
        GlassForm.callPattern("environment")
        GlassForm.callPattern("transformEnvironment")
      }
      ZeroOrMore(.whitespace)
      "\\"
      ZeroOrMore(.word)
      "."
      WordPattern.wholeWord("editorTheme")
    }
    let assignment = Regex {
      WordPattern.wholeWord("editorTheme")
      ZeroOrMore(.whitespace)
      "="
      NegativeLookahead { "=" }
    }
    return Regex {
      ChoiceOf {
        GlassForm.callPattern("editorTheme")
        environmentKeyPath
        assignment
      }
    }
  }

  /// The pattern that finds a theme value or a theme color constant of the
  /// `EditorTheme` module of EditorKit: a name of the module as a whole word,
  /// or a call of a theme factory after a dot.
  ///
  /// The list is complete for the public declarations of the module:
  /// - each public type that conforms to `Theme`: `DefaultTheme`,
  ///   `SystemTheme`, `ZedTheme`, `TmTheme` and `VSCodeTheme`.
  /// - the family of Zed themes, `ZedThemeFamily`.
  /// - the default theme of the environment, `defaultEditorTheme`.
  /// - the enums of default colors, `ThemeRoleDefaults` and
  ///   `DiffTintDefaults`.
  /// - the static functions that make a theme from a file:
  ///   `Theme.zed(_:colorScheme:)`, `Theme.tmTheme(_:map:)` and
  ///   `Theme.vscode(_:map:)`.
  ///
  /// The implicit member `.system` (`Theme.system`) is not in the list,
  /// because `.system` is also a font and a member of many other types. The
  /// kit can only inject or keep such a theme, and ``themeInjectionPattern``
  /// finds each injection.
  static var themeValuePattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        Regex {
          Anchor.wordBoundary
          ChoiceOf {
            "DefaultTheme"
            "SystemTheme"
            "ZedThemeFamily"
            "ZedTheme"
            "TmTheme"
            "VSCodeTheme"
            "defaultEditorTheme"
            "ThemeRoleDefaults"
            "DiffTintDefaults"
          }
          Anchor.wordBoundary
        }
        Regex {
          "."
          ChoiceOf {
            "zed"
            "tmTheme"
            "vscode"
          }
          Anchor.wordBoundary
          ZeroOrMore(.whitespace)
          "("
        }
      }
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds a declaration of a type that conforms to
  /// `Theme`: `struct`, `class`, `enum`, `actor`, `protocol` or `extension`,
  /// a name, `:`, then `Theme` as a whole word before the `{` of the body.
  ///
  /// The name can be qualified, such as `EditorTheme.Theme`. An extension of
  /// the protocol itself, `extension EditorTheme.Theme {`, has no `:` after
  /// the name, so it does not match.
  static var themeTypePattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        WordPattern.wholeWord("struct")
        WordPattern.wholeWord("class")
        WordPattern.wholeWord("enum")
        WordPattern.wholeWord("actor")
        WordPattern.wholeWord("protocol")
        WordPattern.wholeWord("extension")
      }
      OneOrMore(.whitespace)
      OneOrMore(.word)
      ZeroOrMore(.whitespace)
      ":"
      ZeroOrMore(CharacterClass.anyOf("{").inverted)
      WordPattern.wholeWord("Theme")
    }
  }
}

/// The data of ``ThemeInjectionTests`` for the shared form checks.
extension ThemeInjectionForm: SampledCodeForm, FixtureCodeForm {
  static var sampleLines: [(form: ThemeInjectionForm, line: String)] { ThemeInjectionTests.sampleForms }

  static var lookAlikeLines: [String] { ThemeInjectionTests.lookAlikeLines }

  static var fixtures: URL {
    get throws { try ThemeInjectionTests.fixtures }
  }

  static var scan: CodeScan { .text }
}

/// Holds the tint, the theme accent and the theme of the kit (D111 step 7,
/// D112 (d), D113 answers 5, 6 and 8).
///
/// The scan reads the code of each Swift file: it blanks the comments and the
/// string literals, then reads each file as one text, so a call can continue
/// on the next lines. Each ``ThemeInjectionForm`` can show only in its
/// allowed files. Only the theme accent has allowed files, each with its
/// permitted uses and the reason of each use.
///
/// D113 answer 8 permits the computed terminal colors: the colors 0 to 15
/// come from `TerminalPalette`, and the xterm formula gives the colors 16 to
/// 255. A standard formula is not a color constant of a kit. Thus
/// `Terminal/ANSIText.swift` stays in the allow list of ``FixedColorTests``.
///
/// Other suites hold the other colors, so this suite does not check them
/// again:
/// - ``FixedColorTests`` holds the fixed colors and the system background
///   colors.
/// - ``ContentFillTests`` holds the custom fills behind content.
/// - ``GlassPlacementTests`` holds the one prominent glass button style of
///   the composer, which gives the tint to the Send button.
@Suite struct ThemeInjectionTests {
  /// A sample line of each form, with only that form on the line.
  static let sampleForms: [(form: ThemeInjectionForm, line: String)] = [
    (.tintModifier, "Text(\"a\").tint(.red)"),
    (.tintModifier, ".tint(isOn ? .blue : .red)"),
    (.tintModifier, ".accentColor(.orange)"),
    (.tintModifier, ".listItemTint(.monochrome)"),
    (.tintModifier, ".listRowSeparatorTint(.red, edges: .all)"),
    (.tintModifier, ".glassEffect(.regular.interactive().tint(.blue))"),
    (.glassTint, ".glassEffect(.regular.tint(accent), in: .capsule)"),
    (.glassTint, "let tinted = glass.tint(color)"),
    (.glassTint, "let tinted = Glass.clear.tint (.red)"),
    (.glassTint, "let tinted: Glass = .identity.tint(color)"),
    (.tintShapeStyle, ".foregroundStyle(.tint)"),
    (.tintShapeStyle, ".foregroundStyle(.primary, .tint)"),
    (.tintShapeStyle, ".fill(.tint.opacity(opacity))"),
    (.tintShapeStyle, ".stroke(.tint, lineWidth: width)"),
    (.tintShapeStyle, ".background(.tint)"),
    (.tintShapeStyle, ".stroke(AnyShapeStyle(.tint))"),
    (.tintShapeStyle, ".background(.accentColor)"),
    (.tintShapeStyle, ".foregroundStyle(Color.accentColor)"),
    (.tintShapeStyle, ".foregroundStyle(TintShapeStyle())"),
    (.themeAccent, ".foregroundStyle(editorTheme.accent)"),
    (.themeAccent, "let color = theme.accent.opacity(opacity)"),
    (.themeAccent, #"let path = \.accent"#),
    (.themeAccent, ".foregroundStyle(editorTheme.tokenTint)"),
    (.themeAccent, ".foregroundStyle(editorTheme.selectedTokenTint)"),
    (.themeInjection, ".editorTheme(.system)"),
    (.themeInjection, #".environment(\.editorTheme, theme)"#),
    (.themeInjection, #".transformEnvironment(\EnvironmentValues.editorTheme) { _ in }"#),
    (.themeInjection, "values.editorTheme = theme"),
    (.themeValue, "let theme = DefaultTheme.dark"),
    (.themeValue, "let theme = SystemTheme()"),
    (.themeValue, "let theme: any Theme = defaultEditorTheme"),
    (.themeValue, "let color = ThemeRoleDefaults.succeeded"),
    (.themeValue, "let band = DiffTintDefaults.bandOpacity"),
    (.themeValue, "let theme = try ZedTheme(url: url)"),
    (.themeValue, "let family: ZedThemeFamily = family"),
    (.themeValue, "let theme = try TmTheme(url: url)"),
    (.themeValue, "let theme = try VSCodeTheme(url: url)"),
    (.themeValue, "let theme: any Theme = try .vscode(url)"),
    (.themeValue, "let theme: any Theme = try .zed(url)"),
    (.themeValue, "let theme: any Theme = try .tmTheme(url)"),
    (.themeType, "struct OwnTheme: Theme {"),
    (.themeType, "struct OwnTheme: Sendable, EditorTheme.Theme {"),
    (.themeType, "extension OwnTheme: Theme {"),
    (.themeType, "protocol KitTheme: Theme {"),
  ]

  /// Lines that look like a form, but use none.
  static let lookAlikeLines = [
    "color: editorTheme.tint(for: severity)",
    "color: theme.tint(for: entry.priority)",
    ".tint(for: severity)",
    "Tick(tint: Self.tint(of: entry, in: editorTheme), mark: mark)",
    "context.fill(path, with: .color(tick.tint))",
    "StatusSymbolImage(name: name, color: appearance.tint)",
    #"@Environment(\.editorTheme) private var editorTheme"#,
    "let same = editorTheme == other",
    ".foregroundStyle(editorTheme.statusRunning)",
    "let palette = editorTheme.terminalPalette",
    ".buttonStyle(.glassProminent)",
    ".glassEffect(.regular, in: .capsule)",
    ".foregroundStyle(.tertiary)",
    "let accentOpacity = Self.accentOpacity",
    ".font(.system(size: size))",
    "let tinted = isTinted",
    "nonisolated extension EditorTheme.Theme {",
    "struct ThemePicker: View {",
    "init(theme: any Theme) {",
  ]

  /// The fixture directory of the form scan.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ThemeInjection") }
  }

  /// The fixture file that uses each form, relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/TintAndTheme.swift"

  /// Each form of ``violatingFixtureFile``, and the lines where it starts.
  static let violatingFixtureForms: [(form: ThemeInjectionForm, lines: [Int])] = [
    (.tintModifier, [13, 19]),
    (.glassTint, [14]),
    (.tintShapeStyle, [15]),
    (.themeAccent, [16]),
    (.themeInjection, [17]),
    (.themeValue, [25]),
    (.themeType, [28]),
  ]

  /// Each allowed file of each form, with its number of permitted uses.
  static let allowedFormFiles = ThemeInjectionForm.allCases.flatMap { form in
    form.allowedFiles.sorted { $0.key < $1.key }.map { (form: form, file: $0.key, uses: $0.value.count) }
  }

  @Test func eachPatternFindsOnlyItsOwnForm() {
    ThemeInjectionForm.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    ThemeInjectionForm.expectNoFormFindsALookAlikeLine()
  }

  @Test func theTintModifierPatternFindsAModifierOnTheNextLine() {
    let call = """
      Text("a")
        .tint(
          .blue)
      """

    #expect(ThemeInjectionForm.forms(in: call) == [.tintModifier])
  }

  @Test func theTintPatternsDoNotFindALabelOnTheNextLine() {
    let call = """
      editorTheme.tint(
        for: severity)
      """

    #expect(ThemeInjectionForm.forms(in: call).isEmpty)
  }

  @Test(arguments: ThemeInjectionForm.allCases)
  func noSourceUsesTheFormOutsideItsAllowedFiles(form: ThemeInjectionForm) throws {
    let found = try form.scanPaths.flatMap { path in
      try SourceLineScanner.codeMatchStarts(
        of: form.pattern, inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
        skipping: Set(form.allowedFiles.keys))
    }

    #expect(
      found.isEmpty,
      """
      Only the primary action has a tint, the accent marks only a link, the selection or the current item, \
      and the kit sets no theme (D111 step 7, D112 (d), D113 answers 5 and 6). \(form) is in: \(found)
      """)
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: ThemeInjectionForm, lines: [Int]) throws {
    let found = try ThemeInjectionForm.fixtureUses(of: form, in: "Violating")

    #expect(found == lines.map { "\(Self.violatingFixtureFile):\($0)" })
  }

  @Test(arguments: ThemeInjectionForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: ThemeInjectionForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }

  /// Each allowed file has its permitted uses and no more. A use that leaves
  /// the file, or a new use in the file, changes the number.
  @Test(arguments: allowedFormFiles)
  func eachAllowedFileHasItsNumberOfUses(form: ThemeInjectionForm, file: String, uses: Int) throws {
    let code = try ThreadBottomBarStructureTests.code(of: file)

    #expect(SourceLineScanner.matchStartLines(of: form.pattern, in: code).count == uses, "\(file)")
  }
}
