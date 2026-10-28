import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// A form that puts a custom fill behind content: behind a content card, a
/// panel or the header row of a code block, a terminal or command output
/// (D111 step 1, D113 answers 1 and 4, EditorKit `style.md` "How
/// the steps apply").
///
/// Content has no fill. A thin `.separator` stroke marks the edge of a card,
/// and a `.separator` line marks a header row. A group that needs more uses a
/// system container, such as `GroupBox`, never a custom fill.
enum ContentFillForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The content surface modifier `agentContentSurface()`, or its modifier
  /// type `AgentContentSurface`. AVK-8ab removed them (D113 answer 1).
  case agentContentSurface

  /// The status bar color of a theme. A bar has no opaque fill, so a view
  /// does not draw this color (`style.md` "Bar colors of a theme").
  case statusBarBackground

  /// The tab bar color of a theme. A bar has no opaque fill, so a view does
  /// not draw this color (`style.md` "Bar colors of a theme").
  case tabBarBackground

  /// A `.background(` call with a style in a shape:
  /// `.background(<style>, in: <shape>)`. The call can continue on the next
  /// lines.
  case backgroundInShape

  /// A fill of a card shape: ``cardShapes`` then `.fill(`, such as
  /// `RoundedRectangle(cornerRadius: radius).fill(.quaternary)`. The form
  /// includes a filled shape in a background, `.background(<shape>.fill(`.
  case shapeFill

  /// A `.background(` call with a color of the EditorKit theme:
  /// `.background(editorTheme.<color>`.
  case themeColorBackground

  /// A fill of the EditorKit `EditorStyle` target: the fill that a host opts
  /// into, `.inlineFill(_:)`, and the filled surfaces `SurfaceFill` and
  /// `.surfaceBackground(_:radius:)`. A kit view draws no fill by default,
  /// and `.inlineEdge(radius:)` paints a fill only below a host that sets
  /// one, so no kit view sets it.
  case editorStyleFill

  var testDescription: String { rawValue }

  /// The files that can use ``backgroundInShape``, relative to the package
  /// root, each with the reason.
  static let backgroundInShapeFiles = [
    KitSourceFiles.kitFile("Items/ToolCallLocationChips.swift"): "The capsule fill of a tool call badge: a small chip.",
    KitSourceFiles.kitFile("Attachments/AttachmentChip.swift"): "The fill of an attachment chip: a small chip.",
    KitSourceFiles.kitFile("Sessions/PendingRequestCountBadge.swift"):
      "The capsule fill of the pending-request badge: a small chip.",
    KitSourceFiles.kitFile("Code/EditorBlockChrome.swift"):
      "The TerminalPalette background of terminal output: terminal data (AVK-8aa, choice B).",
  ]

  /// The files that can use ``shapeFill``, relative to the package root, each
  /// with the reason.
  static let shapeFillFiles = [
    KitSourceFiles.kitFile("Citations/InlineCitation.swift"): "The fill of a citation chip: a link."
  ]

  /// The files, relative to the package root, that can use the form, each
  /// with the reason.
  ///
  /// The reasons that permit a fill are: a link, a small chip that is not a
  /// card, and terminal data. A selection draws through the shared selection
  /// surface of EditorKit, which ``SelectionFillTests`` holds, so no
  /// selection is in a list (card ^dn1m56r). A current item that is not the
  /// selection and has no focus has no fill (card ^y2mrfxt), so the current
  /// source of `Citations/SourcesView.swift` is not in a list.
  var allowedFiles: [String: String] {
    switch self {
    case .backgroundInShape: Self.backgroundInShapeFiles
    case .shapeFill: Self.shapeFillFiles
    case .agentContentSurface, .statusBarBackground, .tabBarBackground, .themeColorBackground, .editorStyleFill:
      [:]
    }
  }

  /// The pattern that finds the form in the code of a file.
  var pattern: Regex<Substring> {
    switch self {
    case .agentContentSurface:
      Regex {
        ChoiceOf {
          WordPattern.wholeWord(rawValue)
          WordPattern.wholeWord("AgentContentSurface")
        }
      }
    case .statusBarBackground, .tabBarBackground: WordPattern.wholeWord(rawValue)
    case .backgroundInShape: Self.backgroundInShapePattern
    case .shapeFill: Self.shapeFillPattern
    case .themeColorBackground: Self.themeColorBackgroundPattern
    case .editorStyleFill: Self.editorStyleFillPattern
    }
  }

  /// The pattern that finds a fill of EditorStyle: a call of
  /// `inlineFill`, `SurfaceFill` or `surfaceBackground`.
  static var editorStyleFillPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        GlassForm.callPattern("inlineFill")
        GlassForm.callPattern("SurfaceFill")
        GlassForm.callPattern("surfaceBackground")
      }
    }
  }

  /// The pattern that finds a card shape: the surface shape of EditorStyle
  /// (`EditorSurface.shape` or `EditorSurface.fallbackShape`),
  /// `ConcentricRectangle`, `RoundedRectangle`, `Rectangle` or `Capsule`.
  static var cardShapes: Regex<Substring> {
    Regex {
      ChoiceOf {
        WordPattern.memberPattern(
          after: WordPattern.wholeWord("EditorSurface"),
          ChoiceOf {
            WordPattern.wholeWord("shape")
            WordPattern.wholeWord("fallbackShape")
          })
        WordPattern.wholeWord("ConcentricRectangle")
        WordPattern.wholeWord("RoundedRectangle")
        WordPattern.wholeWord("Rectangle")
        WordPattern.wholeWord("Capsule")
      }
    }
  }

  /// The pattern of the text between the parentheses of a call: text with
  /// no parentheses, and pairs of parentheses with up to two levels of
  /// nested pairs. The text can continue on the next lines.
  static var argumentText: Regex<Substring> {
    let other = CharacterClass.anyOf("()").inverted
    let innerPair = Regex {
      "("
      ZeroOrMore(other)
      ")"
    }
    let pair = Regex {
      "("
      ZeroOrMore {
        ChoiceOf {
          other
          innerPair
        }
      }
      ")"
    }
    return Regex {
      ZeroOrMore {
        ChoiceOf {
          other
          pair
        }
      }
    }
  }

  /// The pattern that finds `.background(<style>, in: <shape>)`: a
  /// `.background(` call with an `in:` argument at the top level of the
  /// call.
  static var backgroundInShapePattern: Regex<Substring> {
    Regex {
      GlassForm.callPattern("background")
      argumentText
      WordPattern.wholeWord("in")
      ZeroOrMore(.whitespace)
      ":"
    }
  }

  /// The pattern that finds a fill of a card shape: the shape, its
  /// arguments, then `.fill(`.
  static var shapeFillPattern: Regex<Substring> {
    Regex {
      cardShapes
      ZeroOrMore(.whitespace)
      "("
      argumentText
      ")"
      ZeroOrMore(.whitespace)
      "."
      GlassForm.callPattern("fill")
    }
  }

  /// The pattern that finds `.background(editorTheme.<color>`.
  static var themeColorBackgroundPattern: Regex<Substring> {
    Regex {
      GlassForm.callPattern("background")
      ZeroOrMore(.whitespace)
      WordPattern.wholeWord("editorTheme")
      ZeroOrMore(.whitespace)
      "."
    }
  }
}

