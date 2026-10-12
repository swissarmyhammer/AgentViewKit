import Foundation
import PackageFileSupport
import Testing

/// Holds the symbols of the status views in one rendering mode.
///
/// The error card, the status bar, the notice banner, the plan and the
/// compaction row show each symbol with the hierarchical rendering mode. The
/// tool call row, the status symbol of a tool call, the activity timeline and
/// the diff use the same mode, so each status view shows the layers of a
/// symbol in the same way.
///
/// The scan reads each file as text. The modifier chain of a symbol image is
/// each line after the image line that starts with a dot.
@Suite struct SymbolRenderingModeTests {
  /// The files of the status views. Each symbol image in these files uses the
  /// hierarchical rendering mode.
  static let statusViewFiles = [
    "Sources/AgentViewKit/Items/ErrorView.swift",
    "Sources/AgentViewKit/Status/StatusBar.swift",
    "Sources/AgentViewKit/Status/SessionNoticeBanner.swift",
    "Sources/AgentViewKit/Status/TaskListView.swift",
    "Sources/AgentViewKit/Items/CompactionEntryView.swift",
    "Sources/AgentViewKit/Items/ToolCallView.swift",
    "Sources/AgentViewKit/Items/ToolStatusImage.swift",
    "Sources/AgentViewKit/Activity/ActivityTimeline.swift",
    "Sources/AgentViewKit/Diff/DiffView.swift",
  ]

  /// The text that starts a symbol image.
  static let symbolImageCall = "Image(systemName:"

  /// The modifier that sets the hierarchical rendering mode.
  static let hierarchicalModifier = ".symbolRenderingMode(.hierarchical)"

  /// The text that starts each line of a modifier chain.
  static let modifierPrefix = "."

  /// Finds the symbol images of a source that have no hierarchical mode.
  ///
  /// - Parameters:
  ///   - source: The text of a Swift file.
  ///   - file: The file name to write into each result.
  /// - Returns: `<file>:<line>` for each symbol image whose modifier chain
  ///   does not set the hierarchical mode, in line order.
  static func imagesWithNoHierarchicalMode(in source: String, file: String) -> [String] {
    let lines = source.split(separator: "\n", omittingEmptySubsequences: false)
    return lines.indices.compactMap { index in
      guard lines[index].contains(symbolImageCall) else { return nil }
      let chain = lines[(index + 1)...].prefix { line in
        line.trimmingCharacters(in: .whitespaces).hasPrefix(modifierPrefix)
      }
      return chain.contains { $0.contains(hierarchicalModifier) } ? nil : "\(file):\(index + 1)"
    }
  }

  @Test func theScanFindsAnImageWithNoHierarchicalModeInItsChain() {
    let source = """
      Image(systemName: SharedSymbol.error)
        .symbolRenderingMode(.hierarchical)
        .fontWeight(theme.symbolWeight)
      Image(systemName: SharedSymbol.disclosure)
        .fontWeight(theme.symbolWeight)
      Text("A")
        .symbolRenderingMode(.hierarchical)
      """

    #expect(Self.imagesWithNoHierarchicalMode(in: source, file: "A.swift") == ["A.swift:4"])
  }

  @Test func eachSymbolImageOfTheStatusViewsUsesTheHierarchicalMode() throws {
    let found = try Self.statusViewFiles.flatMap { file in
      Self.imagesWithNoHierarchicalMode(in: try PackageFiles.text(of: file), file: file)
    }

    #expect(found.isEmpty, "Add \(Self.hierarchicalModifier) to: \(found)")
  }
}
