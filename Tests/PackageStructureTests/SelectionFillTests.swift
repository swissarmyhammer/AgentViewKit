import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// A form that draws a selection with a fill of its own, outside the shared
/// selection surface of EditorKit (`.selectionSurface(_:radius:)` and
/// `.selectionSurface(_:cornerRadius:)`, card ^dn1m56r).
///
/// A selected item has one look in the kit: the shared surface puts the
/// accent at a fixed low opacity behind the item, or the inactive grey when
/// the window is not key, and the text stays `.primary`. So no view draws a
/// selection with the system selection style, or with a fill whose style
/// switches on a state, such as `isSelected ? .quaternary : .clear`. That
/// ternary is how each selection fill of the kit was written before the
/// shared surface.
///
/// EditorKit's `themeInjection` engine (``StyleRuleEngineTests``) holds the
/// accent and the tint, which are the other two styles of a selection fill:
/// the tint shape style is in no file, and the theme accent is only in the
/// chip fill of a citation.
enum SelectionFillForm: String, CaseIterable, CustomTestStringConvertible, Sendable {
  /// The system selection shape style: the implicit member `.selection`, or
  /// its type `SelectionShapeStyle`.
  case systemSelectionStyle

  /// A `.background(` or a `.fill(` call whose style is a conditional
  /// expression at the top level of the call, such as
  /// `.background(isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear))`.
  /// The call can continue on the next lines.
  case conditionalFill

  var testDescription: String { rawValue }

  /// The pattern that finds the form in the code of a file.
  var pattern: Regex<Substring> {
    switch self {
    case .systemSelectionStyle: Self.systemSelectionStylePattern
    case .conditionalFill: Self.conditionalFillPattern
    }
  }

  /// The pattern that finds the system selection style.
  ///
  /// The SwiftUICore interface of the macOS SDK declares the style as
  /// `ShapeStyle.selection`, of the type `SelectionShapeStyle`. The implicit
  /// member has no name directly before its dot, so a property such as
  /// `model.selection` does not match. A call such as `.selection(` is not the
  /// style.
  static var systemSelectionStylePattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        Regex {
          WordPattern.dotAfterNoName
          "selection"
          Anchor.wordBoundary
          NegativeLookahead {
            ZeroOrMore(.whitespace)
            "("
          }
        }
        WordPattern.wholeWord("SelectionShapeStyle")
      }
    }
    .wordBoundaryKind(.simple)
  }

  /// The pattern that finds a fill whose style is a conditional expression:
  /// a `.background(` or a `.fill(` call, then the text of its arguments up
  /// to a ` ? ` at the top level of the call.
  ///
  /// The `?` has whitespace on each side, so an optional chain such as
  /// `color?.opacity` and the operator `??` do not match.
  static var conditionalFillPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        GlassForm.callPattern("background")
        GlassForm.callPattern("fill")
      }
      WordPattern.argumentText
      OneOrMore(.whitespace)
      "?"
      OneOrMore(.whitespace)
    }
  }
}

/// The data of ``SelectionFillTests`` for the shared form checks.
extension SelectionFillForm: SampledCodeForm, FixtureCodeForm {
  static var sampleLines: [(form: SelectionFillForm, line: String)] { SelectionFillTests.sampleForms }

  static var lookAlikeLines: [String] { SelectionFillTests.lookAlikeLines }

  static var fixtures: URL {
    get throws { try SelectionFillTests.fixtures }
  }

  static var scan: CodeScan { .text }
}

/// Holds the kit, the demo support and the demo to one look of a selection:
/// the shared selection surface of EditorKit (card ^dn1m56r).
///
/// The scan reads the code of each Swift file: it blanks the comments and the
/// string literals, then reads each file as one text, so a call can continue
/// on the next lines. No ``SelectionFillForm`` has an allowed file.
@Suite struct SelectionFillTests {
  /// A sample line of each form, with only that form on the line.
  static let sampleForms: [(form: SelectionFillForm, line: String)] = [
    (.systemSelectionStyle, ".background(.selection)"),
    (.systemSelectionStyle, "let style = AnyShapeStyle(.selection)"),
    (.systemSelectionStyle, "Rectangle().fill(SelectionShapeStyle())"),
    (.conditionalFill, ".background(isOn ? Color.blue : Color.clear)"),
    (.conditionalFill, "Capsule().fill(isOn ? Color.blue : .clear)"),
    (.conditionalFill, ".background(isOn ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear), in: shape)"),
  ]

