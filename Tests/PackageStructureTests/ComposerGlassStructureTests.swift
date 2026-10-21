import Foundation
import PackageFileSupport
import RegexBuilder
import Testing

/// Checks the glass calls in the files of the composer (D110 (c)).
///
/// One file of the kit makes a `GlassEffectContainer`: the shared
/// `FloatingGlassContainer` (``GlassPlacementTests``). That container makes
/// no second container in a container, so a group of floating controls has
/// one container. The thread view puts the scroll-to-bottom pill and the
/// composer slot in one shared container, and the composer uses the shared
/// container too.
///
/// The composer puts the field, the menu of the editor and the accessory in
/// that one container. The field and the menu are on the floating
/// glass of the kit, through `agentFloatingGlass(id:)`. The menu is a sibling
/// of the field glass, not in it. The composer file writes no direct
/// `.glassEffect` call, so that one modifier gives each glass. The menu shows
/// and hides next to the field glass. Thus the field and the menu each have a
/// `FloatingGlassID` in the one namespace of the container, and the change
/// morphs (D113 answer 2). The composer adds no animation of its own, so no
/// morph runs while Reduce Motion is on (plan.md §6).
///
/// The EditorKit editor is in the field glass. So its file writes no glass:
/// glass in it is glass on glass.
///
/// The scan blanks the comments and the string literals of each file, then
/// reads it one line at a time
/// (``SourceLineScanner/codeMatches(inSwiftFilesBelow:relativeTo:skipping:match:)``).
@Suite struct ComposerGlassStructureTests {
  /// The file of the composer.
  static let composerFile = KitSourceFiles.kitFile("Input/PromptInputView.swift")

  /// The file of the EditorKit editor of the composer.
  static let editorFile = KitSourceFiles.kitFile("Input/EditorKitPromptEditor.swift")

  /// The file of the thread view, which holds the floating controls.
  static let threadFile = KitSourceFiles.kitFile("Thread/AgentThreadView.swift")

  /// The number of the views of the composer on the floating glass: the
  /// field and the menu of the editor.
  static let floatingGlassViewCount = 2

  /// The `FloatingGlassID` cases that the composer gives: the field and the
  /// menu of the editor.
  static let composerGlassIDs = ["composerField", "editorMenu"]

  /// The pattern that finds a namespace property wrapper, `@Namespace`.
  static var namespacePattern: Regex<Substring> {
    Regex {
      "@"
      WordPattern.wholeWord("Namespace")
    }
  }

  /// The pattern that finds the floating glass of the kit with a glass id,
  /// such as `.agentFloatingGlass(id: .composerField)`.
  ///
  /// - Parameter id: The name of the `FloatingGlassID` case.
  /// - Returns: The pattern, from ``WordPattern/memberPattern(after:_:)``.
  static func floatingGlassPattern(id: String) -> Regex<Substring> {
    let receiver = Regex {
      GlassForm.floatingGlass.pattern
      ZeroOrMore(.whitespace)
      "id:"
    }
    return WordPattern.memberPattern(after: receiver, WordPattern.wholeWord(id))
  }

  /// The number of the code lines of `file` that use `pattern`. A use in a
  /// comment or in a string literal does not count.
  ///
  /// The scan reads the directory of `file`, and keeps only the lines of
  /// `file`.
  ///
  /// - Parameters:
  ///   - pattern: The pattern to find.
  ///   - file: The file to read, relative to the package root.
  /// - Returns: The number of the code lines that use `pattern`.
  /// - Throws: The error of
  ///   ``GlassPlacementTests/uses(of:inSwiftFilesBelow:relativeTo:allowing:)``.
  static func codeLineCount(of pattern: Regex<Substring>, in file: String = composerFile) throws -> Int {
    let directory = try PackageFiles.file(file).deletingLastPathComponent()
    let found = try GlassPlacementTests.uses(of: pattern, inSwiftFilesBelow: directory, relativeTo: PackageFiles.root)
    return found.filter { $0.hasPrefix("\(file):") }.count
  }

  @Test func theComposerUsesTheSharedContainerOneTime() throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlassContainer.pattern) == 1)
  }

  @Test func theThreadViewPutsItsFloatingControlsInTheSharedContainer() throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlassContainer.pattern, in: Self.threadFile) == 1)
  }

  @Test func theThreadViewWritesNoGlassOfItsOwn() throws {
    #expect(try Self.codeLineCount(of: GlassForm.glassEffect.pattern, in: Self.threadFile) == 0)
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlass.pattern, in: Self.threadFile) == 0)
  }

  @Test func theComposerPutsTheFloatingGlassOfTheKitOnTheFieldAndTheMenu() throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlass.pattern) == Self.floatingGlassViewCount)
  }

  @Test(arguments: composerGlassIDs)
  func theComposerGivesTheGlassIDOneTime(id: String) throws {
    #expect(try Self.codeLineCount(of: Self.floatingGlassPattern(id: id)) == 1)
  }

  @Test func theComposerWritesNoDirectGlassEffect() throws {
    #expect(try Self.codeLineCount(of: GlassForm.glassEffect.pattern) == 0)
  }

  @Test func theSharedContainerHasOneNamespace() throws {
    #expect(try Self.codeLineCount(of: Self.namespacePattern, in: GlassForm.sharedContainerFile) == 1)
  }

  @Test func theFloatingGlassPatternFindsTheIDInTheArgumentOfTheModifier() {
    let pattern = Self.floatingGlassPattern(id: "editorMenu")

    #expect("menu.agentFloatingGlass( id: .editorMenu)".contains(pattern))
    #expect(!"menu.agentFloatingGlass(id: .editorMenuBar)".contains(pattern))
    #expect(!"menu.agentFloatingGlass()".contains(pattern))
  }

  @Test func theEditorWritesNoGlassEffect() throws {
    #expect(try Self.codeLineCount(of: GlassForm.glassEffect.pattern, in: Self.editorFile) == 0)
  }

  @Test func theEditorWritesNoFloatingGlass() throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlass.pattern, in: Self.editorFile) == 0)
  }
}
