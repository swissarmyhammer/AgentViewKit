import Foundation
import PackageFileSupport
import Testing

/// Holds the package on the one shared style guide, `../EditorKit/style.md`
/// (^tx59fk). EditorKit holds the guide for EditorKit, KanbanViewKit,
/// AgentViewKit, SnapshotViewKit and TestudoApp, and the package keeps no copy
/// of its rules. The guide and its research page moved out of TestudoApp, so no
/// file of the package still names their old paths.
@Suite struct StyleGuideLinkTests {
  /// The architecture document of the package, relative to the package root.
  static let architecturePath = "ARCHITECTURE.md"

  /// The Markdown link target of the shared style guide, as a document at the
  /// package root writes it.
  static let sharedStyleGuideLink = "](../EditorKit/style.md)"

  /// The old paths of the style guide and of its research page in TestudoApp.
  static let retiredGuidePaths = ["features/style.md", "features/research-liquid-glass.md"]

  /// The extensions of the files that can link a guide: the documents, the
  /// Swift sources and their comments, and the scripts.
  static let linkingFileExtensions: Set<String> = ["md", "swift", "sh"]

  @Test func theArchitectureLinksTheSharedStyleGuide() throws {
    let architecture = try PackageFiles.text(of: Self.architecturePath)

    #expect(architecture.contains(Self.sharedStyleGuideLink))
  }

  @Test func noFileNamesAnOldPathOfTheStyleGuide() throws {
    let ownPath = try PackageFiles.relativePath(of: URL(filePath: #filePath), to: PackageFiles.root)
    let files = try PackageFiles.visibleFiles(in: PackageFiles.root, withExtensions: Self.linkingFileExtensions)
    let paths = try files.map { try PackageFiles.relativePath(of: $0, to: PackageFiles.root) }

    let found = try paths.filter { $0 != ownPath }.sorted().flatMap { path in
      SourceLineScanner.matches(inSource: try PackageFiles.text(of: path), file: path) { line in
        Self.retiredGuidePaths.flatMap { SourceLineScanner.uses(of: $0, on: line) }
      }
    }

    #expect(paths.contains(Self.architecturePath))
    #expect(found.isEmpty, "Link ../EditorKit/style.md or ../EditorKit/Docs/research-liquid-glass.md: \(found)")
  }
}
