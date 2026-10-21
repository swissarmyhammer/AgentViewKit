import Foundation
import PackageFileSupport
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
/// glass of the kit, through `agentFloatingGlass()`. The menu is a sibling of
/// the field glass, not in it. The composer file writes no direct
/// `.glassEffect` call, so that one modifier gives each glass. The file also
/// writes no `glassEffectID`, so the composer adds no glass morph, also while
/// Reduce Motion is on (plan.md §6).
///
/// The EditorKit editor is in the field glass. So its file writes no glass:
/// glass in it is glass on glass.
///
/// The scan reads each file as text, one line at a time. A comment line does
/// not count.
@Suite struct ComposerGlassStructureTests {
  /// The file of the composer.
  static let composerFile = KitSourceFiles.kitFile("Input/PromptInputView.swift")

  /// The file of the EditorKit editor of the composer.
  static let editorFile = KitSourceFiles.kitFile("Input/EditorKitPromptEditor.swift")

  /// The file of the thread view, which holds the floating controls.
  static let threadFile = KitSourceFiles.kitFile("Thread/AgentThreadView.swift")

  /// The text that makes the shared container of the floating controls.
  static let sharedContainerCall = "FloatingGlassContainer("

  /// The text of the floating glass modifier of the kit.
  static let floatingGlassCall = ".agentFloatingGlass()"

  /// The text of a direct glass effect call.
  static let glassEffectCall = ".glassEffect("

  /// The text of a glass effect identity, which makes a glass morph.
  static let glassEffectIdentityCall = ".glassEffectID("

  /// The number of the views of the composer on the floating glass: the
  /// field and the menu of the editor.
  static let floatingGlassViewCount = 2

  /// The number of the code lines of `file` that hold `text`.
  ///
  /// - Parameters:
  ///   - text: The text to find.
  ///   - file: The file to read.
  /// - Returns: The number of lines that hold `text` and are not comments.
  /// - Throws: An error when the file cannot be read.
  static func codeLineCount(holding text: String, in file: String = composerFile) throws -> Int {
    let source = try PackageFiles.text(of: file)
    return SourceLineScanner.matches(inSource: source, file: file) { line in
      isCode(line, holding: text) ? [line.number] : []
    }.count
  }

  /// Tells if `line` is a code line that holds `text`.
  ///
  /// - Parameters:
  ///   - line: The line of a Swift file.
  ///   - text: The text to find.
  /// - Returns: `true` when the line holds `text` and is not a comment.
  static func isCode(_ line: SourceLine, holding text: String) -> Bool {
    let isComment = line.text.trimmingCharacters(in: .whitespaces).hasPrefix("//")
    return !isComment && line.text.contains(text)
  }

  @Test func theComposerUsesTheSharedContainerOneTime() throws {
    #expect(try Self.codeLineCount(holding: Self.sharedContainerCall) == 1)
  }

  @Test func theThreadViewPutsItsFloatingControlsInTheSharedContainer() throws {
    #expect(try Self.codeLineCount(holding: Self.sharedContainerCall, in: Self.threadFile) == 1)
  }

  @Test func theThreadViewWritesNoGlassOfItsOwn() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectCall, in: Self.threadFile) == 0)
    #expect(try Self.codeLineCount(holding: Self.floatingGlassCall, in: Self.threadFile) == 0)
  }

  @Test func theComposerPutsTheFloatingGlassOfTheKitOnTheFieldAndTheMenu() throws {
    #expect(try Self.codeLineCount(holding: Self.floatingGlassCall) == Self.floatingGlassViewCount)
  }

  @Test func theComposerWritesNoDirectGlassEffect() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectCall) == 0)
  }

  @Test func theComposerAddsNoGlassMorph() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectIdentityCall) == 0)
  }

  @Test func theEditorWritesNoGlassEffect() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectCall, in: Self.editorFile) == 0)
  }

  @Test func theEditorWritesNoFloatingGlass() throws {
    #expect(try Self.codeLineCount(holding: Self.floatingGlassCall, in: Self.editorFile) == 0)
  }
}
