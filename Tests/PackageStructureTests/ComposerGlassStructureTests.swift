import Foundation
import PackageFileSupport
import Testing

/// Checks the glass calls in the files of the composer (D110 (c)).
///
/// The composer puts the field, the menu of the editor and the accessory in
/// one `GlassEffectContainer`. The field and the menu are on the floating
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

  /// The text that makes a glass effect container.
  static let containerCall = "GlassEffectContainer("

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
      let isComment = line.text.trimmingCharacters(in: .whitespaces).hasPrefix("//")
      return !isComment && line.text.contains(text) ? [line.number] : []
    }.count
  }

  @Test func theComposerHasOneGlassEffectContainer() throws {
    #expect(try Self.codeLineCount(holding: Self.containerCall) == 1)
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
