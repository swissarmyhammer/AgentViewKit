import Foundation
import PackageFileSupport
import Testing

/// Checks the glass calls in the file of the composer (D110 (c)).
///
/// The composer puts the field and the accessory in one
/// `GlassEffectContainer`. Only the field is on the floating glass of the
/// kit, through `agentFloatingGlass()`. The file writes no direct
/// `.glassEffect` call, so that one modifier gives the glass of the field.
/// The file also writes no `glassEffectID`, so the composer adds no glass
/// morph, also while Reduce Motion is on (plan.md §6).
///
/// The scan reads the file as text, one line at a time. A comment line does
/// not count.
@Suite struct ComposerGlassStructureTests {
  /// The file of the composer.
  static let composerFile = KitSourceFiles.kitFile("Input/PromptInputView.swift")

  /// The text that makes a glass effect container.
  static let containerCall = "GlassEffectContainer("

  /// The text of the floating glass modifier of the kit.
  static let floatingGlassCall = ".agentFloatingGlass()"

  /// The text of a direct glass effect call.
  static let glassEffectCall = ".glassEffect("

  /// The text of a glass effect identity, which makes a glass morph.
  static let glassEffectIdentityCall = ".glassEffectID("

  /// The number of the code lines of the composer file that hold `text`.
  ///
  /// - Parameter text: The text to find.
  /// - Returns: The number of lines that hold `text` and are not comments.
  /// - Throws: An error when the file cannot be read.
  static func codeLineCount(holding text: String) throws -> Int {
    let source = try PackageFiles.text(of: composerFile)
    return SourceLineScanner.matches(inSource: source, file: composerFile) { line in
      let isComment = line.text.trimmingCharacters(in: .whitespaces).hasPrefix("//")
      return !isComment && line.text.contains(text) ? [line.number] : []
    }.count
  }

  @Test func theComposerHasOneGlassEffectContainer() throws {
    #expect(try Self.codeLineCount(holding: Self.containerCall) == 1)
  }

  @Test func theComposerPutsTheFloatingGlassOfTheKitOnOneView() throws {
    #expect(try Self.codeLineCount(holding: Self.floatingGlassCall) == 1)
  }

  @Test func theComposerWritesNoDirectGlassEffect() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectCall) == 0)
  }

  @Test func theComposerAddsNoGlassMorph() throws {
    #expect(try Self.codeLineCount(holding: Self.glassEffectIdentityCall) == 0)
  }
}