/// The data of ``ContentFillTests`` for the shared form checks.
extension ContentFillForm: SampledCodeForm, FixtureCodeForm {
  static var sampleLines: [(form: ContentFillForm, line: String)] { ContentFillTests.sampleForms }

  static var lookAlikeLines: [String] { ContentFillTests.lookAlikeLines }

  static var fixtures: URL {
    get throws { try ContentFillTests.fixtures }
  }

  static var scan: CodeScan { .text }
}

/// Holds the content of the kit, the demo support and the demo free of
/// custom fills (D111 step 1, D113 answers 1 and 4).
///
/// The scan reads the code of each Swift file: it blanks the comments and the
/// string literals, then reads each file as one text, so a call can continue
/// on the next lines. Each ``ContentFillForm`` can show only in its allowed
/// files, and each allowed file has the reason of its fill.
///
/// Other suites hold the other fills, so this suite does not check them
/// again:
/// - ``FixedColorTests`` holds the fixed colors and the system background
///   colors of AppKit, such as `windowBackgroundColor`.
/// - ``SystemStructureTests`` holds the backgrounds and the materials of the
///   bars, the sidebar and the inspector, and the content of the two bars of
///   a thread.
/// - `EditorThemeViewsTests` holds the pixels of the header row of a code
///   block, a terminal and command output: the row has no fill of its own.
@Suite struct ContentFillTests {
  /// A sample line of each form, with only that form on the line.
  static let sampleForms: [(form: ContentFillForm, line: String)] = [
    (.agentContentSurface, "Text(\"card\").agentContentSurface()"),
    (.agentContentSurface, "content.modifier(AgentContentSurface())"),
    (.statusBarBackground, "let fill = theme.statusBarBackground"),
    (.tabBarBackground, "let fill = theme.tabBarBackground"),
    (.backgroundInShape, ".background(.background.secondary, in: ConcentricRectangle(corners: .concentric))"),
    (.backgroundInShape, ".background(isOn ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: shape)"),
    (.backgroundInShape, ".background(.quaternary, in: .capsule)"),
    (.shapeFill, "RoundedRectangle(cornerRadius: radius).fill(.quaternary)"),
    (.shapeFill, ".background(Capsule().fill(.tint))"),
    (.shapeFill, "EditorSurface.shape(radius: editorStyle.radii.m) .fill(.quaternary)"),
    (.shapeFill, "EditorSurface.fallbackShape(radius: editorStyle.radii.m).fill(.quaternary)"),
    (.shapeFill, "ConcentricRectangle(corners: .concentric(minimum: .fixed(radius))).fill(.quaternary)"),
    (.shapeFill, "Rectangle().fill(.background.secondary)"),
    (.themeColorBackground, ".background(editorTheme.selection)"),
    (.editorStyleFill, "Text(\"badge\").inlineFill(.quaternary)"),
    (.editorStyleFill, "SurfaceFill(.tint, radius: editorStyle.radii.s)"),
    (.editorStyleFill, ".surfaceBackground(.regularMaterial, radius: editorStyle.radii.l)"),
  ]

