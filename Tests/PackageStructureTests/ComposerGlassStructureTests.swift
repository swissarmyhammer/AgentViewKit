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
/// The scroll-to-bottom pill and the suggestion chips are glass buttons that
/// show and hide next to the composer, in the same container. Each file gives
/// its glass a `FloatingGlassID` one time, through `agentGlassID(_:)`. That
/// one modifier applies each `.glassEffectID` of a glass button.
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

  /// The files that put their floating controls in the shared container: the
  /// composer and the thread view.
  static let sharedContainerUsers = [composerFile, threadFile]

  /// Each glass form that a file must not write, as the file and the form.
  ///
  /// The thread view writes no glass of its own: its floating controls get
  /// their glass from their own files. The composer writes no direct
  /// `.glassEffect` call. The editor is in the field glass, so it writes no
  /// glass.
  static let forbiddenGlass = [
    (file: threadFile, form: GlassForm.glassEffect),
    (file: threadFile, form: GlassForm.floatingGlass),
    (file: composerFile, form: GlassForm.glassEffect),
    (file: editorFile, form: GlassForm.glassEffect),
    (file: editorFile, form: GlassForm.floatingGlass),
  ]

  /// Each glass that shows or hides next to another glass in the shared
  /// container, and so gives its `FloatingGlassID` (D113 answer 2): the field
  /// and the menu of the composer, the scroll-to-bottom pill, and the
  /// suggestion chips.
  static let glassIDUses = [
    GlassIDUse(modifier: .floatingGlass, file: composerFile, id: "composerField"),
    GlassIDUse(modifier: .floatingGlass, file: composerFile, id: "editorMenu"),
    GlassIDUse(modifier: .glassID, file: GlassForm.scrollPillFile, id: "scrollPill"),
    GlassIDUse(modifier: .glassID, file: GlassForm.suggestionsFile, id: "suggestion"),
  ]

  /// A sample line for the id pattern of each modifier, and the lines that
  /// the pattern must not find.
  static let glassIDPatternSamples = [
    GlassIDPatternSample(
      modifier: .floatingGlass,
      id: "editorMenu",
      use: "menu.agentFloatingGlass( id: .editorMenu)",
      nonUses: ["menu.agentFloatingGlass(id: .editorMenuBar)", "menu.agentFloatingGlass()"]),
    GlassIDPatternSample(
      modifier: .glassID,
      id: "suggestion",
      use: "chip.agentGlassID( .suggestion(index))",
      nonUses: ["chip.agentGlassID(.suggestions)", "chip.agentFloatingGlass(id: .suggestion(index))"]),
  ]

  /// The pattern that finds a namespace property wrapper, `@Namespace`.
  static var namespacePattern: Regex<Substring> {
    Regex {
      "@"
      WordPattern.wholeWord("Namespace")
    }
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

  @Test(arguments: sharedContainerUsers)
  func eachFileOfTheFloatingControlsUsesTheSharedContainerOneTime(file: String) throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlassContainer.pattern, in: file) == 1)
  }

  @Test(arguments: forbiddenGlass)
  func eachFileWritesNoGlassFormThatIsForbiddenToIt(file: String, form: GlassForm) throws {
    #expect(try Self.codeLineCount(of: form.pattern, in: file) == 0)
  }

  @Test func theComposerPutsTheFloatingGlassOfTheKitOnTheFieldAndTheMenu() throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlass.pattern) == Self.floatingGlassViewCount)
  }

  @Test(arguments: glassIDUses)
  func eachGlassNextToAnotherGlassGivesItsGlassIDOneTime(use: GlassIDUse) throws {
    #expect(try Self.codeLineCount(of: use.modifier.pattern(id: use.id), in: use.file) == 1)
  }

  @Test(arguments: glassIDPatternSamples)
  func eachGlassIDPatternFindsTheIDInTheArgumentOfTheModifier(sample: GlassIDPatternSample) {
    let pattern = sample.modifier.pattern(id: sample.id)

    #expect(sample.use.contains(pattern))
    for nonUse in sample.nonUses {
      #expect(!nonUse.contains(pattern), "\(nonUse)")
    }
  }

  @Test func theSharedContainerHasOneNamespace() throws {
    #expect(try Self.codeLineCount(of: Self.namespacePattern, in: GlassForm.sharedContainerFile) == 1)
  }
}

/// A modifier of the kit that gives a glass a `FloatingGlassID` (D113
/// answer 2).
enum GlassIDModifier: String, CustomTestStringConvertible, Sendable {
  /// The floating glass of the kit with a glass id, such as
  /// `.agentFloatingGlass(id: .composerField)`.
  case floatingGlass

  /// The glass id modifier of the kit, such as `.agentGlassID(.scrollPill)`
  /// or `.agentGlassID(.suggestion(index))`.
  case glassID

  var testDescription: String { rawValue }

  /// The pattern that comes before the id: the call of the modifier, and for
  /// the floating glass, the `id:` label too.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  var receiver: Regex<Substring> {
    switch self {
    case .floatingGlass:
      Regex {
        GlassForm.floatingGlass.pattern
        ZeroOrMore(.whitespace)
        "id:"
      }
    case .glassID: GlassForm.glassID.pattern
    }
  }

  /// The pattern that finds the modifier with a glass id as a whole word in
  /// its argument.
  ///
  /// - Parameter id: The name of the `FloatingGlassID` case.
  /// - Returns: The pattern, from ``WordPattern/memberPattern(after:_:)``.
  func pattern(id: String) -> Regex<Substring> {
    WordPattern.memberPattern(after: receiver, WordPattern.wholeWord(id))
  }
}

/// A file that gives a glass its `FloatingGlassID` one time.
struct GlassIDUse: CustomTestStringConvertible, Sendable {
  /// The modifier that gives the id.
  let modifier: GlassIDModifier
  /// The file that holds the glass, relative to the package root.
  let file: String
  /// The name of the `FloatingGlassID` case.
  let id: String

  var testDescription: String { "\(file) \(id)" }
}

/// A sample line that uses a glass id, and lines that do not use it, for the
/// id pattern of one modifier.
struct GlassIDPatternSample: CustomTestStringConvertible, Sendable {
  /// The modifier of the pattern.
  let modifier: GlassIDModifier
  /// The name of the `FloatingGlassID` case.
  let id: String
  /// A line that uses the id. The pattern finds it.
  let use: String
  /// The lines that do not use the id. The pattern finds none of them.
  let nonUses: [String]

  var testDescription: String { modifier.rawValue }
}
