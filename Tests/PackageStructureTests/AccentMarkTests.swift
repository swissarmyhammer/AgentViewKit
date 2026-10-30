import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// Forbids the old accent marks of a link and of a current item (card
/// ^y2mrfxt).
///
/// The accent is only for the selection and the focus (the user decision of
/// 2026-10-24, shared style rule 2). Before card ^y2mrfxt, a link took the
/// theme accent as its text color: the digits of a citation pill had
/// `.foregroundStyle(editorTheme.accent)`. A current item took the accent as a
/// fill: the current source of the sources list and the band of the rows in
/// view on the minimap. A current item that is not the selection and has no
/// focus now has no accent and no fill.
///
/// EditorKit's `themeInjection` and `contentFills` engines
/// (``StyleRuleEngineTests``) hold the files that can read the accent at all
/// and the files that can fill behind content. This suite names the two old
/// forms, so that neither one comes back in a file that a later card adds to
/// those allow lists.
@Suite struct AccentMarkTests {
  /// The files that show a current item, relative to the package root: the
  /// current source of the sources list and the rows in view on the minimap.
  /// Neither one is the selection, and neither one has the focus.
  static let currentItemFiles = [
    KitSourceFiles.kitFile("Citations/SourcesView.swift"),
    KitSourceFiles.kitFile("Thread/ThreadMinimapView.swift"),
  ]

  /// The pattern that finds a read of the theme accent: a member `.accent`,
  /// `.tokenTint`, `.selectedTokenTint` or `.themeAccent`, as a whole word.
  ///
  /// The list is complete for the `Theme` protocol of EditorKit
  /// (`EditorTheme/Theme.swift`) and for the environment value of the theme
  /// accent (`EditorStyle/ThemeAccent.swift`). The protocol names the accent
  /// `accent`, and two members whose default is the accent: `tokenTint` and
  /// `selectedTokenTint`. The pattern finds the member after each receiver,
  /// such as `editorTheme`, `theme` or a key path `\.accent`.
  static var themeAccentPattern: Regex<Substring> {
    Regex {
      "."
      ChoiceOf {
        WordPattern.wholeWord("accent")
        WordPattern.wholeWord("tokenTint")
        WordPattern.wholeWord("selectedTokenTint")
        WordPattern.wholeWord("themeAccent")
      }
    }
  }

  /// The pattern of the theme accent as a text color: a `foregroundStyle(` or
  /// `foregroundColor(` call that reads the theme accent before its first `)`.
  /// The call can continue on the next lines.
  static var accentTextPattern: Regex<Substring> {
    Regex {
      ChoiceOf {
        GlassForm.callPattern("foregroundStyle")
        GlassForm.callPattern("foregroundColor")
      }
      ZeroOrMore(CharacterClass.anyOf(")").inverted)
      themeAccentPattern
    }
  }

  /// Lines with the theme accent as a text color: the old form of a link.
  static let accentTextLines = [
    ".foregroundStyle(editorTheme.accent)",
    ".foregroundStyle(isCurrent ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.secondary))",
    ".foregroundColor(editorTheme.tokenTint)",
  ]

  /// Lines that read the accent, but not as a text color, or that set a text
  /// color with no accent.
  static let notAccentTextLines = [
    ".background(Capsule().fill(editorTheme.accent.opacity(Self.fillOpacity)))",
    ".foregroundStyle(.secondary)",
    ".foregroundStyle(editorTheme.statusRunning)",
  ]

  @Test(arguments: accentTextLines)
  func theAccentTextPatternFindsTheAccentAsATextColor(line: String) {
    #expect(line.contains(Self.accentTextPattern))
  }

  @Test(arguments: notAccentTextLines)
  func theAccentTextPatternFindsNoOtherLine(line: String) {
    #expect(!line.contains(Self.accentTextPattern))
  }

  /// A link, or any other text, does not use the accent as its text color.
  @Test(arguments: SystemStructureTests.scanPaths)
  func noSourceUsesTheAccentAsATextColor(path: String) throws {
    let found = try SourceLineScanner.codeMatchStarts(
      of: Self.accentTextPattern, inSwiftFilesBelow: PackageFiles().file(path), relativeTo: PackageFiles().root)

    #expect(
      found.isEmpty,
      "A link does not use the accent as its text color (card ^y2mrfxt). Mark it another way: \(found)")
  }

  /// A current item that is not the selection and has no focus reads no
  /// accent.
  @Test(arguments: currentItemFiles)
  func aCurrentItemReadsNoAccent(file: String) throws {
    let code = try ThreadBottomBarStructureTests.code(of: file)

    #expect(SourceLineScanner.matchStartLines(of: Self.themeAccentPattern, in: code).isEmpty)
  }

  /// A current item that is not the selection and has no focus has no fill:
  /// EditorKit's `contentFills` engine finds nothing in its file.
  @Test(arguments: currentItemFiles)
  func aCurrentItemHasNoFill(file: String) throws {
    let lines = try StyleRuleScanner.contentFills.lines(inSource: PackageFiles().text(of: file))

    #expect(lines.isEmpty, "\(file) fills at lines \(lines)")
  }
}