  /// Lines that look like a form, but put no fill behind content.
  static let lookAlikeLines = [
    ".background(.selection)",
    ".background(isSelected ? AnyShapeStyle(.selection) : AnyShapeStyle(.clear))",
    ".background(AgentCommandMount(target: target, scope: nil))",
    ".background(Foo(value, in: shape))",
    ".overlay(Capsule().strokeBorder(.separator))",
    ".clipShape(RoundedRectangle(cornerRadius: radius))",
    ".contentShape(Rectangle())",
    ".glassEffect(.regular, in: .capsule)",
    "context.fill(Path(rect), with: .color(tint))",
    "bounds.fill()",
    "Circle().fill(editorTheme.statusRunning)",
    ".foregroundStyle(editorTheme.accent)",
    ".inlineEdge(radius: editorStyle.radii.m)",
    "@Environment(\\.inlineFill) private var hostFill",
    "let height = theme.statusBarBackgroundHeight",
  ]

  /// The fixture directory of the form scan.
  static var fixtures: URL {
    get throws { try PackageFiles.file("Tests/PackageStructureTests/Fixtures/ContentFill") }
  }

  /// The fixture file that uses each form, relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/ContentCards.swift"

  /// Each form of ``violatingFixtureFile``, and the lines where it starts.
  static let violatingFixtureForms: [(form: ContentFillForm, lines: [Int])] = [
    (.agentContentSurface, [14, 15]),
    (.statusBarBackground, [16]),
    (.tabBarBackground, [17]),
    (.backgroundInShape, [11, 20]),
    (.shapeFill, [12, 13, 24]),
    (.themeColorBackground, [16, 18]),
    (.editorStyleFill, [26, 27, 28]),
  ]

  /// Each form, and each of its allowed files.
  static let allowedFormFiles = ContentFillForm.allCases.flatMap { form in
    form.allowedFiles.keys.sorted().map { (form: form, file: $0) }
  }

  @Test func eachPatternFindsOnlyItsOwnForm() {
    ContentFillForm.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    ContentFillForm.expectNoFormFindsALookAlikeLine()
  }

  @Test func theBackgroundInShapePatternFindsACallOnMoreThanOneLine() {
    let call = """
      .background(
        isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
        in: EditorSurface.shape(radius: editorStyle.radii.s))
      """

    #expect(ContentFillForm.forms(in: call) == [.backgroundInShape])
  }

  @Test(arguments: SystemStructureTests.scanPaths, ContentFillForm.allCases)
  func noSourcePutsACustomFillBehindContent(path: String, form: ContentFillForm) throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: form.pattern, inSwiftFilesBelow: PackageFiles.file(path), relativeTo: PackageFiles.root,
      skipping: Set(form.allowedFiles.keys))

    #expect(found.isEmpty, "Content has no fill (D113 answer 1). Use a .separator stroke. \(form) is in: \(found)")
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: ContentFillForm, lines: [Int]) throws {
    let found = try ContentFillForm.fixtureUses(of: form, in: "Violating")

    #expect(found == lines.map { "\(Self.violatingFixtureFile):\($0)" })
  }

  @Test(arguments: ContentFillForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: ContentFillForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }

  /// An allowed file that no longer has its fill must leave the allow list,
  /// so that the list holds only the fills that it permits.
  @Test(arguments: allowedFormFiles)
  func eachAllowedFileUsesItsForm(form: ContentFillForm, file: String) throws {
    let code = try ThreadBottomBarStructureTests.code(of: file)

    #expect(!SourceLineScanner.matchStartLines(of: form.pattern, in: code).isEmpty, "\(file)")
  }
}
