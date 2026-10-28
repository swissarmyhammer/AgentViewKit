import Foundation
import PackageFileSupport
import Testing

/// Holds the treatment of the status symbols in one place.
///
/// The live symbol effect and its Reduce Motion rule are in one view modifier,
/// `LiveSymbolEffect`. The hierarchical rendering mode, the symbol weight and
/// the color of a status symbol are in one view, `StatusSymbolImage`. A change
/// to the effect, to the Reduce Motion rule or to the symbol treatment is thus
/// made one time, and each status symbol in ``statusSymbolFiles`` shows it.
/// The secondary style, the symbol weight and the hidden accessibility trait
/// of a decorative header symbol are in one view, `DecorativeSymbolImage`, and
/// each symbol in ``decorativeSymbolFiles`` shows them.
///
/// The scan reads each Swift file as text, one line at a time.
@Suite struct SharedSymbolTreatmentTests {
  /// The file of the view modifier that applies the live symbol effect and
  /// removes the symbol effects under Reduce Motion.
  static let liveEffectFile = KitSourceFiles.styleFile("Symbols/LiveSymbolEffect.swift")

  /// The text of the modifiers that only `LiveSymbolEffect` writes: the
  /// variable color effect and the removal of the symbol effects.
  static let liveEffectModifiers = [".variableColor", ".symbolEffectsRemoved("]

  /// The files of the status symbols that draw with `StatusSymbolImage`: the
  /// status of a tool call, the status and the priority of a plan entry, the
  /// symbol of a status bar, the header of a compaction row, the symbol of an
  /// error card, the symbol of a session notice and the symbol of an activity
  /// row.
  static let statusSymbolFiles = [
    KitSourceFiles.kitFile("Items/ToolStatusImage.swift"),
    KitSourceFiles.taskListFile,
    KitSourceFiles.statusBarFile,
    KitSourceFiles.kitFile("Items/CompactionEntryView.swift"),
    KitSourceFiles.kitFile("Items/ErrorView.swift"),
    KitSourceFiles.kitFile("Status/SessionNoticeBanner.swift"),
    KitSourceFiles.kitFile("Activity/ActivityTimeline.swift"),
  ]

  /// The files of the decorative header symbols that draw with
  /// `DecorativeSymbolImage`: the symbol of the agent header and the symbol of
  /// the conversation empty state.
  static let decorativeSymbolFiles = [
    KitSourceFiles.kitFile("Connections/AgentInfoHeader.swift"),
    KitSourceFiles.kitFile("Thread/ConversationEmptyState.swift"),
  ]

  /// Finds the lines that write one of some texts.
  ///
  /// - Parameters:
  ///   - texts: The texts to find.
  ///   - line: One line of a Swift file.
  /// - Returns: `<file>:<line>` when the line holds one of `texts`, or no
  ///   result.
  static func uses(of texts: [String], on line: SourceLine) -> [String] {
    texts.contains { line.text.contains($0) } ? ["\(line.file):\(line.number)"] : []
  }

  @Test func theScanFindsTheLiveEffectModifiers() {
    let source = """
      Image(systemName: name)
        .symbolEffect(.variableColor.iterative, isActive: isLive)
        .symbolEffect(.bounce, value: done)
        .symbolEffectsRemoved(reduceMotion)
      """

    let found = SourceLineScanner.matches(inSource: source, file: "A.swift") { line in
      Self.uses(of: Self.liveEffectModifiers, on: line)
    }

    #expect(found == ["A.swift:2", "A.swift:4"])
  }

  @Test func onlyTheSharedModifierWritesTheLiveEffectAndTheReduceMotionRule() throws {
    let found = try KitSourceFiles.scanLibraryFiles { directory in
      try SourceLineScanner.matches(inSwiftFilesBelow: directory, relativeTo: PackageFiles.root) { line in
        Self.uses(of: Self.liveEffectModifiers, on: line)
      }
    }

    let outside = found.filter { !$0.hasPrefix(Self.liveEffectFile + ":") }
    #expect(!found.isEmpty)
    #expect(outside.isEmpty, "Use liveSymbolEffect(isActive:) in: \(outside)")
  }

  /// Records an issue when one of some files writes a call.
  ///
  /// - Parameters:
  ///   - call: The text of the call that the files must not write.
  ///   - files: The files to read, relative to the package root.
  ///   - replacement: The name of the shared view to use in place of the
  ///     call. The failure report shows it.
  ///   - sourceLocation: The location of the caller, for the failure report.
  /// - Throws: An error when a file cannot be read.
  static func expectNoCall(
    _ call: String,
    in files: [String],
    use replacement: String,
    sourceLocation: SourceLocation = #_sourceLocation
  ) throws {
    let found = try files.flatMap { file in
      SourceLineScanner.matches(inSource: try PackageFiles.text(of: file), file: file) { line in
        uses(of: [call], on: line)
      }
    }

    #expect(found.isEmpty, "Use \(replacement) in: \(found)", sourceLocation: sourceLocation)
  }

  @Test func eachStatusSymbolDrawsWithTheSharedStatusSymbolImage() throws {
    try Self.expectNoCall(
      KitSourceFiles.symbolImageCall, in: Self.statusSymbolFiles, use: "StatusSymbolImage")
  }

  @Test func eachDecorativeHeaderSymbolDrawsWithTheSharedDecorativeSymbolImage() throws {
    try Self.expectNoCall(
      KitSourceFiles.symbolImageCall, in: Self.decorativeSymbolFiles, use: "DecorativeSymbolImage")
  }
}
