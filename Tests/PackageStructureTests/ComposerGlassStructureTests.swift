import EditorTestSupport
import Foundation
import RegexBuilder
import Testing

/// Checks the glass calls in the files of the composer (D110 (c)).
///
/// No file of the kit makes a `GlassEffectContainer`: the shared
/// `FloatingGlassContainer` of the EditorKit `EditorStyle` target makes it
/// (``GlassPlacementTests``). That container makes no second container in a
/// container, so a group of floating controls has one container. The thread
/// view puts the scroll-to-bottom pill and the composer slot in one shared
/// container, and the composer uses the shared container too.
///
/// The composer puts the field, the menu of the editor and the accessory in
/// that one container. The field and the menu are on the floating
/// glass of EditorStyle, through `floatingGlass(id:)`. The menu is a sibling
/// of the field glass, not in it. The composer file writes no direct
/// `.glassEffect` call, so that one modifier gives each glass. The menu shows
/// and hides next to the field glass. Thus the field and the menu each have a
/// `FloatingGlassID` in the one namespace of the container, and the change
/// morphs (D113 answer 2). The composer adds no animation of its own, so no
/// morph runs while Reduce Motion is on (plan.md §6).
///
/// The scroll-to-bottom pill and the suggestion chips are glass buttons that
/// show and hide next to the composer, in the same container. Each file gives
/// its glass a `FloatingGlassID` one time, through `floatingGlassID(_:)`.
/// That one modifier of EditorStyle applies each `.glassEffectID` of a glass
/// button. The id of EditorStyle is any `Hashable` value, so each call names
/// the id type of the kit, such as `FloatingGlassID.scrollPill`.
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

  /// Each file that puts views on the floating glass of the kit, and the
  /// number of those views: the field and the menu of the editor in the
  /// composer, and the ``AgentInfoHeader`` in the top bar of the thread view
  /// (``ThreadTopBarStructureTests``).
  static let floatingGlassViews = [
    (file: composerFile, count: 2),
    (file: threadFile, count: 1),
  ]

  /// Each file that puts its floating controls in the shared container, and
  /// the number of its containers. The composer has one. The thread view has
  /// one for the header in its top bar, and one for the floating controls in
  /// its bottom bar.
  static let sharedContainerUsers = [
    (file: composerFile, count: 1),
    (file: threadFile, count: 2),
  ]

  /// Each glass form that a file must not write, as the file and the form.
  ///
  /// The thread view writes no direct `.glassEffect` call: its header gets
  /// the floating glass of the kit, and its floating controls get their
  /// glass from their own files. The composer writes no direct
  /// `.glassEffect` call. The editor is in the field glass, so it writes no
  /// glass.
  static let forbiddenGlass = [
    (file: threadFile, form: GlassForm.glassEffect),
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
      use: "menu.floatingGlass( id: FloatingGlassID.editorMenu)",
      nonUses: ["menu.floatingGlass(id: FloatingGlassID.editorMenuBar)", "menu.floatingGlass()"]),
    GlassIDPatternSample(
      modifier: .glassID,
      id: "suggestion",
      use: "chip.floatingGlassID( FloatingGlassID.suggestion(index))",
      nonUses: [
        "chip.floatingGlassID(FloatingGlassID.suggestions)",
        "chip.floatingGlass(id: FloatingGlassID.suggestion(index))",
      ]),
  ]

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
  static func codeLineCount(of pattern: Regex<Substring>, in file: String) throws -> Int {
    let directory = try PackageFiles().file(file).deletingLastPathComponent()
    let found = try GlassPlacementTests.uses(of: pattern, inSwiftFilesBelow: directory, relativeTo: PackageFiles().root)
    return found.filter { $0.hasPrefix("\(file):") }.count
  }

  @Test(arguments: sharedContainerUsers)
  func eachFileOfTheFloatingControlsUsesTheSharedContainerItsNumberOfTimes(file: String, count: Int) throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlassContainer.pattern, in: file) == count)
  }

  @Test(arguments: forbiddenGlass)
  func eachFileWritesNoGlassFormThatIsForbiddenToIt(file: String, form: GlassForm) throws {
    #expect(try Self.codeLineCount(of: form.pattern, in: file) == 0)
  }

  @Test(arguments: floatingGlassViews)
  func eachFilePutsItsViewsOnTheFloatingGlassOfTheKit(file: String, count: Int) throws {
    #expect(try Self.codeLineCount(of: GlassForm.floatingGlass.pattern, in: file) == count)
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
}

/// A modifier of EditorStyle that gives a glass a `FloatingGlassID` (D113
/// answer 2).
enum GlassIDModifier: String, CustomTestStringConvertible, Sendable {
  /// The floating glass of EditorStyle with a glass id, such as
  /// `.floatingGlass(id: FloatingGlassID.composerField)`.
  case floatingGlass

  /// The glass id modifier of EditorStyle, such as
  /// `.floatingGlassID(FloatingGlassID.scrollPill)` or
  /// `.floatingGlassID(FloatingGlassID.suggestion(index))`.
  case glassID

  var testDescription: String { rawValue }

  /// The pattern that comes before the id: the call of the modifier, for the
  /// floating glass the `id:` label too, and the id type of the kit,
  /// `FloatingGlassID`. The modifiers take any `Hashable` id, so an implicit
  /// member does not compile, and each call names the type.
  ///
  /// A `Regex` is not `Sendable`, so each call makes the value again.
  var receiver: Regex<Substring> {
    Regex {
      call
      ZeroOrMore(.whitespace)
      WordPattern.wholeWord("FloatingGlassID")
    }
  }

  /// The call of the modifier, and for the floating glass, the `id:` label
  /// too.
  private var call: Regex<Substring> {
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
