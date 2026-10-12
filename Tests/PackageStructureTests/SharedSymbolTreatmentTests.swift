import Foundation
import PackageFileSupport
import Testing

/// Holds the treatment of the status symbols in one place.
///
/// The live symbol effect and its Reduce Motion rule are in one view modifier,
/// `LiveSymbolEffect`. The hierarchical rendering mode, the symbol weight and
/// the color of a status symbol are in one view, `StatusSymbolImage`. A change
/// to the effect, to the Reduce Motion rule or to the symbol treatment is thus
/// made one time, and the tool call, the plan entry and the status bar show it.
///
/// The scan reads each Swift file as text, one line at a time.
@Suite struct SharedSymbolTreatmentTests {
  /// The file of the view modifier that applies the live symbol effect and
  /// removes the symbol effects under Reduce Motion.
  static let liveEffectFile = KitSourceFiles.kitFile("Items/LiveSymbolEffect.swift")

  /// The text of the modifiers that only `LiveSymbolEffect` writes: the
  /// variable color effect and the removal of the symbol effects.
  static let liveEffectModifiers = [".variableColor", ".symbolEffectsRemoved("]

  /// The files of the status symbols that draw with `StatusSymbolImage`: the
  /// status of a tool call, the status and the priority of a plan entry, and
  /// the symbol of a status bar.
  static let statusSymbolFiles = [
    KitSourceFiles.kitFile("Items/ToolStatusImage.swift"),
    KitSourceFiles.taskListFile,
    KitSourceFiles.statusBarFile,
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
    let found = try SourceLineScanner.matches(
      inSwiftFilesBelow: PackageFiles.file(KitSourceFiles.kitPath),
      relativeTo: PackageFiles.root
    ) { line in
      Self.uses(of: Self.liveEffectModifiers, on: line)
    }

    let outside = found.filter { !$0.hasPrefix(Self.liveEffectFile + ":") }
    #expect(!found.isEmpty)
    #expect(outside.isEmpty, "Use liveSymbolEffect(isActive:) in: \(outside)")
  }

  @Test func eachStatusSymbolDrawsWithTheSharedStatusSymbolImage() throws {
    let found = try Self.statusSymbolFiles.flatMap { file in
      SourceLineScanner.matches(inSource: try PackageFiles.text(of: file), file: file) { line in
        Self.uses(of: [KitSourceFiles.symbolImageCall], on: line)
      }
    }

    #expect(found.isEmpty, "Use StatusSymbolImage in: \(found)")
  }
}