  /// Lines that look like a form, but draw no selection fill of their own.
  static let lookAlikeLines = [
    "let caret = model.selection.primary.head",
    "EditorContext(model.state.withSelection(model.selection))",
    ".selectionSurface(isSelected, radius: .small)",
    ".selectionSurface(isSelected, cornerRadius: corners.radius(in: editorStyle))",
    ".foregroundStyle(isSelected ? .primary : .secondary)",
    ".background(fill ?? .clear)",
    ".fill(color?.opacity(0.5) ?? .clear)",
    ".background(Foo(isOn ? a : b))",
    ".accessibilityAddTraits(isSelected ? .isSelected : [])",
  ]

  /// The fixture directory of the form scan.
  static var fixtures: URL {
    get throws { try PackageFiles().file("Tests/PackageStructureTests/Fixtures/SelectionFill") }
  }

  /// The fixture file that uses each form, relative to ``fixtures``.
  static let violatingFixtureFile = "Violating/SelectionFills.swift"

  /// Each form of ``violatingFixtureFile``, and the lines where it starts.
  static let violatingFixtureForms: [(form: SelectionFillForm, lines: [Int])] = [
    (.systemSelectionStyle, [9, 10, 16]),
    (.conditionalFill, [9, 11, 13]),
  ]

  @Test func eachPatternFindsOnlyItsOwnForm() {
    SelectionFillForm.expectEachSampleFindsOnlyItsOwnForm()
  }

  @Test func noPatternFindsALookAlikeLine() {
    SelectionFillForm.expectNoFormFindsALookAlikeLine()
  }

  @Test func theConditionalFillPatternFindsACallOnMoreThanOneLine() {
    let call = """
      .background(
        isSelected ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.clear),
        in: EditorSurface.shape(radius: editorStyle.radii.s))
      """

    #expect(SelectionFillForm.forms(in: call) == [.conditionalFill])
  }

  @Test(arguments: SystemStructureTests.scanPaths, SelectionFillForm.allCases)
  func noSourceDrawsASelectionOutsideTheSharedSurface(path: String, form: SelectionFillForm) throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: form.pattern, inSwiftFilesBelow: PackageFiles().file(path), relativeTo: PackageFiles().root)

    #expect(
      found.isEmpty,
      "A selection draws through .selectionSurface (card ^dn1m56r). \(form) is in: \(found)")
  }

  /// The one file that applies the shared selection surface of EditorKit:
  /// the kit modifier `.selectableSurface`, which pairs the surface with the
  /// hit and focus shape of the same corners.
  static let selectableSurfaceFile = KitSourceFiles.styleFile("Theme/SelectableSurface.swift")

  /// The pattern that finds a call of the shared selection surface of
  /// EditorKit, in either of its forms.
  static var selectionSurfaceCall: Regex<Substring> { GlassForm.callPattern("selectionSurface") }

  @Test(arguments: SystemStructureTests.scanPaths)
  func onlyTheSharedSelectableSurfaceAppliesTheSelectionSurface(path: String) throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: Self.selectionSurfaceCall, inSwiftFilesBelow: PackageFiles().file(path), relativeTo: PackageFiles().root,
      skipping: [Self.selectableSurfaceFile])

    #expect(
      found.isEmpty,
      "A selected item uses .selectableSurface, so its hit and focus shape keep the corners of its surface: \(found)")
  }

  @Test func theSharedSelectableSurfaceAppliesTheSelectionSurface() throws {
    let found = try KitSourceFiles.scanLibraryFiles { directory in
      try SourceLineScanner.codeMatchStarts(
        of: Self.selectionSurfaceCall, inSwiftFilesBelow: directory, relativeTo: PackageFiles().root)
    }

    #expect(
      found.contains { $0.hasPrefix("\(Self.selectableSurfaceFile):") },
      "\(Self.selectableSurfaceFile) applies .selectionSurface: \(found)")
  }

  @Test(arguments: violatingFixtureForms)
  func theScanReportsTheFormInTheViolatingFixture(form: SelectionFillForm, lines: [Int]) throws {
    let found = try SelectionFillForm.fixtureUses(of: form, in: "Violating")

    #expect(found == lines.map { "\(Self.violatingFixtureFile):\($0)" })
  }

  @Test(arguments: SelectionFillForm.allCases)
  func theScanIgnoresTheCommentsAndTheStringLiteralsOfTheCleanFixture(form: SelectionFillForm) throws {
    try form.expectNoUseInTheCleanFixture()
  }
}
